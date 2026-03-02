//
//  ContentView.swift
//  Main
//
//  Created by av3ry on 9/21/25.
//

import SwiftUI

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
    var body: some View {
        Text("Data")
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
