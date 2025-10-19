import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var supabaseAuth = SupabaseAuthManager.shared
    @State private var pageIndex: Int = 0
    @State private var showEmailSheet: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSigningIn: Bool = false
    @State private var isSigningUp: Bool = false
    // Simplified animation state
    @State private var dotsBlink: Bool = false
    @State private var screenTwoOpacity: Double = 1.0
    @State private var brandScale: CGFloat = 1.0
    @State private var letterColored: [Bool] = Array(repeating: false, count: 5)
    @State private var showGetStartedButton: Bool = false
    @StateObject private var permissionsVM = PermissionsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
                
                Group {
                    switch pageIndex {
                    case 0:
                        screenOne
                    case 1:
                        screenTwo
                    case 2:
                        screenLogin
                    case 3:
                        screenThree
                    case 4:
                        screenFour
                    default:
                        screenOne
                    }
                }
            }
            .onAppear { pageIndex = 0 }
            .onReceive(NotificationCenter.default.publisher(for: .supabaseAuthStateChanged)) { _ in
                if supabaseAuth.isAuthenticated {
                    // advance to permissions after login
                    pageIndex = 3
                    showEmailSheet = false
                }
            }
            .sheet(isPresented: $showEmailSheet) {
                NavigationStack {
                    ZStack {
                        Color.taqvoOnboardingBG.edgesIgnoringSafeArea(.all)
                        VStack(spacing: 16) {
                            Text("Sign in with Email")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Email")
                                    .foregroundColor(.gray)
                                TextField("you@example.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(12)
                                    .background(Color(white: 0.15))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)

                                Text("Password")
                                    .foregroundColor(.gray)
                                SecureField("••••••••", text: $password)
                                    .textContentType(.password)
                                    .padding(12)
                                    .background(Color(white: 0.15))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 32)

                            VStack(spacing: 12) {
                                Button(action: {
                                    guard !email.isEmpty, !password.isEmpty else { return }
                                    isSigningIn = true
                                    SupabaseAuthManager.shared.signInWithEmail(email: email, password: password)
                                }) {
                                    HStack {
                                        if isSigningIn { ProgressView().tint(.white) }
                                        Text("Sign In")
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 32)

                                Button(action: {
                                    guard !email.isEmpty, !password.isEmpty else { return }
                                    isSigningUp = true
                                    SupabaseAuthManager.shared.signUpWithEmail(email: email, password: password)
                                }) {
                                    HStack {
                                        if isSigningUp { ProgressView().tint(.white) }
                                        Text("Sign Up")
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 32)

                                if let err = supabaseAuth.lastAuthError, !err.isEmpty {
                                    Text(err)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                        .padding(.horizontal, 32)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showEmailSheet = false }
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }

    private var screenLogin: some View {
        ZStack {
            Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Text("Sign In")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text("Sign in to sync your data across devices")
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            SupabaseAuthManager.shared.signInWithApple()
                        }) {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Sign in with Apple")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(.white)
                            .cornerRadius(22)
                        }
                        
                        Button(action: { showEmailSheet = true }) {
                            Text("Sign In with Email")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.white)
                                .cornerRadius(22)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    // Simplified screenOne with system fonts for guaranteed visibility
    private var screenOne: some View {
        ZStack {
            Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 17) {
                    let titleView = Text("Smart ").foregroundColor(Color.taqvoCTA) + Text("Motion").foregroundColor(Color.white) + Text("\nTracking").foregroundColor(Color.white)
                    titleView
                        .font(.system(size: 36, weight: .bold))
                        .lineSpacing(0)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("Every step,").lineLimit(1)
                        Text("Every stride,").lineLimit(1)
                        Text("Every").lineLimit(1)
                        Text("...")
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                }
                .padding(.horizontal, 52)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .zIndex(1)
        }
        .onAppear {
            // Start dots blinking after a brief delay, then auto-advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dotsBlink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    pageIndex = 1
                }
            }
        }
    }

    private var screenTwo: some View {
        ZStack {
            Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Taqvo text - centered vertically regardless of button
                    let letters = Array("taqvo")
                    HStack(spacing: 0) {
                        ForEach(letters.indices, id: \.self) { i in
                            Text(String(letters[i]))
                                .foregroundColor(letterColored[i] ? .taqvoCTA : .white)
                        }
                    }
                    .font(.system(size: 96, weight: .bold))
                    .scaleEffect(brandScale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // Get Started button positioned at bottom center
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { pageIndex = 2 }) {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .underline()
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                        }
                        .opacity(showGetStartedButton ? 1.0 : 0.0)
                        Spacer()
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            screenTwoOpacity = 1.0
            brandScale = 4.0
            letterColored = Array(repeating: false, count: 5)
            showGetStartedButton = false
            
            DispatchQueue.main.async {
                // brand fades handled by scale only
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { brandScale = 1.0 }
            }
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30 + Double(i) * 0.06) {
                    withAnimation(.easeInOut(duration: 0.12)) { letterColored[i] = true }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { brandScale = 1.14 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.92)) { brandScale = 1.0 }
                    
                    // Show "Get Started" button 1 second after taqvo animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showGetStartedButton = true
                        }
                    }
                }
            }
        }
    }

    private var screenThree: some View {
        ZStack {
            Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 24) {
                    Text("Enable Permissions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Location").font(.headline).foregroundColor(.white)
                            Text("Required for route tracking").font(.caption).foregroundColor(Color.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: { permissionsVM.requestLocationAuthorization() }) {
                            Text(appState.locationAuthorized ? "Enabled" : "Enable")
                                .foregroundColor(Color(red: 17/255, green: 17/255, blue: 17/255))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.taqvoCTA)
                                .cornerRadius(12)
                        }
                        .disabled(appState.locationAuthorized)
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Motion & Fitness").font(.headline).foregroundColor(.white)
                            Text("Required for steps and cadence").font(.caption).foregroundColor(Color.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: {
                            permissionsVM.requestMotionAuthorization { granted in
                                appState.motionAuthorized = granted
                            }
                        }) {
                            Text(appState.motionAuthorized ? "Enabled" : "Enable")
                                .foregroundColor(Color(red: 17/255, green: 17/255, blue: 17/255))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.taqvoCTA)
                                .cornerRadius(12)
                        }
                        .disabled(appState.motionAuthorized)
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Background Tracking").font(.headline).foregroundColor(.white)
                            Text("Allows tracking if screen locks or you switch apps").font(.caption).foregroundColor(Color.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: { permissionsVM.requestAlwaysAuthorization() }) {
                            Text(appState.backgroundTrackingEnabled ? "Enabled" : "Enable")
                                .foregroundColor(Color(red: 17/255, green: 17/255, blue: 17/255))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.taqvoCTA)
                                .cornerRadius(12)
                        }
                        .disabled(appState.backgroundTrackingEnabled)
                    }
                    Button(action: { appState.hasCompletedOnboarding = true }) {
                        Text(appState.allRequiredPermissionsGranted ? "Continue" : "Continue (Permissions Required)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 17/255, green: 17/255, blue: 17/255))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .frame(height: 39)
                            .background(Color.taqvoCTA)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(!appState.allRequiredPermissionsGranted)
                }
                .padding(.horizontal, 32)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear {
            appState.locationAuthorized = permissionsVM.locationAuthorizedState
            appState.motionAuthorized = PermissionsViewModel.motionAuthorized()
            appState.backgroundTrackingEnabled = permissionsVM.alwaysAuthorizedState
        }
        .onReceive(permissionsVM.$locationAuthorizedState) { authorized in
            appState.locationAuthorized = authorized
        }
        .onReceive(permissionsVM.$alwaysAuthorizedState) { authorizedAlways in
            appState.backgroundTrackingEnabled = authorizedAlways
        }
    }

    private var screenFour: some View {
        ZStack {
            Color(red: 29/255, green: 31/255, blue: 37/255).ignoresSafeArea(.all)
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Text("Welcome to Taqvo")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text("You're all set. Tap continue to start.")
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: { appState.hasCompletedOnboarding = true }) {
                        Text("Continue")
                            .bold()
                            .foregroundColor(Color(red: 17/255, green: 17/255, blue: 17/255))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .frame(height: 39)
                            .background(Color.taqvoCTA)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(.horizontal, 32)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}