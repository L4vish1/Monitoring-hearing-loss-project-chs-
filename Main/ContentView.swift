//
//  ContentView.swift
//  Main
//
//  Created by av3ry on 9/21/25.
//

import SwiftUI
import HealthKit
import Charts

struct ExposurePoint: Identifiable {
    let id = UUID()
    let date: Date
    let decibels: Double
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
        TabView{
            StreakView()
                .tabItem{
                    Image(systemName: "chart.bar")
                    Text("Streak")
                }
            
            TestView()
                .tabItem{
                    Image(systemName: "headphones")
                    Text("Test")
                }
            
            DataView()
                .tabItem{
                    Image(systemName: "heart")
                    Text("Data")
                }
        }
    }
}

struct StreakView: View {
    var body: some View {
        Text("Streak")
    }
}

struct TestView: View {
    var body: some View {
        Text("Test")
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
                print("permission correct")
                fetchExposureData()
            } else {
                print("Permission failed")
            }
        }
    }
    
    func fetchExposureData() {
        
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else { return }
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
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
                
                if db >= 90 {
                    warnings += 1
                }
                
                let date = sample.startDate
                points.append(ExposurePoint(date: date, decibels: db))
            }
            
            DispatchQueue.main.async {
                let cleanedData = aggregateAveragePerInterval(points)
                exposureData = cleanedData
                notificationCount = warnings
                isLoading = false
            }
        }
        
        healthStore.execute(query)
    }
    
    func aggregateAveragePerInterval(_ rawData: [ExposurePoint]) -> [ExposurePoint] {
        
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
        
        return grouped.map { date, values in
            let avg = values.reduce(0, +) / Double(values.count)
            return ExposurePoint(date: date, decibels: avg)
        }
        .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        
        VStack {
            
            if isLoading {
                ProgressView("Fetching data...")
            }
            else {
                
                Chart(exposureData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("dB", point.decibels)
                    )
                }
                .frame(height: 250)
                
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
                
                Text("Times over 90 dB: \(notificationCount)")
                    .padding(.top)
            }
        }
        .onAppear {
            requestPermission()
        }
    }
}
