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
    
    func requestPermission() {
        guard let exposureType = HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure) else {return}
        healthStore.requestAuthorization(toShare: [], read: [exposureType]) {success, error in
            if success {
                print("permission correct")
            } else if let error = error {
                print("Permission failed")
            }
            
        }
    }
    var body: some View {
       Text("Data")
            .onAppear {
                requestPermission()
            }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
