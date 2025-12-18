import SwiftUI

struct ContentView: View {

    @State private var showGame = false
    @State private var selectedLevel: GameLevel? = nil

    // damit es nach Rückkehr aus dem Spiel neu lädt
    @State private var refreshToken = UUID()

    var body: some View {
        if showGame, let selectedLevel {
            GameView(showGame: $showGame, level: selectedLevel)
                .onDisappear { refreshToken = UUID() } // reload stats when back
        } else {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 26) {
                    Text("Space Game")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Text("Demo Build")
                        .foregroundColor(.gray)

                    // Level 1 Row
                    LevelRow(
                        title: "Level 1",
                        tint: .white,
                        titleColor: .black,
                        levelId: GameLevels.level1.id,
                        refreshToken: refreshToken
                    ) {
                        selectedLevel = GameLevels.level1
                        showGame = true
                    }

                    // Level 2 Row
                    LevelRow(
                        title: "Level 2 (Boss)",
                        tint: .purple,
                        titleColor: .white,
                        levelId: GameLevels.level2.id,
                        refreshToken: refreshToken
                    ) {
                        selectedLevel = GameLevels.level2
                        showGame = true
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }
}

private struct LevelRow: View {
    let title: String
    let tint: Color
    let titleColor: Color
    let levelId: Int
    let refreshToken: UUID
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Button(action: action) {
                Text("Play \(title)")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .foregroundColor(titleColor)

            // Stats line
            HStack(spacing: 14) {
                Text("Best Time: \(bestTimeText)")
                Text("Highscore: \(bestScoreText)")
            }
            .font(.footnote)
            .foregroundColor(.gray)
            .id(refreshToken) // forces refresh when token changes
        }
    }

    private var bestTimeText: String {
        guard let t = HighscoreStore.bestTime(levelId: levelId) else { return "--:--" }
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var bestScoreText: String {
        let s = HighscoreStore.bestScore(levelId: levelId)
        return s > 0 ? "\(s)" : "-"
    }
}
