//
//  ProgressViewScreen.swift
//  Main
//
//  Created by Leo Lin  on 10/22/26.
//

import Foundation
import SwiftUI
import Charts

// This screen displays the user's HearQuest progress + reads saved scores, XP, and streaks from ProgressStore.
struct ProgressViewScreen: View {

    // Gives this screen access to the shared progress data.
    @EnvironmentObject var progress: ProgressStore

    var body: some View {

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Screen Title

                    Text("Your Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // MARK: - XP and Streak

                    HStack(spacing: 12) {

                        // Shows the total XP earned.
                        statCard(
                            title: "Total XP",
                            value: "\(progress.totalXP)",
                            symbol: "star.fill"
                        )

                        // Shows consecutive challenge days.
                        statCard(
                            title: "Day Streak",
                            value: "\(progress.currentStreak)",
                            symbol: "flame.fill"
                        )
                    }

                    // MARK: - Additional Statistics

                    HStack(spacing: 12) {

                        // Number of completed challenges.
                        statCard(
                            title: "Challenges",
                            value: "\(progress.challengesCompleted)",
                            symbol: "checkmark.circle.fill"
                        )

                        // Average percentage of correct answers.
                        statCard(
                            title: "Accuracy",
                            value: String(
                                format: "%.0f%%",
                                progress.averageAccuracy
                            ),
                            symbol: "target"
                        )
                    }

                    // MARK: - Score History Chart

                    VStack(alignment: .leading, spacing: 12) {

                        Text("Challenge History")
                            .font(.headline)

                        if progress.results.isEmpty {

                            // MARK: - Empty Challenge History

                            // Display this message when the user hasn't
                            // completed any HearQuest challenges yet.
                            // This works with older versions of iOS.
                            VStack(spacing: 12) {

                                // Show a chart icon.
                                Image(systemName: "chart.bar")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)

                                // Tell the user there are no saved scores yet.
                                Text("No Challenges Yet")
                                    .font(.headline)

                                // Explain how to get results to appear here.
                                Text("Complete a challenge to see your scores.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)


                        } else {

                            // Draw one bar for each completed challenge.
                            Chart {
                                ForEach(
                                    Array(progress.results.enumerated()),
                                    id: \.element.id
                                ) { index, result in

                                    BarMark(
                                        x: .value(
                                            "Challenge",
                                            index + 1
                                        ),
                                        y: .value(
                                            "Score",
                                            result.correctAnswers
                                        )
                                    )
                                    .foregroundStyle(.blue)
                                }
                            }
                            .chartYScale(domain: 0...5)
                            .frame(height: 220)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // MARK: - Recent Challenges

                    VStack(alignment: .leading, spacing: 12) {

                        Text("Recent Challenges")
                            .font(.headline)

                        // Show the newest challenges first.
                        ForEach(Array(progress.results.reversed()), id: \.id) { result in


                            HStack {

                                Text(
                                    result.date,
                                    style: .date
                                )

                                Spacer()

                                Text(
                                    "\(result.correctAnswers)/\(result.totalQuestions)"
                                )
                                .fontWeight(.semibold)

                                Text("+\(result.xpEarned) XP")
                                    .foregroundStyle(.blue)
                            }

                            Divider()
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                }
                .padding()
            }
            .navigationTitle("HearQuest")
        }
    }

    // MARK: - Reusable Statistic Card

    // Creates a matching card for XP, streaks,
    // challenges completed, and accuracy.
    func statCard(
        title: String,
        value: String,
        symbol: String
    ) -> some View {

        VStack(spacing: 10) {

            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
