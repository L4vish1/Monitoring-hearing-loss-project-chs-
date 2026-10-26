//
//  PitchChallengeView.swift
//  Main
//
//  Created by Leo Lin  on 10/24/26.
//


import SwiftUI
import AVFoundation

// MARK: - Sound Player

final class PitchTonePlayer {

    // The engine creates and plays our audio.
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    // Use ONE format for both the player and the buffer.
    private let sampleRate = 44100.0

    private let audioFormat = AVAudioFormat(
        standardFormatWithSampleRate: 44100,
        channels: 2
    )!

    init() {
        // Attach the player to the engine.
        engine.attach(player)

        // Connect the player using our exact audio format.
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: audioFormat
        )
    }

    // Play a short tone at the requested frequency.
    func play(frequency: Double) {

        // Stop the previous tone before starting another.
        player.stop()

        // Each tone lasts half a second.
        let duration = 0.5
        let frameCount = AVAudioFrameCount(
            sampleRate * duration
        )

        // IMPORTANT: Use the SAME format as the player.
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameCount
        ) else {
            return
        }

        buffer.frameLength = frameCount

        // Access both stereo channels.
        guard let channels = buffer.floatChannelData else {
            return
        }

        let left = channels[0]
        let right = channels[1]

        // Create a sine wave with a short fade
        // to avoid clicking sounds.
        let fadeFrames = Int(sampleRate * 0.02)

        for i in 0..<Int(frameCount) {
            let time = Double(i) / sampleRate

            let fadeIn = min(
                1.0,
                Double(i) / Double(fadeFrames)
            )

            let fadeOut = min(
                1.0,
                Double(Int(frameCount) - i - 1)
                    / Double(fadeFrames)
            )

            let envelope = max(
                0.0,
                min(fadeIn, fadeOut)
            )

            // Keep the generated tone at a low amplitude.
            let sample = Float(
                sin(2.0 * Double.pi * frequency * time)
                * 0.08 * envelope
            )

            // Write the same tone into both channels.
            left[i] = sample
            right[i] = sample
        }

        do {
            // Start the engine only when needed.
            if !engine.isRunning {
                try engine.start()
            }

            // Schedule the generated audio buffer.
            player.scheduleBuffer(buffer)

            // Play the sound.
            player.play()

        } catch {
            print("Audio playback error: \(error)")
        }
    }

    // Stop playback when switching tabs.
    func stop() {
        player.stop()
    }
}


// MARK: - Pitch Challenge
// Uses the shared card(), Color.brand and PressableStyle helpers from SharedUI.swift.

struct PitchChallengeView: View {

    // Access the XP system we already created.
    @EnvironmentObject var progress: ProgressStore

    // Keep one sound player for the entire challenge.
    @State private var tonePlayer = PitchTonePlayer()

    // Track the current question and score.
    @State private var questionNumber = 1
    @State private var score = 0

    // Store the two frequencies.
    @State private var frequencyA = 440.0
    @State private var frequencyB = 660.0

    // Track whether the challenge is finished.
    @State private var challengeFinished = false

    // Prevent multiple answers to the same question.
    @State private var answered = false

    // Show feedback after an answer.
    @State private var feedback = ""

    // Whether the last answer was right (only used for coloring the feedback).
    @State private var lastAnswerCorrect = false

    // Randomizes the very first question once. Without this, question 1
    // was always 440 vs 660, so the answer was always Sound B.
    @State private var firstQuestionReady = false

    private let totalQuestions = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if challengeFinished {
                        resultsCard
                    } else {
                        questionCard
                    }

                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pitch Challenge")
            .onAppear {
                if !firstQuestionReady {
                    generateQuestion()
                    firstQuestionReady = true
                }
            }
            .onDisappear {
                // Stop audio when leaving the screen.
                tonePlayer.stop()
            }
        }
    }

    // MARK: - Question Card

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Progress through the 5 questions.
            HStack {
                Text("Question \(questionNumber) of \(totalQuestions)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                HStack(spacing: 6) {
                    ForEach(1...totalQuestions, id: \.self) { n in
                        Capsule()
                            .fill(n <= questionNumber ? Color.brand : Color(.systemGray5))
                            .frame(width: 18, height: 6)
                    }
                }
            }

            Text("Which sound has a higher pitch?")
                .font(.system(.title3, design: .rounded).weight(.semibold))

            // Listen buttons
            HStack(spacing: 12) {
                listenTile(label: "A", frequency: frequencyA)
                listenTile(label: "B", frequency: frequencyB)
            }

            Divider()

            // Answer buttons
            Text("Your answer")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    checkAnswer(choseA: true)
                } label: {
                    Text("Sound A")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(answered)

                Button {
                    checkAnswer(choseA: false)
                } label: {
                    Text("Sound B")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(answered)
            }

            if answered {
                HStack(spacing: 8) {
                    Image(systemName: lastAnswerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(feedback)
                }
                .font(.headline)
                .foregroundStyle(lastAnswerCorrect ? Color.brand : Color.red)

                Button {
                    nextQuestion()
                } label: {
                    Text(questionNumber == totalQuestions ? "Finish Challenge" : "Next Question")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .card()
    }

    private func listenTile(label: String, frequency: Double) -> some View {
        Button {
            tonePlayer.play(frequency: frequency)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                Text("Sound \(label)")
                    .font(.system(.headline, design: .rounded))
                Text("Tap to play")
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        VStack(spacing: 10) {
            Text("Challenge complete")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(totalQuestions)")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text("+\(score * 10) XP")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.brand)

            Button {
                restartChallenge()
            } label: {
                Text("Play Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - Answer Checking

    private func checkAnswer(choseA: Bool) {
        // Only count one answer per question.
        guard !answered else { return }

        tonePlayer.stop()

        let aIsHigher = frequencyA > frequencyB

        if choseA == aIsHigher {
            score += 1
            feedback = "Correct!"
            lastAnswerCorrect = true
        } else {
            feedback = "Incorrect, try the next one"
            lastAnswerCorrect = false
        }

        answered = true
    }

    // MARK: - Next Question

    private func nextQuestion() {
        guard answered else { return }

        if questionNumber == totalQuestions {
            // Save the result exactly once.
            progress.completeChallenge(
                correctAnswers: score
            )

            challengeFinished = true
        } else {
            questionNumber += 1
            answered = false
            feedback = ""

            generateQuestion()
        }
    }

    // MARK: - Generate Random Sounds

    private func generateQuestion() {
        // Pick two noticeably different pitches.
        let pitches = [
            330.0, 440.0, 550.0,
            660.0, 770.0, 880.0
        ]

        frequencyA = pitches.randomElement() ?? 440.0

        // Make sure the two sounds are different.
        repeat {
            frequencyB = pitches.randomElement() ?? 660.0
        } while frequencyB == frequencyA
    }

    // MARK: - Restart Challenge

    private func restartChallenge() {
        tonePlayer.stop()

        questionNumber = 1
        score = 0
        answered = false
        feedback = ""
        challengeFinished = false

        generateQuestion()
    }
}
