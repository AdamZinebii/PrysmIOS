import SwiftUI

struct DailySchedulingView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTimes: [Date] = []
    @State private var notificationsEnabled = true
    @State private var selectedFrequency: ScheduleFrequency = .daily
    @State private var selectedDuration: ReadingDuration = .medium
    @State private var showTimePicker = false
    @State private var tempTime = Date()
    
    let onComplete: ([Date], Bool, ScheduleFrequency, ReadingDuration) -> Void
    
    enum ScheduleFrequency: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        
        var localizedTitle: String {
            switch self {
            case .daily: return NSLocalizedString("schedule.daily", comment: "Daily")
            case .weekly: return NSLocalizedString("schedule.weekly", comment: "Weekly")
            }
        }
        
        var icon: String {
            switch self {
            case .daily: return "sun.max"
            case .weekly: return "calendar"
            }
        }
        
        var maxTimes: Int {
            switch self {
            case .daily: return 3
            case .weekly: return 1
            }
        }
    }
    
    enum ReadingDuration: String, CaseIterable {
        case short = "short"
        case medium = "medium"
        case long = "long"
        
        var localizedTitle: String {
            switch self {
            case .short: return NSLocalizedString("duration.short", comment: "5-10 minutes")
            case .medium: return NSLocalizedString("duration.medium", comment: "15-20 minutes")
            case .long: return NSLocalizedString("duration.long", comment: "30+ minutes")
            }
        }
        
        var description: String {
            switch self {
            case .short: return "5-10 min"
            case .medium: return "15-20 min"
            case .long: return "30+ min"
            }
        }
        
        var icon: String {
            switch self {
            case .short: return "clock"
            case .medium: return "clock.badge"
            case .long: return "clock.badge.checkmark"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text(localizedString("schedule_your_news"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(localizedString("schedule_description"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    
                    // Frequency Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.blue)
                            Text(localizedString("update_frequency"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 1), spacing: 12) {
                            ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                                FrequencyCard(
                                    frequency: frequency,
                                    isSelected: selectedFrequency == frequency
                                ) {
                                    selectedFrequency = frequency
                                    // Adjust selected times based on frequency
                                    adjustTimesForFrequency()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(localizedString("preferred_times"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        if selectedTimes.isEmpty {
                            Button(action: {
                                showTimePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text(localizedString("add_time"))
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        )
                                )
                                .foregroundColor(.blue)
                            }
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(selectedTimes.enumerated()), id: \.offset) { index, time in
                                    TimeCard(
                                        time: time,
                                        onDelete: {
                                            selectedTimes.remove(at: index)
                                        }
                                    )
                                }
                                
                                if selectedTimes.count < selectedFrequency.maxTimes {
                                    Button(action: {
                                        showTimePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle")
                                            Text(localizedString("add_another_time"))
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.secondarySystemBackground))
                                                .overlay(
                                                                                                RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                                )
                                        )
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Reading Duration
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.blue)
                            Text(localizedString("reading_duration"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(ReadingDuration.allCases, id: \.self) { duration in
                                DurationCard(
                                    duration: duration,
                                    isSelected: selectedDuration == duration
                                ) {
                                    selectedDuration = duration
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Notifications Toggle
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                            Text(localizedString("notifications"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedString("push_notifications"))
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(localizedString("notifications_description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Complete Button
                    Button(action: {
                        onComplete(selectedTimes, notificationsEnabled, selectedFrequency, selectedDuration)
                    }) {
                        HStack {
                            Text(localizedString("complete_setup"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Image(systemName: "checkmark")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .disabled(selectedTimes.isEmpty)
                        .opacity(selectedTimes.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(localizedString("daily_schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(localizedString("back")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                selectedTime: $tempTime,
                isPresented: $showTimePicker,
                onSave: {
                    selectedTimes.append(tempTime)
                    selectedTimes.sort()
                }
            )
        }
        .onAppear {
            // Set default times based on frequency
            setDefaultTimes()
        }
    }
    
    private func localizedString(_ key: String) -> String {
        return languageManager.localizedString(key)
    }
    
    private func adjustTimesForFrequency() {
        if selectedTimes.count > selectedFrequency.maxTimes {
            selectedTimes = Array(selectedTimes.prefix(selectedFrequency.maxTimes))
        }
        if selectedTimes.isEmpty {
            setDefaultTimes()
        }
    }
    
    private func setDefaultTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        selectedTimes.removeAll()
        
        switch selectedFrequency {
        case .daily:
            // Default: 8 AM
            if let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) {
                selectedTimes.append(morning)
            }
        case .weekly:
            // Default: Monday 9 AM
            if let monday = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) {
                selectedTimes.append(monday)
            }
        }
    }
}

struct FrequencyCard: View {
    let frequency: DailySchedulingView.ScheduleFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: frequency.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(frequency.localizedTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text("Up to \(frequency.maxTimes) time\(frequency.maxTimes > 1 ? "s" : "") per day")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

struct TimeCard: View {
    let time: Date
    let onDelete: () -> Void
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.blue)
            
            Text(timeString)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct DurationCard: View {
    let duration: DailySchedulingView.ReadingDuration
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: duration.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(duration.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    onSave()
                    isPresented = false
                }
            )
        }
    }
}

struct DailySchedulingView_Previews: PreviewProvider {
    static var previews: some View {
        DailySchedulingView { times, notifications, frequency, duration in
            print("Schedule set: \(times), notifications: \(notifications), frequency: \(frequency), duration: \(duration)")
        }
        .environmentObject(LanguageManager())
    }
} 