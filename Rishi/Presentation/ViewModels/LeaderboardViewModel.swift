//
//  LeaderboardViewModel.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//

import SwiftUI
import Combine

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var modelStats: [ModelStats] = []
    @Published var battleResults: [BattleResult] = []
    
    private let userDefaults = UserDefaults.standard
    private let battleResultsKey = "BattleResults"
    
    init() {
        loadBattleResults()
        calculateStats()
    }
    
    // MARK: - Public Methods
    
    func loadLeaderboard() {
        loadBattleResults()
        calculateStats()
    }
    
    func addBattleResult(_ result: BattleResult) {
        battleResults.append(result)
        saveBattleResults()
        calculateStats()
    }
    
    func clearAllStats() {
        battleResults.removeAll()
        modelStats.removeAll()
        saveBattleResults()
    }
    
    // MARK: - Private Methods
    
    private func loadBattleResults() {
        if let data = userDefaults.data(forKey: battleResultsKey),
           let results = try? JSONDecoder().decode([BattleResult].self, from: data) {
            battleResults = results
        }
    }
    
    private func saveBattleResults() {
        if let data = try? JSONEncoder().encode(battleResults) {
            userDefaults.set(data, forKey: battleResultsKey)
        }
    }
    
    private func calculateStats() {
        var statsDict: [String: (wins: Int, losses: Int)] = [:]
        
        // Count wins and losses for each model
        for result in battleResults {
            // Winner gets a win
            if statsDict[result.winnerModel] == nil {
                statsDict[result.winnerModel] = (wins: 0, losses: 0)
            }
            statsDict[result.winnerModel]?.wins += 1
            
            // Loser gets a loss
            if statsDict[result.loserModel] == nil {
                statsDict[result.loserModel] = (wins: 0, losses: 0)
            }
            statsDict[result.loserModel]?.losses += 1
        }
        
        // Convert to ModelStats and sort by win rate, then by total battles
        modelStats = statsDict.map { modelName, stats in
            ModelStats(modelName: modelName, wins: stats.wins, losses: stats.losses)
        }.sorted { first, second in
            if first.winRate == second.winRate {
                return first.totalBattles > second.totalBattles
            }
            return first.winRate > second.winRate
        }
    }
}
