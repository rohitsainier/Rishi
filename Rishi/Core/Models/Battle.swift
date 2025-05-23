//
//  ScreenType.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//

import Foundation

enum ScreenType {
    case chat
    case battle
    case leaderboard
}

struct BattleResult: Identifiable, Codable {
    var id = UUID()
    let winnerModel: String
    let loserModel: String
    let prompt: String
    let timestamp: Date
    
    init(winnerModel: String, loserModel: String, prompt: String) {
        self.winnerModel = winnerModel
        self.loserModel = loserModel
        self.prompt = prompt
        self.timestamp = Date()
    }
}

struct ModelStats: Identifiable {
    let id = UUID()
    let modelName: String
    let wins: Int
    let losses: Int
    let totalBattles: Int
    let winRate: Double
    
    var rank: Int = 0
    
    init(modelName: String, wins: Int, losses: Int) {
        self.modelName = modelName
        self.wins = wins
        self.losses = losses
        self.totalBattles = wins + losses
        self.winRate = totalBattles > 0 ? Double(wins) / Double(totalBattles) : 0.0
    }
}
