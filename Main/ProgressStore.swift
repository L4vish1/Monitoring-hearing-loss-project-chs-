//
//  ProgressStore.swift
//  Main
//
//  Created by Leo Lin  on 10/22/26.
//

import Foundation
import Combine

// Saves completed challenges and calculates XP and streaks.
final class ProgressStore: ObservableObject {

    // Stores every challenge the user has completed.
    @Published private(set) var results: [ChallengeResult] = []

    // Use a separate key so we don't overwrite the old app's data.
    private let saveKey = "hearquestChallengeResults"

    // Runs automatically when a ProgressStore is created.
    init() {
        loadResults()
    }

    // MARK: - Saving a Challenge

    // Each correct answer earns 10 XP.
    func completeChallenge(correctAnswers: Int) {

        // Keep the score between 0 and 5.
        let score = min(max(correctAnswers, 0), 5)

        // Calculate XP earned from this challenge.
        let earnedXP = score * 10

        // Create a new result using our ChallengeResult model.
        let newResult = ChallengeResult(
            correctAnswers: score,
            xpEarned: earnedXP
        )

        // Add the result to the user's history.
        results.append(newResult)

        // Save the updated history to the device.
        saveResults()
    }

    // MARK: - Total XP

    // Adds up the XP earned from every completed challenge.
    var totalXP: Int {
        results.reduce(0) { total, result in
            total + result.xpEarned
        }
    }

    // MARK: - Challenges Completed

    // Counts how many challenges the user has finished.
    var challengesCompleted: Int {
        results.count
    }

    // MARK: - Average Accuracy

    // Calculates the user's average score percentage.
    var averageAccuracy: Double {

        // Return 0 if the user hasn't completed anything.
        guard !results.isEmpty else { return 0 }

        // Add up the accuracy of all completed challenges.
        let totalAccuracy = results.reduce(0.0) { total, result in
            total + result.accuracy
        }

        // Divide by the number of completed challenges.
        return totalAccuracy / Double(results.count)
    }

    // MARK: - Daily Streak

    var currentStreak: Int {

        let calendar = Calendar.current

        // Get the unique days when challenges were completed.
        let completedDays = Set(
            results.map { calendar.startOfDay(for: $0.date) }
        )

        // Start checking from today.
        var checkingDay = calendar.startOfDay(for: Date())

        if !completedDays.contains(checkingDay) {
            guard let yesterday = calendar.date(
                byAdding: .day,
                value: -1,
                to: checkingDay
            ) else {
                return 0
            }

            checkingDay = yesterday
        }

        // Count each consecutive completed day.
        var streak = 0

        while completedDays.contains(checkingDay) {
            streak += 1

            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: checkingDay
            ) else {
                break
            }

            checkingDay = previousDay
        }

        return streak
    }

    // MARK: - Save Data

    // Converts our results into data and saves them on the iPhone.
    private func saveResults() {

        guard let encoded = try? JSONEncoder().encode(results) else {
            print("Failed to encode HearQuest results.")
            return
        }

        UserDefaults.standard.set(encoded, forKey: saveKey)
    }

    // MARK: - Load Data

    // Loads the user's previous results when the app opens.
    private func loadResults() {

        // Check whether saved results already exist.
        guard let savedData = UserDefaults.standard.data(
            forKey: saveKey
        ) else {
            return
        }

        guard let decoded = try? JSONDecoder().decode(
            [ChallengeResult].self,
            from: savedData
        ) else {
            print("Failed to decode HearQuest results.")
            return
        }

        results = decoded
    }
}
