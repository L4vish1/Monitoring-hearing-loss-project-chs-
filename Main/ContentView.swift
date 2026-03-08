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
    let date : Date
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
        let calendar = Calendar.current  // fixed typo: calender → calendar
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
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else {return}
        healthStore.requestAuthorization(toShare: [], read: [exposureType]) {success, error in
            if success {
                print("permission correct")
                fetchExposureData()
            } else if let error = error {
                print("Permission failed")
            }
            
        }
    }
    func fetchExposureData() {
        guard let exposureType = HKObjectType.quantityType(
            forIdentifier: .headphoneAudioExposure
        ) else { return }
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        let query = HKSampleQuery(
            sampleType: exposureType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }
            var points: [ExposurePoint] = []
            for sample in samples {
                let db = sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel())
                let date = sample.startDate
                points.append(ExposurePoint(date: date, decibels: db))
                DispatchQueue.main.async {
                    exposureData = points
                    isLoading = false
                }
                
            }
        }
        healthStore.execute(query)
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Fetching data...")
            } else {
                Chart(exposureData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("dB", point.decibels)
                    )
                }
                .frame(height: 250)
                .padding()
            }
        }
        .onAppear {
            requestPermission()
        }
    }
}
