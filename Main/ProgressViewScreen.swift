//
//  ProgressViewScreen.swift
//  Main
//
//  Created by Leo Lin  on 10/22/26.
// simplifed 10/23/26

import SwiftUI

struct ProgressViewScreen: View {

    // Gets the user's saved progress.
    @EnvironmentObject var progress: ProgressStore
    @State private var showTrophies = false

    // The six ranks
    private let ranks = [
        "Iron", "Bronze", "Silver",
        "Gold", "Platinum", "Champion"
    ]

    private let xpNeeded = [0, 100, 250, 450, 700, 1000]

    // Finds the user's current rank.
    private var rankIndex: Int {
        var current = 0

        for i in 0..<xpNeeded.count {
            if progress.totalXP >= xpNeeded[i] {
                current = i
            }
        }

        return current
    }

    private var xpProgress: Double {
        if rankIndex == 5 {
            return 1.0
        }

        let start = xpNeeded[rankIndex]
        let end = xpNeeded[rankIndex + 1]

        return Double(progress.totalXP - start) /
               Double(end - start)
    }

    // MARK: - Trophy Colors

    // Each rank has its own simple color.
    // Locked trophies will stay gray.
    private func trophyColor(for rank: Int) -> Color {
        switch rank {
        case 0:
            return Color(red: 0.45, green: 0.43, blue: 0.40) // Iron
        case 1:
            return Color.brown // Bronze
        case 2:
            return Color.gray // Silver
        case 3:
            return Color.yellow // Gold
        case 4:
            return Color(red: 0.45, green: 0.55, blue: 0.60) // Platinum
        case 5:
            return Color.purple // Champion
        default:
            return Color.gray
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("My Progress")
                        .font(.title2)
                        .bold()

                    // MARK: - XP Progress

                    Button {
                        // Open or close the trophy collection.
                        showTrophies.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {

                            HStack {
                                Text("Level \(rankIndex + 1): \(ranks[rankIndex])")
                                    .bold()

                                Spacer()

                                Text("\(progress.totalXP) XP")
                            }

                            // Simple blue XP progress bar.
                            ProgressView(value: xpProgress)
                                .tint(.blue)

                            if rankIndex < 5 {
                                Text(
                                    "\(xpNeeded[rankIndex + 1] - progress.totalXP) XP until \(ranks[rankIndex + 1])"
                                )
                                .font(.caption)
                                .foregroundStyle(.gray)
                            } else {
                                Text("Maximum level reached!")
                                    .font(.caption)
                            }

                            Text("Tap to view trophies")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    // MARK: - Trophy Collection

                    if showTrophies {
                        VStack(alignment: .leading, spacing: 12) {

                            Text("Your Trophies (\(rankIndex + 1)/6)")
                                .font(.headline)

                            // Three trophies per row.
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 10
                            ) {
                                ForEach(0..<6, id: \.self) { i in

                                    // A trophy is unlocked when
                                    // the user's XP reaches its requirement.
                                    let unlocked = progress.totalXP >= xpNeeded[i]

                                    VStack(spacing: 6) {

                                        Image(
                                            systemName: i == 5 ? "crown.fill" :
                                                i == 0 ? "shield.fill" : "trophy.fill"
                                        )
                                        .font(.title)
                                        .foregroundStyle(
                                            unlocked ? trophyColor (for: i) : Color.gray
                                        )

                                        Text(ranks[i])
                                            .font(.caption)
                                            .bold()

                                        Text(
                                            unlocked ? "Earned" : "\(xpNeeded[i]) XP"
                                        )
                                        .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        unlocked ?
                                        Color.gray.opacity(0.15) :
                                        Color.gray.opacity(0.07)
                                    )
                                    .cornerRadius(5)
                                }
                            }
                        }
                    }
//

                    // MARK: - Temporary XP Testing Button
                    // This button simulates completing a challenge.
                    // We will remove it before submitting HearQuest.
//                    Button {
//                        // Give the user a perfect score of 5/5.
//                        // Each correct answer earns 10 XP,
//                        // so one perfect challenge gives 50 XP.
//                        progress.completeChallenge(correctAnswers: 5)
//                    } label: {
//                        Text("Test: Complete Challenge (+50 XP)")
//                            .font(.subheadline)
//                            .frame(maxWidth: .infinity)
//                            .padding(10)
//                            .background(Color.blue.opacity(0.15))
//                            .cornerRadius(5)
//                    }
//
                    Divider()

                    // MARK: - Basic Statistics

                    HStack {
                        Text("Challenges Completed")
                        Spacer()
                        Text("\(progress.challengesCompleted)")
                    }

                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(progress.currentStreak) days")
                    }

                    HStack {
                        Text("Average Accuracy")
                        Spacer()
                        Text(
                            String(
                                format: "%.0f%%",
                                progress.averageAccuracy
                            )
                        )
                    }

                    Divider()

                    // MARK: - Recent Scores

                    Text("Recent Scores")
                        .font(.headline)

                    if progress.results.isEmpty {

                        Text("No challenges completed yet.")
                            .foregroundStyle(.gray)

                    } else {

                        // Show the most recent challenges first.
                        ForEach(
                            Array(progress.results.reversed()),
                            id: \.id
                        ) { result in

                            HStack {
                                Text(result.date, style: .date)

                                Spacer()

                                Text(
                                    "\(result.correctAnswers)/\(result.totalQuestions)"
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("HearQuest")
        }
    }
}
