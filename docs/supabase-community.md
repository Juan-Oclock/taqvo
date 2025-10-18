# Supabase Community: Schema + Sync Plan + RLS

This document sketches a production-ready schema to support challenges, participation, daily contributions, and leaderboards in Supabase. It also outlines a client sync plan and Row Level Security (RLS) policies.

## Goals
- Represent challenges with time-bounded goals (distance total or streaks).
- Allow users to join/leave challenges and record daily contributions.
- Generate leaderboards and progress efficiently.
- Support offline-first mobile clients with eventual consistency.

## Entities

- `profiles` — basic user profile (source of `auth.users` reference).
- `challenges` — challenge definitions, owned by an org or public.
- `challenge_participants` — many-to-many users ↔ challenges with join state.
- `challenge_day_contributions` — per-user, per-day contribution within a challenge.
- `activities` — raw user activities (optional), used for analytics or backfill.
- `leaderboard_view` — materialized or SQL view of totals for a challenge.

## Schema (SQL)

```sql
-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  avatar_url text,
  created_at timestamptz default now()
);

-- Challenges
create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  detail text,
  start_date date not null,
  end_date date not null,
  goal_distance_meters bigint not null default 0,
  is_public boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

-- Challenge participants
create table if not exists public.challenge_participants (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (challenge_id, user_id)
);

-- Per-day contributions (aggregated client-side or server-side)
create table if not exists public.challenge_day_contributions (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  distance_meters bigint not null default 0,
  -- Optional derived columns for streak logic
  contribution_count integer not null default 0,
  primary key (challenge_id, user_id, day)
);

-- Optional raw activities table (if needed for audits/backfill)
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  distance_meters bigint not null default 0,
  source text check (source in ('device','import','manual')),
  created_at timestamptz default now()
);

-- Leaderboard view: total distance by user for a given challenge
create or replace view public.leaderboard_view as
select
  cdc.challenge_id,
  cdc.user_id,
  sum(cdc.distance_meters) as total_distance_meters
from public.challenge_day_contributions cdc
group by cdc.challenge_id, cdc.user_id;
```

## RLS Policies

Enable RLS and add policies to protect user-owned rows while allowing public reads of public challenges.

```sql
alter table public.profiles enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.challenge_day_contributions enable row level security;
alter table public.activities enable row level security;
```

Policies:

```sql
-- profiles: users can read themselves and public fields, update their own
create policy "profiles_select_self_or_public" on public.profiles
  for select using (true);
create policy "profiles_update_self" on public.profiles
  for update using (auth.uid() = id);

-- challenges: public read, only creator can manage
create policy "challenges_public_read" on public.challenges
  for select using (is_public = true);
create policy "challenges_owner_write" on public.challenges
  for insert with check (auth.uid() = created_by)
  for update using (auth.uid() = created_by)
  for delete using (auth.uid() = created_by);

-- challenge_participants: user can insert/join and read their row; public read if challenge is public
create policy "participants_public_read" on public.challenge_participants
  for select using (
    exists (
      select 1 from public.challenges ch
      where ch.id = challenge_participants.challenge_id and ch.is_public
    )
  );
create policy "participants_self_write" on public.challenge_participants
  for insert with check (auth.uid() = user_id)
  for update using (auth.uid() = user_id)
  for delete using (auth.uid() = user_id);

-- day contributions: user-only read/write for their own rows
create policy "contrib_self_rw" on public.challenge_day_contributions
  for select using (auth.uid() = user_id)
  for insert with check (auth.uid() = user_id)
  for update using (auth.uid() = user_id)
  for delete using (auth.uid() = user_id);

-- activities: user-only read/write
create policy "activities_self_rw" on public.activities
  for select using (auth.uid() = user_id)
  for insert with check (auth.uid() = user_id)
  for update using (auth.uid() = user_id)
  for delete using (auth.uid() = user_id);
```

Notes:
- If you want global leaderboards for public challenges, either create a
  `security definer` function that aggregates across users or provide a
  `public.leaderboard_view` with `anon` read access via PostgREST.
- For privacy, you can restrict `profiles` fields by creating a separate view
  that exposes only `username` and `avatar_url` to the public.

## Client Sync Plan

- Data Source protocol (implemented): `CommunityDataSource` with methods:
  - `loadChallenges()` → list of challenges.
  - `loadLeaderboard(challengeID)` → list of entries.
  - `setJoin(challengeID, joined: Bool)` → join/leave.
- Supabase implementation will map to REST/RPC calls:
  - `GET /challenges?select=*` (public challenges).
  - `GET /leaderboard_view?challenge_id=eq.<id>&select=*` for leaderboard.
  - `UPSERT challenge_participants` when joining/leaving.
  - `UPSERT challenge_day_contributions` to upload per-day totals.
- Offline-first:
  - Maintain local cache of `challenges`, `participants`, and per-day contributions.
  - Queue writes for `setJoin` and per-day `contributions` while offline.
  - On reconnect, push queued writes, then pull fresh aggregates.
- Conflict resolution:
  - `challenge_day_contributions` is additive per (user, day). Last-write-wins for the single row; client reconciles by summing local data then upserting.
  - Joins: idempotent insert; leave sets `left_at`.

## Indexes & Performance

```sql
create index if not exists idx_challenges_dates on public.challenges (start_date, end_date);
create index if not exists idx_participants_ch_user on public.challenge_participants (challenge_id, user_id);
create index if not exists idx_contrib_ch_user_day on public.challenge_day_contributions (challenge_id, user_id, day);
create index if not exists idx_activities_user_started on public.activities (user_id, started_at);
```

- Leaderboards read primarily from `leaderboard_view`. Consider a materialized view
  refreshed periodically for large datasets.
- For streak logic, compute client-side or via an RPC function that scans daily rows.

## RPC (Optional)

```sql
-- Example: get leaderboard for a challenge with usernames
create or replace function public.get_leaderboard(ch_id uuid)
returns table (user_id uuid, username text, total_distance_meters bigint)
language sql security definer as $$
  select cdc.user_id, p.username, sum(cdc.distance_meters)
  from public.challenge_day_contributions cdc
  join public.profiles p on p.id = cdc.user_id
  where cdc.challenge_id = ch_id
  group by cdc.user_id, p.username
  order by sum(cdc.distance_meters) desc
$$;
```

## Mapping to Swift

- `Challenge` ↔ `challenges` (dates as `Date`, distance as meters).
- `LeaderboardEntry` ↔ `leaderboard_view` or `get_leaderboard` RPC.
- `toggleJoin`/`setJoin` ↔ upsert into `challenge_participants`.
- `refreshProgress(from store)` ↔ sum of `ActivityStore.dailySummaries()` mapped into `challenge_day_contributions` per-day rows.

## Security Considerations

- Ensure all write endpoints enforce `auth.uid()` ownership.
- Avoid exposing raw `activities` publicly; keep per-user only.
- If public leaderboards are needed, expose only aggregated totals and usernames via a curated view.