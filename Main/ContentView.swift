//
//  ContentView.swift
//  Main
//
//  Created by av3ry on 9/21/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "house.fill")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Pushtest")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
