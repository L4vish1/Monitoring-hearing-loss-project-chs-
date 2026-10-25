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

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {

                Text("Pitch Challenge")
                    .font(.title)
                    .bold()

                if challengeFinished {

                    // MARK: - Results Screen

                    Text("Challenge Complete!")
                        .font(.title2)
                        .bold()

                    Text("\(score) / 5 Correct")
                        .font(.largeTitle)

                    Text("+\(score * 10) XP")
                        .foregroundStyle(.blue)
                        .font(.title2)
                        .bold()

                    Button("Play Again!") {
                        restartChallenge()
                    }
                    .buttonStyle(.borderedProminent)

                } else {

                    // MARK: - Question Screen

                    Text("Question \(questionNumber) of 5")
                        .font(.headline)

                    Text("Which sound has a higher pitch?")
                        .font(.title3)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {

                        Button {
                            tonePlayer.play(
                                frequency: frequencyA
                            )
                        } label: {
                            Label(
                                "Sound A",
                                systemImage: "speaker.wave.2"
                            )
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            tonePlayer.play(
                                frequency: frequencyB
                            )
                        } label: {
                            Label(
                                "Sound B",
                                systemImage: "speaker.wave.2"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("Listen to both sounds, then choose the correct answer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // MARK: - Answer Buttons

                    HStack(spacing: 20) {

                        Button("Sound A") {
                            checkAnswer(choseA: true)
                        }
                        .buttonStyle(.bordered)
                        .disabled(answered)

                        Button("Sound B") {
                            checkAnswer(choseA: false)
                        }
                        .buttonStyle(.bordered)
                        .disabled(answered)
                    }

                    if answered {
                        Text(feedback)
                            .font(.headline)

                        Button(
                            questionNumber == 5
                                ? "Finish Challenge"
                                : "Next Question"
                        ) {
                            nextQuestion()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()

                Text(
                    "Use a comfortable listening volume. "
                    + "This is a listening game, not a medical hearing test."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("HearQuest")
            .onDisappear {
                // Stop audio when leaving the screen.
                tonePlayer.stop()
            }
        }
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
        } else {
            feedback = "Incorrect, try the next one"
        }

        answered = true
    }

    // MARK: - Next Question

    private func nextQuestion() {
        guard answered else { return }

        if questionNumber == 5 {
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
