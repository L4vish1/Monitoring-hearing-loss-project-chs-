//
//  Sharedui.swift
//  Main
//
//  Created by Qing Yu on 10/24/26.
//
//
//  SharedUI.swift
//  Main
//
//  Shared look used by every tab (ContentView.swift and ProgressViewScreen.swift).
//

import SwiftUI

struct DayStatus: Identifiable {
    let date: Date
    let safe: Bool
    let beforeInstall: Bool
    var id: Date { date }
}

extension Color {
    static let brand = Color(red: 0.16, green: 0.58, blue: 0.56)
}

extension View {
    func card() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var unit: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
