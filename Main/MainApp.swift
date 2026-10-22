//
//  MainApp.swift
//  Main
//
//  Created by av3ry on 9/21/25.
//

//OLD VERSION
//import SwiftUI
//
//@main
//struct MainApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

//NEW VERSION


import SwiftUI

@main
struct MainApp: App {

    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {

            ContentView()
                .environmentObject(progress)
        }
    }
}

