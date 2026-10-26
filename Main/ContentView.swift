//
//  ContentView.swift
//  Main
//  Hiiiiiii Its the GALP LEO GALP, GEHEHEHEHEHEHEHE
//  Created by av3ry on 9/21/25.
//


// Test #2 (Pull and Push)
import SwiftUI
import HealthKit
import Charts
import AVFoundation
import UserNotifications
import Charts

struct ExposurePoint: Identifiable {
    let id = UUID()
    let date: Date
    let decibels: Double
    let type: ExposureType
}

struct ExposureSample {
    let date: Date
    let decibels: Double
    let duration: TimeInterval
}

enum ExposureType {
    case average, max
}

enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"
}

struct HearingTestResult: Codable {
    let date: Date
    let leftEar: [String: Float]
    let rightEar: [String: Float]
}

// Shared UI helpers (DayStatus, Color.brand, card(), StatCard, PressableStyle) live in SharedUI.swift.

// MARK: - Tabs

struct ContentView: View {
    var body: some View {
        TabView {
            //NEW 10/22/26 LEO
            ProgressViewScreen()
                .tabItem { Label("Progress", systemImage: "star.circle.fill") }
            PitchChallengeView()
                .tabItem { Label("Challenge", systemImage: "music.note") }
            StreakView()
                .tabItem { Label("Streak", systemImage: "flame") }
            TestView()
                .tabItem { Label("Test", systemImage: "ear") }
            DataView()
                .tabItem { Label("Data", systemImage: "chart.xyaxis.line") }
        }
        .tint(.brand)
    }
}

// MARK: - Streak

struct StreakView: View {
    
    @State private var streakCount = 0
    @State private var installDate: Date = UserDefaults.standard.object(forKey: "installDate") as? Date ?? Date()
    private let healthStore = HKHealthStore()
    @State private var isLoading = true
    @State private var bestStreak: Int = UserDefaults.standard.integer(forKey: "bestStreak")
    @State private var todayIsSafe = false
    @State private var exposureSamples: [ExposureSample] = []
    private let threshold = 85.0
    private let dailyLimitSeconds = 1800.0
    @State private var showingExportPrompt = false
    @State private var phoneLastFour = ""
    @State private var exportURLs: [URL] = []
    @State private var showingShareSheet = false
    @State private var todayLoudSeconds: Double = 0
    @State private var lastSevenDays: [DayStatus] = []
    
    func requestPermission() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        // `success` only means the prompt was handled, not that access was granted,
        // so always fetch. A denied user simply gets an empty result.
        healthStore.requestAuthorization(toShare: [], read: [exposureType]) { _, _ in
            fetchStreakData()
        }
    }
    
    func exportData(phoneLastFour: String, completion: @escaping ([URL]) -> Void) {
        let calendar = Calendar.current
        let fourMonthsAgo = calendar.date(byAdding: .month, value: -4, to: Date())!
        
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: fourMonthsAgo, end: Date())
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: exposureType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            let samples = (samples as? [HKQuantitySample]) ?? []
            
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            
            // Build exposure CSV
            var exposureCSV = "Date,Average dB,Max dB\n"
            var grouped: [Date: [Double]] = [:]
            
            for sample in samples {
                let day = calendar.startOfDay(for: sample.startDate)
                let db = sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
                grouped[day, default: []].append(db)
            }
            
            for (day, values) in grouped.sorted(by: { $0.key < $1.key }) {
                let avg = values.reduce(0, +) / Double(values.count)
                let max = values.max() ?? avg
                exposureCSV += "\(formatter.string(from: day)),\(String(format: "%.1f", avg)),\(String(format: "%.1f", max))\n"
            }
            
            // Build hearing CSV
            var hearingCSV = "Date,Frequency,Left Ear,Right Ear\n"
            if let data = UserDefaults.standard.data(forKey: "hearingTestResults"),
               let results = try? JSONDecoder().decode([HearingTestResult].self, from: data) {
                for test in results {
                    for freq in [250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0] {
                        let left = test.leftEar[String(freq)] ?? 0
                        let right = test.rightEar[String(freq)] ?? 0
                        hearingCSV += "\(formatter.string(from: test.date)),\(Int(freq)),\(left),\(right)\n"
                    }
                }
            }
            
            // Write files
            let tempDir = FileManager.default.temporaryDirectory
            let exposureURL = tempDir.appendingPathComponent("exposure_\(phoneLastFour).csv")
            let hearingURL = tempDir.appendingPathComponent("hearing_\(phoneLastFour).csv")
            
            try? exposureCSV.write(to: exposureURL, atomically: true, encoding: .utf8)
            try? hearingCSV.write(to: hearingURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                completion([exposureURL, hearingURL])
            }
        }
        
        healthStore.execute(query)
    }
    
    func scheduleStreakNotification() {
        print("notif")
        let notif = UNUserNotificationCenter.current()
        
        notif.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            
            content.title = "Streak Alert!"
            content.body = "Open the app to check your streak!"
            content.sound = .default
            
            var dateComponents = DateComponents()
            dateComponents.hour = 19
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "dailystreak", content: content, trigger: trigger)
            
            notif.removePendingNotificationRequests(withIdentifiers: ["dailystreak"])
            notif.add(request)
        }
    }
    
    func fetchStreakData() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let predicate = HKQuery.predicateForSamples(withStart: installDate, end: Date())
        
        let query = HKSampleQuery(
            sampleType: exposureType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            // Empty on error or no data, so loading always finishes.
            let samples = (samples as? [HKQuantitySample]) ?? []
            
            var newSamples: [ExposureSample] = []
            for sample in samples {
                let db = sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                newSamples.append(ExposureSample(date: sample.startDate, decibels: db, duration: duration))
            }
            
            DispatchQueue.main.async {
                exposureSamples = newSamples
                calculateStreak()
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let installDay = calendar.startOfDay(for: installDate)
        
        var dailyLoudSeconds: [Date: Double] = [:]
        
        for sample in exposureSamples {
            let day = calendar.startOfDay(for: sample.date)
            if sample.decibels >= threshold {
                dailyLoudSeconds[day, default: 0] += sample.duration
            }
        }
        var dailySafe: [Date: Bool] = [:]
        for (day, seconds) in dailyLoudSeconds {
            dailySafe[day] = seconds < dailyLimitSeconds
        }
        todayIsSafe = dailySafe[today] ?? true
        todayLoudSeconds = dailyLoudSeconds[today] ?? 0
        lastSevenDays = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayStatus(date: day, safe: dailySafe[day] ?? true, beforeInstall: day < installDay)
        }
        var current = 0
        var checking = today
        
        while checking >= installDay {
            let isSafe = checking == installDay ? true : dailySafe[checking] ?? true
            if isSafe {
                current += 1
                checking = calendar.date(byAdding: .day, value: -1, to: checking)!
            } else {
                break
            }
        }
        
        if current > bestStreak {
            bestStreak = current
            UserDefaults.standard.set(current, forKey: "bestStreak")
        }
        streakCount = current
        isLoading = false
        print(current)
    }
    
    private var limitMinutes: Int { Int(dailyLimitSeconds / 60) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Fetching data...")
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(Color.brand.opacity(0.15), lineWidth: 18)
                                Circle()
                                    .trim(from: 0, to: min(todayLoudSeconds / dailyLimitSeconds, 1))
                                    .stroke(todayIsSafe ? Color.brand : Color.red,
                                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeOut(duration: 0.8), value: todayLoudSeconds)
                                VStack(spacing: 0) {
                                    Text("\(streakCount)")
                                        .font(.system(size: 60, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                    Text("day streak")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 200, height: 200)
                            .padding(.top, 8)
                            
                            Text(todayIsSafe
                                 ? "\(Int(todayLoudSeconds / 60)) of \(limitMinutes) loud minutes used today"
                                 : "Over today's \(limitMinutes) minute limit")
                                .font(.subheadline)
                                .foregroundStyle(todayIsSafe ? Color.secondary : Color.red)
                        }
                        .frame(maxWidth: .infinity)
                        .card()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last 7 days")
                                .font(.headline)
                            HStack {
                                ForEach(lastSevenDays) { day in
                                    VStack(spacing: 6) {
                                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Circle()
                                            .fill(day.beforeInstall ? Color(.systemGray5)
                                                  : day.safe ? Color.brand : Color.red.opacity(0.85))
                                            .frame(width: 30, height: 30)
                                            .overlay {
                                                if !day.beforeInstall {
                                                    Image(systemName: day.safe ? "checkmark" : "xmark")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .card()
                        
                        HStack(spacing: 16) {
                            StatCard(title: "Best streak", value: "\(bestStreak)",
                                     unit: bestStreak == 1 ? "day" : "days")
                            StatCard(title: "Daily limit", value: "\(limitMinutes)", unit: "min")
                        }
                        
                        Text("A day counts toward your streak when you spend less than \(limitMinutes) minutes listening at \(Int(threshold)) dB or louder.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Streak")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExportPrompt = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export data")
                }
            }
            .alert("Export Data", isPresented: $showingExportPrompt) {
                TextField("Last 4 digits of phone", text: $phoneLastFour)
                    .keyboardType(.numberPad)
                Button("Export") {
                    exportData(phoneLastFour: phoneLastFour) { urls in
                        exportURLs = urls
                        showingShareSheet = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Exports the last four months of listening levels and your hearing test results as CSV files.")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: exportURLs)
            }
            .onAppear {
                print("appear")
                scheduleStreakNotification()
                if UserDefaults.standard.object(forKey: "installDate") == nil {
                    UserDefaults.standard.set(Date(), forKey: "installDate")
                }
                requestPermission()
            }
        }
    }
}

// MARK: - Hearing test

struct TestView: View {
    @State private var currentFrequency: Double = 1000.0
    @State private var currentVolume: Float = 0.5
    @State private var isPlaying = false
    @State private var testStarted = false
    @State private var currentEar: String = "left"
    // Note: despite the name, this holds the LEFT ear results once the left ear finishes.
    @State private var rightEarResults: [Double: Float] = [:]
    
    let frequencies: [Double] = [250, 500, 1000, 2000, 4000, 8000]
    
    @State private var frequencyIndex: Int = 0
    @State private var audioengine = AVAudioEngine()
    @State private var results: [Double: Float] = [:]
    @State private var playerNode = AVAudioPlayerNode()
    @State private var testComplete = false
    @State private var timer: Timer? = nil
    
    func saveTestResult() {
        var leftDict: [String: Float] = [:]
        var rightDict: [String: Float] = [:]
        
        for (freq, value) in rightEarResults {
            leftDict[String(freq)] = value
        }
        for (freq, value) in results {
            rightDict[String(freq)] = value
        }
        
        let result = HearingTestResult(date: Date(), leftEar: leftDict, rightEar: rightDict)
        
        var saved: [HearingTestResult] = []
        if let data = UserDefaults.standard.data(forKey: "hearingTestResults"),
           let decoded = try? JSONDecoder().decode([HearingTestResult].self, from: data) {
            saved = decoded
        }
        
        saved.append(result)
        
        if let encoded = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(encoded, forKey: "hearingTestResults")
        }
    }
    
    func playTone(frequency: Double, volume: Float) {
        print("Playing \(frequency) Hz at volume \(volume) for \(currentEar) ear")
        audioengine.stop()
        audioengine.reset()
        let sampleRate: Double = 44100.0
        let duration: Double = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let leftChannel = buffer.floatChannelData![0]
        let rightChannel = buffer.floatChannelData![1]
        
        for frame in 0..<Int(frameCount) {
            let sample = sin(2.0 * Float.pi * Float(frequency) * Float(frame) / Float(sampleRate)) * volume
            leftChannel[frame] = currentEar == "left" ? sample : 0
            rightChannel[frame] = currentEar == "right" ? sample : 0
        }
        
        audioengine.attach(playerNode)
        audioengine.connect(playerNode, to: audioengine.mainMixerNode, format: format)
        try? audioengine.start()
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        playerNode.play()
        isPlaying = true
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                cantHearIt()
            }
        }
    }
    
    func stopTone() {
        playerNode.stop()
        audioengine.stop()
        isPlaying = false
    }
    
    func startingVolume(for frequency: Double) -> Float {
        switch frequency {
        case 250:
            return 0.00003
        case 500:
            return 0.00002
        default:
            return 0.00001
        }
    }
    
    func heardIt() {
        timer?.invalidate()
        timer = nil
        print("Heard at volume: \(currentVolume) for frequency: \(frequencies[frequencyIndex])")
        stopTone()
        results[frequencies[frequencyIndex]] = currentVolume - startingVolume(for: frequencies[frequencyIndex]) + 0.00001
        if frequencyIndex < frequencies.count - 1 {
            frequencyIndex += 1
            currentVolume = startingVolume(for: frequencies[frequencyIndex])
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.0...5.0)) {
                guard !testComplete else { return }
                playTone(frequency: frequencies[frequencyIndex], volume: currentVolume)
                startTimer()
            }
        } else {
            stopTone()
            timer?.invalidate()
            timer = nil
            if currentEar == "left" {
                rightEarResults = results
                results = [:]
                currentEar = "right"
                frequencyIndex = 0
                currentVolume = startingVolume(for: frequencies[0])
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    playTone(frequency: frequencies[0], volume: currentVolume)
                    startTimer()
                }
            } else {
                saveTestResult()
                testComplete = true
            }
        }
    }
    
    func cantHearIt() {
        stopTone()
        currentVolume = min(currentVolume + 0.00001, 0.1)
        playTone(frequency: frequencies[frequencyIndex], volume: currentVolume)
        startTimer()
        print("didnt hear")
    }
    
    func interpret(_ volume: Float) -> String {
        switch volume {
        case ..<0.00005:
            return "Normal"
        case 0.00005..<0.0001:
            return "Mild loss"
        default:
            return "Significant loss"
        }
    }
    
    // MARK: UI helpers (no change to test logic)
    
    private var overallProgress: Double {
        let earOffset = currentEar == "left" ? 0 : frequencies.count
        return Double(earOffset + frequencyIndex) / Double(frequencies.count * 2)
    }
    
    func color(for volume: Float) -> Color {
        volume < 0.00005 ? .green : volume < 0.0001 ? .orange : .red
    }
    
    // Same code as the original "Begin Test" button.
    func startTest() {
        testStarted = true
        frequencyIndex = 0
        currentVolume = startingVolume(for: frequencies[0])
        playTone(frequency: frequencies[0], volume: currentVolume)
        startTimer()
    }
    
    // Same code as the original "Retake Test" button.
    func resetTest() {
        testStarted = false
        testComplete = false
        frequencyIndex = 0
        currentVolume = startingVolume(for: frequencies[0])
        currentEar = "left"
        results = [:]
        rightEarResults = [:]
        stopTone()
        timer?.invalidate()
        timer = nil
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !testStarted {
                    introView
                } else if testComplete {
                    resultsView
                } else {
                    inProgressView
                }
            }
            .navigationTitle("Hearing Test")
            .navigationBarTitleDisplayMode(testStarted && !testComplete ? .inline : .large)
        }
    }
    
    private var introView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Check how well you hear quiet tones at six pitches in each ear.")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 18) {
                    stepRow(icon: "headphones", title: "Put on headphones", detail: "Find a quiet room first.")
                    stepRow(icon: "speaker.wave.3.fill", title: "Turn volume all the way up", detail: "The tones start very quietly.")
                    stepRow(icon: "hand.tap.fill", title: "Tap when you hear a tone", detail: "Even if it's faint.")
                }
                .card()
                
                Text("This is not a medical hearing test. Results depend on your headphones and device and should not be used for diagnosis. If you're concerned about your hearing, talk to a licensed audiologist or doctor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button(action: startTest) {
                Text("Begin Test")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func stepRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // Deliberately no animation tied to isPlaying: a visual cue would let users see the tone.
    private var inProgressView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(currentEar == "left" ? "Left ear" : "Right ear")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Tone \(frequencyIndex + 1) of \(frequencies.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.top, 24)
            
            ProgressView(value: overallProgress)
                .padding(.horizontal, 48)
            
            Spacer()
            
            Button(action: heardIt) {
                Text("I heard it")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 200)
                    .background(Circle().fill(Color.brand))
                    .background(Circle().fill(Color.brand.opacity(0.12)).padding(-22))
            }
            .buttonStyle(PressableStyle())
            
            Text("Tones may be very quiet. Tap as soon as you hear one.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)
            
            Spacer()
            
            Button("Cancel Test", role: .destructive, action: resetTest)
                .padding(.bottom, 16)
        }
    }
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                earCard(title: "Left ear", data: rightEarResults)
                earCard(title: "Right ear", data: results)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button(action: resetTest) {
                Text("Retake Test")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func earCard(title: String, data: [Double: Float]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            Chart {
                ForEach(frequencies, id: \.self) { freq in
                    if let volume = data[freq] {
                        BarMark(
                            x: .value("Frequency", freq >= 1000 ? "\(Int(freq / 1000))k" : "\(Int(freq))"),
                            y: .value("Volume", Double(volume))
                        )
                        .foregroundStyle(color(for: volume))
                        .cornerRadius(5)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...0.0002)
            .frame(height: 140)
            
            Divider()
            
            ForEach(frequencies, id: \.self) { freq in
                if let volume = data[freq] {
                    HStack {
                        Text("\(Int(freq)) Hz")
                            .monospacedDigit()
                        Spacer()
                        Text(interpret(volume))
                            .fontWeight(.medium)
                            .foregroundStyle(color(for: volume))
                    }
                    .font(.subheadline)
                }
            }
        }
        .card()
    }
}

// MARK: - Data

struct DataView: View {
    
    private let healthStore = HKHealthStore()
    
    @State private var exposureData: [ExposurePoint] = []
    @State private var selectedRange: TimeRange = .week
    @State private var notificationCount = 0
    @State private var isLoading = true
    
    private var averageLevel: Double? {
        let values = exposureData.filter { $0.type == .average }.map(\.decibels)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    
    private var peakLevel: Double? {
        exposureData.filter { $0.type == .max }.map(\.decibels).max()
    }
    
    func predicateForTimeRange() -> NSPredicate? {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedRange {
        case .today:
            let start = calendar.startOfDay(for: now)
            return HKQuery.predicateForSamples(withStart: start, end: now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return HKQuery.predicateForSamples(withStart: start, end: now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return HKQuery.predicateForSamples(withStart: start, end: now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return HKQuery.predicateForSamples(withStart: start, end: now)
        case .all:
            return nil
        }
    }
    
    func requestPermission() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        healthStore.requestAuthorization(toShare: [], read: [exposureType]) { _, _ in
            fetchExposureData()
        }
    }
    
    func fetchExposureData() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: exposureType,
            predicate: predicateForTimeRange(),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            // Empty on error or no data, so loading always finishes.
            let samples = (samples as? [HKQuantitySample]) ?? []
            
            var points: [ExposurePoint] = []
            var warnings = 0
            
            for sample in samples {
                let db = sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
                if db >= 85 {
                    warnings += 1
                }
                points.append(ExposurePoint(date: sample.startDate, decibels: db, type: .average))
            }
            
            DispatchQueue.main.async {
                let cleanedData = aggregatePerInterval(points)
                exposureData = cleanedData
                notificationCount = warnings
                isLoading = false
            }
        }
        
        healthStore.execute(query)
    }
    
    func aggregatePerInterval(_ rawData: [ExposurePoint]) -> [ExposurePoint] {
        var grouped: [Date: [Double]] = [:]
        let calendar = Calendar.current
        
        for point in rawData {
            let key: Date
            switch selectedRange {
            case .today:
                key = calendar.date(
                    bySettingHour: calendar.component(.hour, from: point.date),
                    minute: 0,
                    second: 0,
                    of: point.date
                )!
            case .week, .month:
                key = calendar.startOfDay(for: point.date)
            case .year, .all:
                let components = calendar.dateComponents([.year, .month], from: point.date)
                key = calendar.date(from: components)!
            }
            grouped[key, default: []].append(point.decibels)
        }
        
        var result: [ExposurePoint] = []
        for (date, values) in grouped {
            let avg = values.reduce(0, +) / Double(values.count)
            let max = values.max() ?? avg
            result.append(ExposurePoint(date: date, decibels: avg, type: .average))
            result.append(ExposurePoint(date: date, decibels: max, type: .max))
        }
        
        return result.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Headphone levels")
                            .font(.headline)
                        ZStack {
                            if exposureData.isEmpty && !isLoading {
                                Text("No listening data for this range.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                chart.opacity(isLoading ? 0.3 : 1)
                            }
                            if isLoading {
                                ProgressView("Fetching data...")
                            }
                        }
                        .frame(height: 220)
                    }
                    .card()
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Average",
                                 value: isLoading ? "-" : averageLevel.map { "\(Int($0.rounded()))" } ?? "-",
                                 unit: "dB")
                        StatCard(title: "Peak",
                                 value: isLoading ? "-" : peakLevel.map { "\(Int($0.rounded()))" } ?? "-",
                                 unit: "dB")
                        StatCard(title: "Over 85",
                                 value: isLoading ? "-" : "\(notificationCount)")
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Data")
            .onChange(of: selectedRange) { _ in
                isLoading = true
                fetchExposureData()
            }
            .onAppear {
                requestPermission()
            }
        }
    }
    
    private var chart: some View {
        Chart(exposureData) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("dB", point.decibels)
            )
            .foregroundStyle(by: .value("Type", point.type == .average ? "Average" : "Max"))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            
            RuleMark(y: .value("Limit", 85))
                .foregroundStyle(Color.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYAxisLabel("dB")
        .chartYScale(domain: {
            let values = exposureData.map { $0.decibels } + [85]
            let min = (values.min() ?? 0) - 5
            let max = (values.max() ?? 100) + 5
            return min...max
        }())
        .chartForegroundStyleScale(["Average": Color.brand, "Max": Color.orange])
        .chartLegend(position: .top, alignment: .leading)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
