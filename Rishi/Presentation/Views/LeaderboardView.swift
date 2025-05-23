//
//  LeaderboardView.swift
//  Rishi
//
//  Created by Rohit Saini on 23/05/25.
//

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: LeaderboardViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.bottom, 1)
            
            Divider()
            
            leaderboardContent
                .layoutPriority(1)
        }
        .background(Material.regular)
        .frame(minWidth: 800, minHeight: 600)
        .task {
            viewModel.loadLeaderboard()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Model Leaderboard")
                    .font(.title2.weight(.semibold))
                Text("Rankings based on battle performance and win rates.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button {
                viewModel.clearAllStats()
            } label: {
                Label("Reset Stats", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.modelStats.isEmpty)
        }
        .padding()
        .background(Material.regular)
    }
    
    // MARK: - Leaderboard Content
    private var leaderboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.modelStats.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(viewModel.modelStats.enumerated()), id: \.element.id) { index, stats in
                        ModelRankCard(stats: stats, rank: index + 1)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Battle Results Yet")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Start some AI battles to see model rankings appear here.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Head over to the AI Battle section to pit models against each other!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Model Rank Card
struct ModelRankCard: View {
    let stats: ModelStats
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "number.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            VStack {
                Image(systemName: rankIcon)
                    .font(.title2)
                    .foregroundColor(rankColor)
                
                Text("#\(rank)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(rankColor)
            }
            .frame(width: 50)
            
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.modelName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("\(stats.totalBattles) battles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 20) {
                StatItem(title: "Win Rate", value: "\(Int(stats.winRate * 100))%", color: .green)
                StatItem(title: "Wins", value: "\(stats.wins)", color: .blue)
                StatItem(title: "Losses", value: "\(stats.losses)", color: .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThin)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rankColor.opacity(0.3), lineWidth: rank <= 3 ? 2 : 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}
