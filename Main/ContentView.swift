//
//  ContentView.swift
//  Main
//
//  Created by av3ry on 9/21/25.
//

import SwiftUI
import HealthKit
import Charts
import AVFoundation
import UserNotifications


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

struct ContentView: View {
    var body: some View {
        TabView {
            StreakView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Streak")
                }
            TestView()
                .tabItem {
                    Image(systemName: "headphones")
                    Text("Test")
                }
            DataView()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Data")
                }
        }
    }
}

struct StreakView: View {
    
    
    @State private var streakCount = 0
    @State private var installDate: Date = UserDefaults.standard.object(forKey: "installDate") as? Date ?? Date()
    private let healthStore = HKHealthStore()
    @State private var isLoading = true
    @State private var bestStreak: Int = UserDefaults.standard.integer(forKey: "bestStreak")
    @State private var todayIsSafe = false
    @State private var exposureSamples: [ExposureSample] = []
    private let threshold = 85.0
    
    func requestPermission() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        healthStore.requestAuthorization(toShare: [], read: [exposureType]) { success, error in
            if success {
                fetchStreakData()
            }
        }
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
            guard let samples = samples as? [HKQuantitySample] else { return }
            
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
        for (day,seconds) in dailyLoudSeconds {
            dailySafe[day] = seconds < 1800
            
        }
        todayIsSafe = dailySafe[today] ?? true
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
        
    
    var body: some View {
       
        
        VStack {
            if isLoading {
                ProgressView("Fetching data...")
            } else {
                VStack(spacing : 12) {
                    Text("You are on a \(streakCount) day streak!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Best streak: \(bestStreak) days")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding()
                        .foregroundStyle(.secondary)
                    Text("You have not listened at 85dB or higher for > 30 minutes in \(streakCount) days.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding()
                    Text(todayIsSafe ? "🟢 Limit not reached today" : "🔴 Limit reached today")
                        .font(.headline)
                    
                    
                    
                    
                }
            }
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

struct TestView: View {
    @State private var currentFrequency: Double = 1000.0
    @State private var currentVolume: Float = 0.5
    @State private var isPlaying = false
    @State private var testStarted = false
    @State private var currentEar: String = "left"
    @State private var rightEarResults: [Double: Float] = [:]
    
    let frequencies: [Double] = [250, 500, 1000, 2000, 4000, 8000]
    
    @State private var frequencyIndex: Int = 0
    @State private var audioengine = AVAudioEngine()
    @State private var results: [Double: Float] = [:]
    @State private var playerNode = AVAudioPlayerNode()
    @State private var testComplete = false
    @State private var timer: Timer? = nil
    
    
    
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
        
        // Fill the buffer first
        for frame in 0..<Int(frameCount) {
            let sample = sin(2.0 * Float.pi * Float(frequency) * Float(frame) / Float(sampleRate)) * volume
            leftChannel[frame] = currentEar == "left" ? sample : 0
            rightChannel[frame] = currentEar == "right" ? sample : 0
        }
        
        // Then set up and start the engine once
        audioengine.attach(playerNode)
        audioengine.connect(playerNode, to: audioengine.mainMixerNode, format: format)
        try? audioengine.start()
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        playerNode.play()
        isPlaying = true
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in DispatchQueue.main.async {
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
    var body: some View {
        VStack {
            if !testStarted {
                Text("Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Please put your headphones in and set your volume to maximum before starting.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                Button("Begin Test") {
                    testStarted = true
                    frequencyIndex = 0
                    currentVolume = startingVolume(for: frequencies[0])
                    playTone(frequency: frequencies[0], volume: currentVolume)
                    startTimer()
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
                Text("THIS TEST IS NOT MEDICALLY PROVEN NOR ACCURATE. IT IS A SUBJECTIVE MEASUREMENT AND MAY BE SKEWED BY HEADPHONE OR PHONE BRAND, MODEL, ETC. TALK TO A LICENSED MEDICAL PROFESSIONAL IF YOU ARE CONCERNED ABOUT YOUR HEARING.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 10)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                
            } else if testComplete {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Results")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Left")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Chart {
                            ForEach(frequencies, id: \.self) { freq in
                                if let volume = rightEarResults[freq] {
                                    BarMark(
                                        x: .value("Frequency", "\(Int(freq)) Hz"),
                                        y: .value("Volume", Double(volume))
                                    )
                                    .foregroundStyle(
                                        volume < 0.00005 ? Color.green :
                                        volume < 0.0001 ? Color.yellow :
                                        Color.red
                                    )
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartYScale(domain: 0...0.0002)
                        .frame(height: 200)
                        .padding(.horizontal, 16)
                        
                        ForEach(frequencies, id: \.self) { freq in
                            if let volume = rightEarResults[freq] {
                                HStack {
                                    Text("\(Int(freq)) Hz:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(interpret(volume))
                                        .foregroundStyle(
                                            volume < 0.00005 ? Color.green :
                                            volume < 0.0001 ? Color.yellow :
                                            Color.red
                                        )
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("Right")
                            .font(.title2)
                            .fontWeight(.bold)
        
                        
                        Chart {
                            ForEach(frequencies, id: \.self) { freq in
                                if let volume = results[freq] {
                                    BarMark(
                                        x: .value("Frequency", "\(Int(freq)) Hz"),
                                        y: .value("Volume", Double(volume))
                                    )
                                    .foregroundStyle(
                                        volume < 0.00005 ? Color.green :
                                        volume < 0.0001 ? Color.yellow :
                                        Color.red
                                    )
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartYScale(domain: 0...0.0002)
                        .frame(height: 200)
                        .padding(.horizontal, 16)
                        
                        ForEach(frequencies, id: \.self) { freq in
                            if let volume = results[freq] {
                                HStack {
                                    Text("\(Int(freq)) Hz:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(interpret(volume))
                                        .foregroundStyle(
                                            volume < 0.00005 ? Color.green :
                                            volume < 0.0001 ? Color.yellow :
                                            Color.red
                                        )
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                    }
                }
                Button("Retake Test") {
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
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.bottom, 16)
            } else {
                Button("I heard it") {
                    heardIt()
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}
    
    struct DataView: View {
        
        private let healthStore = HKHealthStore()
        
        @State private var exposureData: [ExposurePoint] = []
        @State private var selectedRange: TimeRange = .week
        @State private var notificationCount = 3
        @State private var isLoading = true
        
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
            
            healthStore.requestAuthorization(toShare: [], read: [exposureType]) { success, error in
                if success {
                    fetchExposureData()
                }
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
                guard let samples = samples as? [HKQuantitySample] else { return }
                
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
            VStack {
                if isLoading {
                    ProgressView("Fetching data...")
                } else {
                    Text("Average & Max dB Over Time")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Chart(exposureData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("dB", point.decibels)
                        )
                        .foregroundStyle(by: .value("Type", point.type == .average ? "Average" : "Max"))
                    }
                    .chartYAxisLabel("dB", position: .leading)
                    .chartXAxisLabel("Date", position: .bottom)
                    .chartYScale(domain: {
                        let values = exposureData.map { $0.decibels }
                        let min = (values.min() ?? 0) - 5
                        let max = (values.max() ?? 100) + 5
                        return min...max
                    }())
                    .chartForegroundStyleScale([
                        "Average": Color.blue,
                        "Max": Color.red
                    ])
                    .chartLegend(position: .top)
                    .frame(height: 250)
                    .padding(.horizontal, 16)
                    
                    Picker("Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: selectedRange) { _ in
                        isLoading = true
                        fetchExposureData()
                    }
                    
                    Text("Times over 85 dB: \(notificationCount)")
                        .padding(.top)
                }
            }
            .onAppear {
                requestPermission()
            }
        }
    }

