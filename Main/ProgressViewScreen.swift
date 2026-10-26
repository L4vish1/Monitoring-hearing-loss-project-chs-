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
// Uses the shared card(), StatCard and Color.brand helpers defined in SharedUI.swift.
struct ProgressViewScreen: View {

    // Gives this screen access to the shared progress data.
    @EnvironmentObject var progress: ProgressStore

    // True once the user has finished at least one challenge.
    private var hasResults: Bool { !progress.results.isEmpty }

    var body: some View {

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - Total XP

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total XP")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(progress.totalXP)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.brand)
                    }
                    .card()

                    // MARK: - Streak, Challenges, Accuracy

                    HStack(spacing: 12) {

                        // Consecutive days with a completed challenge.
                        StatCard(
                            title: "Streak",
                            value: "\(progress.currentStreak)",
                            unit: progress.currentStreak == 1 ? "day" : "days"
                        )

                        // Number of completed challenges.
                        StatCard(
                            title: "Done",
                            value: "\(progress.challengesCompleted)"
                        )

                        // Average percentage of correct answers.
                        // Shows "-" until there is a real score to average.
                        StatCard(
                            title: "Accuracy",
                            value: hasResults ? String(format: "%.0f", progress.averageAccuracy) : "-",
                            unit: hasResults ? "%" : ""
                        )
                    }

                    // MARK: - Score History Chart

                    VStack(alignment: .leading, spacing: 12) {

                        Text("Challenge history")
                            .font(.headline)

                        if !hasResults {

                            // Shown until the user completes a challenge.
                            VStack(spacing: 6) {
                                Text("No challenges yet")
                                    .font(.subheadline.weight(.semibold))
                                Text("Complete a challenge to see your scores here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)

                        } else {

                            // One bar for each completed challenge.
                            Chart {
                                ForEach(
                                    Array(progress.results.enumerated()),
                                    id: \.element.id
                                ) { index, result in
                                    BarMark(
                                        x: .value("Challenge", index + 1),
                                        y: .value("Score", result.correctAnswers)
                                    )
                                    .foregroundStyle(Color.brand)
                                    .cornerRadius(4)
                                }
                            }
                            .chartYScale(domain: 0...5)
                            .chartYAxis {
                                AxisMarks(values: [0, 1, 2, 3, 4, 5])
                            }
                            .frame(height: 200)
                        }
                    }
                    .card()

                    // MARK: - Recent Challenges

                    if hasResults {
                        VStack(alignment: .leading, spacing: 0) {

                            Text("Recent challenges")
                                .font(.headline)
                                .padding(.bottom, 6)

                            // Newest challenges first.
                            let recent = Array(progress.results.reversed())

                            ForEach(Array(recent.enumerated()), id: \.element.id) { index, result in
                                HStack {
                                    Text(result.date, style: .date)
                                    Spacer()
                                    Text("\(result.correctAnswers)/\(result.totalQuestions)")
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                    Text("+\(result.xpEarned) XP")
                                        .foregroundStyle(Color.brand)
                                        .monospacedDigit()
                                        .frame(minWidth: 64, alignment: .trailing)
                                }
                                .font(.subheadline)
                                .padding(.vertical, 10)

                                if index < recent.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .card()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }
}
