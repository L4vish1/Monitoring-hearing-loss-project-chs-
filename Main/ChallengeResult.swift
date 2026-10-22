//
//  ChallengeResult.swift
//  Main
//
//  Created by Leo Lin  on 10/22/26.
// Things we can save to the app everytime soeone finishes a 5 questions challenge each day

import Foundation

struct ChallengeResult: Codable {
    var id: UUID = UUID()
    //shows the date
    var date: Date = Date()
    //shows the # of correct answers and the total questions there are (total Q is useful later on)
    var correctAnswers: Int
    var totalQuestions: Int = 5
    //this is the XP earned by the user by the Question (kidna like the stuff they do In Duolingo)
    var xpEarned: Int
    
    //find the accuracy of the user when answering the question
    var accuracy: Double {
        guard totalQuestions > 0 else {return 0}
        return Double(correctAnswers) / Double(totalQuestions) * 100
    }
    
}
