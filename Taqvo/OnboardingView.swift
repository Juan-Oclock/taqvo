import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var supabaseAuth = SupabaseAuthManager.shared
    @State private var currentPage: Int = 0
    @State private var showEmailSheet: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSigningIn: Bool = false
    @State private var isSigningUp: Bool = false
    @StateObject private var permissionsVM = PermissionsViewModel()
    
    let totalPages = 4
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 79/255, green: 79/255, blue: 79/255)
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // Main onboarding page
                mainOnboardingPage
                    .tag(0)
                
                // Getting to know you page
                GettingToKnowYouView(onComplete: {
                    withAnimation {
                        currentPage = 2
                    }
                })
                    .tag(1)
                
                // Permissions page
                permissionsPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseAuthStateChanged)) { _ in
            if supabaseAuth.isAuthenticated {
                // advance to getting to know you after login
                withAnimation {
                    currentPage = 1
                }
                showEmailSheet = false
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            emailSignInSheet
        }
    }
    
    // MARK: - Main Onboarding Page
    private var mainOnboardingPage: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color(red: 23/255, green: 23/255, blue: 23/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Hero Image Section - 50% of screen height
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            Image("running man")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.0)
                                .offset(y: 0)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
                        .clipped()
                        
                        // Decorative dots in top right
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 7, height: 7)
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 7, height: 7)
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 7, height: 7)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 11, height: 11)
                        }
                        .padding(.top, 74)
                        .padding(.trailing, 13)
                    }
                    .frame(height: geometry.size.height * 0.5)
                    
                    Spacer(minLength: 0)
                }
                
                // Content overlay - fills remaining 50%
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.5)
                    
                    // Curved background overlay
                    ZStack(alignment: .top) {
                        // Background shape with elliptical curve at top
                        CurvedTopShape()
                            .fill(Color(red: 32/255, green: 32/255, blue: 32/255)) // #202020 from Figma
                            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                            .background(.ultraThinMaterial.opacity(0.3)) // Backdrop blur effect
                            .offset(y: -20) // Offset to show the curve above the container
                    
                    VStack(spacing: 0) {
                        // TAQVO branding with gradient
                        Text("taqvo")
                            .font(.system(size: 40, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(red: 32/255, green: 32/255, blue: 32/255, opacity: 0.54), location: -0.1452),
                                        .init(color: Color(red: 1, green: 1, blue: 1, opacity: 0.42), location: 0.5103),
                                        .init(color: Color(red: 34/255, green: 34/255, blue: 34/255, opacity: 0.50), location: 1.129)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.top, 0)
                        
                        // Main headline
                        Text("Leave The Chaos To\nYour Group Chat")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 16)
                            .padding(.horizontal, 27)
                        
                        // Subtitle
                        Text("The clean, focused running app that keep\ndistractions out and your pace in check.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(red: 179/255, green: 179/255, blue: 179/255))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                            .padding(.horizontal, 27)
                        
                        // Sign up with Email button
                        Button(action: { showEmailSheet = true }) {
                            Text("Sign up with Email")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 23/255, green: 23/255, blue: 23/255))
                                .frame(width: 300, height: 52)
                                .background(Color.taqvoCTA)
                                .cornerRadius(49)
                        }
                        .padding(.top, 33)
                        
                        // Divider with text
                        HStack(spacing: 12) {
                            // Left line - gradient from white to transparent (fades out to the left)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white,
                                            Color.white.opacity(0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.5)
                            
                            Text("Or continue with")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(red: 179/255, green: 179/255, blue: 179/255))
                            
                            // Right line - gradient from transparent to white (fades in from the right)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0),
                                            Color.white
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        
                        // Social login buttons
                        HStack(spacing: 16) {
                            // Google
                            Button(action: {
                                // Google sign in
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 23/255, green: 23/255, blue: 23/255))
                                        .frame(width: 60, height: 60)
                                    
                                    Image("google")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 27, height: 27)
                                }
                            }
                            
                            // Facebook
                            Button(action: {
                                // Facebook sign in
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 23/255, green: 23/255, blue: 23/255))
                                        .frame(width: 60, height: 60)
                                    
                                    Image("facebook")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 27, height: 27)
                                }
                            }
                            
                            // Apple
                            Button(action: {
                                SupabaseAuthManager.shared.signInWithApple()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 23/255, green: 23/255, blue: 23/255))
                                        .frame(width: 60, height: 60)
                                    
                                    Image("apple")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 27, height: 27)
                                }
                            }
                            
                            // X (Twitter)
                            Button(action: {
                                // X sign in
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 23/255, green: 23/255, blue: 23/255))
                                        .frame(width: 60, height: 60)
                                    
                                    Image("twitter")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 27, height: 27)
                                }
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Email Sign In Sheet
    private var emailSignInSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 79/255, green: 79/255, blue: 79/255)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        Text("Sign up with Email")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 32)
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(16)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            SecureField("••••••••", text: $password)
                                .textContentType(.password)
                                .padding(16)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        // Sign In button
                        Button(action: {
                            guard !email.isEmpty, !password.isEmpty else { return }
                            isSigningIn = true
                            SupabaseAuthManager.shared.signInWithEmail(email: email, password: password)
                        }) {
                            HStack {
                                if isSigningIn {
                                    ProgressView()
                                        .tint(.black)
                                }
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.taqvoCTA)
                            .cornerRadius(28)
                        }
                        .disabled(isSigningIn)
                        .padding(.top, 8)
                        
                        // Sign Up button
                        Button(action: {
                            guard !email.isEmpty, !password.isEmpty else { return }
                            isSigningUp = true
                            SupabaseAuthManager.shared.signUpWithEmail(email: email, password: password)
                        }) {
                            HStack {
                                if isSigningUp {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Sign Up")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(28)
                        }
                        .disabled(isSigningUp)
                        
                        // Error message
                        if let err = supabaseAuth.lastAuthError, !err.isEmpty {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showEmailSheet = false
                    }
                    .foregroundColor(.taqvoCTA)
                }
            }
        }
    }
    
    // MARK: - Permissions Page
    private var permissionsPage: some View {
        ZStack {
            Color(red: 79/255, green: 79/255, blue: 79/255)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    Text("Enable Permissions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    
                    Text("To provide the best experience, we need access to:")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("You can always set these later in Settings")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                    
                    VStack(spacing: 16) {
                        // Location permission
                        PermissionCard(
                            icon: "location.fill",
                            title: "Location",
                            description: "Required for route tracking",
                            isEnabled: appState.locationAuthorized,
                            action: {
                                permissionsVM.requestLocationAuthorization()
                            }
                        )
                        
                        // Motion permission
                        PermissionCard(
                            icon: "figure.walk",
                            title: "Motion & Fitness",
                            description: "Required for steps and cadence",
                            isEnabled: appState.motionAuthorized,
                            action: {
                                permissionsVM.requestMotionAuthorization { granted in
                                    appState.motionAuthorized = granted
                                }
                            }
                        )
                        
                        // Background tracking permission
                        PermissionCard(
                            icon: "location.circle.fill",
                            title: "Background Tracking",
                            description: "Allows tracking if screen locks or you switch apps",
                            isEnabled: appState.backgroundTrackingEnabled,
                            action: {
                                permissionsVM.requestAlwaysAuthorization()
                            }
                        )
                        
                        // Notification permission
                        PermissionCard(
                            icon: "bell.fill",
                            title: "Notifications",
                            description: "Get reminders and activity updates",
                            isEnabled: permissionsVM.notificationAuthorized,
                            action: {
                                permissionsVM.requestNotificationAuthorization()
                            }
                        )
                        
                        // Camera permission
                        PermissionCard(
                            icon: "camera.fill",
                            title: "Camera",
                            description: "Take photos during your activities",
                            isEnabled: permissionsVM.cameraAuthorized,
                            action: {
                                permissionsVM.requestCameraAuthorization()
                            }
                        )
                        
                        // Calendar permission
                        PermissionCard(
                            icon: "calendar",
                            title: "Calendar",
                            description: "Schedule and track your workout plans",
                            isEnabled: permissionsVM.calendarAuthorized,
                            action: {
                                permissionsVM.requestCalendarAuthorization()
                            }
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    
                    // Continue button
                    Button(action: {
                        appState.hasCompletedOnboarding = true
                    }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.taqvoCTA)
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    
                    // Skip button
                    Button(action: {
                        appState.hasCompletedOnboarding = true
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            appState.locationAuthorized = permissionsVM.locationAuthorizedState
            appState.motionAuthorized = PermissionsViewModel.motionAuthorized()
            appState.backgroundTrackingEnabled = permissionsVM.alwaysAuthorizedState
            
            // Check new permissions
            permissionsVM.checkNotificationAuthorization()
            permissionsVM.checkCameraAuthorization()
            permissionsVM.checkCalendarAuthorization()
        }
        .onReceive(permissionsVM.$locationAuthorizedState) { authorized in
            appState.locationAuthorized = authorized
        }
        .onReceive(permissionsVM.$alwaysAuthorizedState) { authorizedAlways in
            appState.backgroundTrackingEnabled = authorizedAlways
        }
    }
}

// MARK: - Permission Card Component
struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.taqvoCTA)
                .frame(width: 44, height: 44)
                .background(Color.taqvoCTA.opacity(0.1))
                .clipShape(Circle())
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Enable button
            Button(action: action) {
                Text(isEnabled ? "Enabled" : "Enable")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isEnabled ? .white.opacity(0.5) : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isEnabled ? Color.white.opacity(0.1) : Color.taqvoCTA)
                    .cornerRadius(20)
            }
            .disabled(isEnabled)
        }
        .padding(16)
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
    }
}

// MARK: - Custom Shape for Curved Top (Union of Ellipse + Rectangle)
struct CurvedTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Gentler curve that starts from the very edges
        let curveDepth: CGFloat = 25 // Reduced depth for gentler arc
        
        // Start from bottom-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge going up to top-left corner (start of curve)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Create smooth elliptical curve at top using cubic bezier
        // Curve starts from very left edge (0,0) to very right edge
        let cp1 = CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY - curveDepth)
        let cp2 = CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY - curveDepth)
        
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: cp1,
            control2: cp2
        )
        
        // Right edge going down
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge back to start
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Custom Shape for Top Rounded Corners (Legacy)
struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left, after the corner radius
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        
        // Top-right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge (straight)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge (straight)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge (straight) - close the path
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
