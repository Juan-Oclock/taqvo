//
//  GettingToKnowYouView.swift
//  Taqvo
//
//  Created by Assistant on 10/25/25
//

import SwiftUI

struct GettingToKnowYouView: View {
    @EnvironmentObject var appState: AppState
    var onComplete: () -> Void = {}
    @State private var name: String = ""
    @State private var birthdate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var location: String = ""
    @State private var showDatePicker: Bool = false
    @State private var showCountryPicker: Bool = false
    @State private var countrySearchText: String = ""
    
    // Activity Goals
    @State private var selectedActivityType: ActivityIntentType = .run
    @State private var goalType: GoalIntentType = .none
    @State private var distanceGoal: Double = 5.0 // km
    @State private var timeGoal: Double = 30.0 // minutes
    @State private var frequencyPerWeek: Int = 3 // times per week
    @State private var isGoalConfirmed: Bool = false // Track if user confirmed goal
    
    @State private var currentStep: Int = 0 // 0 = personal info, 1 = activity goals, 2 = goal summary
    
    let totalSteps = 3
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 79/255, green: 79/255, blue: 79/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Progress indicator
                progressIndicator
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if currentStep == 0 {
                            personalInfoSection
                        } else if currentStep == 1 {
                            activityGoalsSection
                        } else {
                            goalSummarySection
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
                
                // Bottom buttons
                bottomButtons
            }
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showCountryPicker) {
            countryPickerSheet
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text("Getting to Know You")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(currentStep == 0 ? "Tell us about yourself" : "Set your activity goals")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index <= currentStep ? Color.taqvoCTA : Color.white.opacity(0.2))
                    .frame(height: 4)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
    
    // MARK: - Personal Info Section
    private var personalInfoSection: some View {
        VStack(spacing: 20) {
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .font(.system(size: 17))
            }
            
            // Birthdate picker
            VStack(alignment: .leading, spacing: 8) {
                Text("BIRTHDATE")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                Button(action: { showDatePicker = true }) {
                    HStack {
                        Text(birthdate, style: .date)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            
            // Location field (Country picker)
            VStack(alignment: .leading, spacing: 8) {
                Text("LOCATION")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                Button(action: { showCountryPicker = true }) {
                    HStack {
                        Text(location.isEmpty ? "Select country" : location)
                            .font(.system(size: 17))
                            .foregroundColor(location.isEmpty ? .white.opacity(0.4) : .white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            
            // Info text
            Text("This information helps us personalize your experience and connect you with nearby runners.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Activity Goals Section
    private var activityGoalsSection: some View {
        VStack(spacing: 24) {
            // Activity Type Selection (Single Line)
            VStack(alignment: .leading, spacing: 12) {
                Text("PREFERRED ACTIVITY")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                HStack(spacing: 8) {
                    CompactActivityTypeCard(
                        type: .walk,
                        isSelected: selectedActivityType == .walk,
                        action: { selectedActivityType = .walk }
                    )
                    
                    CompactActivityTypeCard(
                        type: .run,
                        isSelected: selectedActivityType == .run,
                        action: { selectedActivityType = .run }
                    )
                    
                    CompactActivityTypeCard(
                        type: .trailRun,
                        isSelected: selectedActivityType == .trailRun,
                        action: { selectedActivityType = .trailRun }
                    )
                    
                    CompactActivityTypeCard(
                        type: .hiking,
                        isSelected: selectedActivityType == .hiking,
                        action: { selectedActivityType = .hiking }
                    )
                }
            }
            
            // Goal Type Selection (Accordion Style)
            VStack(alignment: .leading, spacing: 12) {
                Text("DEFAULT GOAL TYPE")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                VStack(spacing: 12) {
                    // Free Run
                    AccordionGoalCard(
                        icon: "infinity",
                        title: "Free Run",
                        description: "No specific goal",
                        isSelected: goalType == .none,
                        isExpanded: false,
                        action: { 
                            withAnimation(.spring(response: 0.3)) {
                                goalType = .none
                            }
                        },
                        content: { EmptyView() }
                    )
                    
                    // Distance Goal with Frequency
                    AccordionGoalCard(
                        icon: "location.fill",
                        title: "Distance Goal",
                        description: "Set distance & frequency",
                        isSelected: goalType == .distance,
                        isExpanded: goalType == .distance,
                        action: { 
                            withAnimation(.spring(response: 0.3)) {
                                goalType = .distance
                            }
                        },
                        content: { distanceGoalWithFrequency }
                    )
                    
                    // Time Goal with Frequency
                    AccordionGoalCard(
                        icon: "clock.fill",
                        title: "Time Goal",
                        description: "Set duration & frequency",
                        isSelected: goalType == .time,
                        isExpanded: goalType == .time,
                        action: { 
                            withAnimation(.spring(response: 0.3)) {
                                goalType = .time
                            }
                        },
                        content: { timeGoalWithFrequency }
                    )
                }
            }
            
            // Info text
            Text("You can always change these settings later in your profile.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Goal Summary Section
    private var goalSummarySection: some View {
        VStack(spacing: 24) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.taqvoCTA.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(.taqvoCTA)
            }
            .padding(.top, 10)
            
            // Title
            VStack(spacing: 8) {
                Text("Great Start, \(name.isEmpty ? "there" : name)!")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("You've set your goal")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Goal Summary Card (wider with less padding)
            VStack(spacing: 16) {
                // Activity Icon
                Image(systemName: activityIconForType(selectedActivityType))
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(activityColorForType(selectedActivityType))
                
                // Goal Description
                VStack(spacing: 6) {
                    Text(goalSummaryText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if goalType != .none {
                        Text(goalDetailText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Edit Goal Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep = 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                        Text("Edit Goal")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.taqvoCTA)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.taqvoCTA.opacity(0.15))
                    .cornerRadius(18)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.2))
            .cornerRadius(20)
            
            Spacer()
        }
    }
    
    // Helper computed properties for goal summary
    private var goalSummaryText: String {
        let activity = selectedActivityType.rawValue.capitalized
        
        switch goalType {
        case .none:
            return "You've set to \(activity) with no specific goal"
        case .distance:
            return "You've set to \(activity)\n\(frequencyPerWeek)x a week at \(String(format: "%.1f", distanceGoal))km each"
        case .time:
            return "You've set to \(activity)\n\(frequencyPerWeek)x a week at \(String(format: "%.0f", timeGoal))min each"
        }
    }
    
    private var goalDetailText: String {
        switch goalType {
        case .none:
            return "Track your activities freely without targets"
        case .distance:
            let totalDistance = distanceGoal * Double(frequencyPerWeek)
            return "That's \(String(format: "%.1f", totalDistance))km per week"
        case .time:
            let totalTime = timeGoal * Double(frequencyPerWeek)
            return "That's \(String(format: "%.0f", totalTime)) minutes per week"
        }
    }
    
    private func activityIconForType(_ type: ActivityIntentType) -> String {
        switch type {
        case .walk: return "figure.walk"
        case .run: return "figure.run"
        case .trailRun: return "figure.run.circle"
        case .hiking: return "figure.hiking"
        }
    }
    
    private func activityColorForType(_ type: ActivityIntentType) -> Color {
        switch type {
        case .walk: return .blue
        case .run: return .red
        case .trailRun: return .orange
        case .hiking: return .green
        }
    }
    
    // MARK: - Distance Goal with Frequency
    private var distanceGoalWithFrequency: some View {
        VStack(spacing: 16) {
            // Distance Slider
            VStack(spacing: 12) {
                Text("Distance per session")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Spacer()
                    Text(String(format: "%.1f", distanceGoal))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("km")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 4)
                    Spacer()
                }
                
                Slider(value: $distanceGoal, in: 1...42.2, step: 0.5)
                    .tint(.taqvoCTA)
                
                HStack {
                    Text("1 km")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("42.2 km")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Frequency Picker (reduced top spacing)
            VStack(spacing: 12) {
                Text("Frequency per week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        Button(action: {
                            withAnimation(.spring(response: 0.2)) {
                                frequencyPerWeek = day
                            }
                        }) {
                            Text("\(day)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(frequencyPerWeek == day ? .black : .white)
                                .frame(width: 40, height: 40)
                                .background(frequencyPerWeek == day ? Color.taqvoCTA : Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Summary
            Text("\(selectedActivityType.rawValue.capitalized), \(frequencyPerWeek)x/week, \(String(format: "%.1f", distanceGoal))km each")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.taqvoCTA)
                .multilineTextAlignment(.center)
            
            // Set Goal Button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    goalType = .distance
                    isGoalConfirmed = true
                }
            }) {
                HStack(spacing: 8) {
                    if isGoalConfirmed && goalType == .distance {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isGoalConfirmed && goalType == .distance ? "Goal Set" : "Set Goal")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.taqvoCTA)
                .cornerRadius(12)
            }
        }
        .padding(16)
    }
    
    // MARK: - Time Goal with Frequency
    private var timeGoalWithFrequency: some View {
        VStack(spacing: 16) {
            // Time Slider
            VStack(spacing: 12) {
                Text("Duration per session")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Spacer()
                    Text(String(format: "%.0f", timeGoal))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("min")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 4)
                    Spacer()
                }
                
                Slider(value: $timeGoal, in: 10...180, step: 5)
                    .tint(.taqvoCTA)
                
                HStack {
                    Text("10 min")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("180 min")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Frequency Picker (reduced top spacing)
            VStack(spacing: 12) {
                Text("Frequency per week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        Button(action: {
                            withAnimation(.spring(response: 0.2)) {
                                frequencyPerWeek = day
                            }
                        }) {
                            Text("\(day)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(frequencyPerWeek == day ? .black : .white)
                                .frame(width: 40, height: 40)
                                .background(frequencyPerWeek == day ? Color.taqvoCTA : Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Summary
            Text("\(selectedActivityType.rawValue.capitalized), \(frequencyPerWeek)x/week, \(String(format: "%.0f", timeGoal))min each")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.taqvoCTA)
                .multilineTextAlignment(.center)
            
            // Set Goal Button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    goalType = .time
                    isGoalConfirmed = true
                }
            }) {
                HStack(spacing: 8) {
                    if isGoalConfirmed && goalType == .time {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isGoalConfirmed && goalType == .time ? "Goal Set" : "Set Goal")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.taqvoCTA)
                .cornerRadius(12)
            }
        }
        .padding(16)
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // Next/Continue/Get Started button
            Button(action: {
                if currentStep == 0 {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep = 1
                    }
                } else if currentStep == 1 {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep = 2
                    }
                } else {
                    saveAndComplete()
                }
            }) {
                Text(currentStep == 0 ? "Next" : currentStep == 1 ? "Continue" : "Get Started")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isCurrentStepValid ? Color.taqvoCTA : Color.white.opacity(0.2))
                    .cornerRadius(28)
            }
            .disabled(!isCurrentStepValid)
            
            // Back/Skip button
            Button(action: {
                if currentStep == 0 {
                    // Skip to permissions
                    onComplete()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep -= 1
                    }
                }
            }) {
                Text(currentStep == 0 ? "Skip for now" : "Back")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color(red: 79/255, green: 79/255, blue: 79/255))
    }
    
    // MARK: - Validation
    private var isCurrentStepValid: Bool {
        if currentStep == 0 {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return true // Activity goals are optional
        }
    }
    
    // MARK: - Save and Complete
    private func saveAndComplete() {
        // Save user preferences to AppState or UserDefaults
        // Save to profileUsername for consistency with profile settings
        UserDefaults.standard.set(name, forKey: "profileUsername")
        UserDefaults.standard.set(birthdate, forKey: "userBirthdate")
        UserDefaults.standard.set(location, forKey: "userLocation")
        UserDefaults.standard.set(selectedActivityType.rawValue, forKey: "preferredActivityType")
        UserDefaults.standard.set(goalType.rawValue, forKey: "defaultGoalType")
        
        if goalType == .distance {
            UserDefaults.standard.set(distanceGoal * 1000, forKey: "defaultDistanceGoalMeters") // Convert to meters
        } else if goalType == .time {
            UserDefaults.standard.set(timeGoal * 60, forKey: "defaultTimeGoalSeconds") // Convert to seconds
        }
        
        // Save frequency
        UserDefaults.standard.set(frequencyPerWeek, forKey: "defaultFrequencyPerWeek")
        
        // Navigate to permissions page
        onComplete()
    }
    
    // MARK: - Date Picker Sheet
    private var datePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 79/255, green: 79/255, blue: 79/255)
                    .ignoresSafeArea()
                
                VStack {
                    Text("Choose Date of Birth")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    DatePicker(
                        "",
                        selection: $birthdate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Buttons
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button("OK") {
                            showDatePicker = false
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.taqvoCTA)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .presentationDetents([.height(400)])
        }
    }
    
    // MARK: - Country Picker Sheet
    private var countryPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 79/255, green: 79/255, blue: 79/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    Text("Select Country")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 20)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        TextField("Search countries", text: $countrySearchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    // Country list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredCountries, id: \.self) { country in
                                Button(action: {
                                    location = country
                                    showCountryPicker = false
                                }) {
                                    HStack {
                                        Text(country)
                                            .font(.system(size: 17))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if location == country {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.taqvoCTA)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.black.opacity(0.0))
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showCountryPicker = false
                    }
                    .foregroundColor(.taqvoCTA)
                }
            }
        }
    }
    
    // MARK: - Countries List
    private var filteredCountries: [String] {
        if countrySearchText.isEmpty {
            return countries
        } else {
            return countries.filter { $0.localizedCaseInsensitiveContains(countrySearchText) }
        }
    }
    
    private let countries = [
        "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda",
        "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain",
        "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bhutan",
        "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria",
        "Burkina Faso", "Burundi", "Cabo Verde", "Cambodia", "Cameroon", "Canada",
        "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros",
        "Congo", "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czech Republic", "Denmark",
        "Djibouti", "Dominica", "Dominican Republic", "East Timor", "Ecuador", "Egypt",
        "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia",
        "Fiji", "Finland", "France", "Gabon", "Gambia", "Georgia", "Germany", "Ghana",
        "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana", "Haiti",
        "Honduras", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland",
        "Israel", "Italy", "Jamaica", "Japan", "Jordan", "Kazakhstan", "Kenya", "Kiribati",
        "Kosovo", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia",
        "Libya", "Liechtenstein", "Lithuania", "Luxembourg", "Madagascar", "Malawi", "Malaysia",
        "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico",
        "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique",
        "Myanmar", "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua",
        "Niger", "Nigeria", "North Korea", "North Macedonia", "Norway", "Oman", "Pakistan",
        "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines",
        "Poland", "Portugal", "Qatar", "Romania", "Russia", "Rwanda", "Saint Kitts and Nevis",
        "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa", "San Marino",
        "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles",
        "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia",
        "South Africa", "South Korea", "South Sudan", "Spain", "Sri Lanka", "Sudan",
        "Suriname", "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan", "Tanzania",
        "Thailand", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan",
        "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States",
        "Uruguay", "Uzbekistan", "Vanuatu", "Vatican City", "Venezuela", "Vietnam", "Yemen",
        "Zambia", "Zimbabwe"
    ]
}

// MARK: - Compact Activity Type Card Component (Single Line)
struct CompactActivityTypeCard: View {
    let type: ActivityIntentType
    let isSelected: Bool
    let action: () -> Void
    
    private var iconName: String {
        switch type {
        case .walk: return "figure.walk"
        case .run: return "figure.run"
        case .trailRun: return "figure.run.circle"
        case .hiking: return "figure.hiking"
        }
    }
    
    private var color: Color {
        switch type {
        case .walk: return .blue
        case .run: return .red
        case .trailRun: return .orange
        case .hiking: return .green
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? color : .white.opacity(0.6))
                
                Text(type.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                isSelected ? color.opacity(0.15) : Color.black.opacity(0.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Accordion Goal Card Component
struct AccordionGoalCard<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: action) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .taqvoCTA : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(
                            isSelected ? Color.taqvoCTA.opacity(0.15) : Color.white.opacity(0.05)
                        )
                        .clipShape(Circle())
                    
                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Chevron or checkmark
                    if isSelected && isExpanded {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.taqvoCTA)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.taqvoCTA)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(16)
            }
            
            // Expanded content
            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            isSelected ? Color.taqvoCTA.opacity(0.1) : Color.black.opacity(0.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.taqvoCTA : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

#Preview {
    GettingToKnowYouView()
        .environmentObject(AppState())
}
