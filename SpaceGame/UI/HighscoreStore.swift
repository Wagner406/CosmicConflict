import Foundation

enum HighscoreStore {

    // Keys pro Level
    private static func bestTimeKey(levelId: Int) -> String { "bestTime_level_\(levelId)" }
    private static func bestScoreKey(levelId: Int) -> String { "bestScore_level_\(levelId)" }

    static func bestTime(levelId: Int) -> TimeInterval? {
        let v = UserDefaults.standard.double(forKey: bestTimeKey(levelId: levelId))
        return v > 0 ? v : nil
    }

    static func bestScore(levelId: Int) -> Int {
        UserDefaults.standard.integer(forKey: bestScoreKey(levelId: levelId))
    }

    /// Speichert:
    /// - Bestzeit = kleiner ist besser
    /// - Highscore = größer ist besser
    static func submitRun(levelId: Int, elapsedTime: TimeInterval, score: Int) {
        // Bestzeit
        if let best = bestTime(levelId: levelId) {
            if elapsedTime < best {
                UserDefaults.standard.set(elapsedTime, forKey: bestTimeKey(levelId: levelId))
            }
        } else {
            UserDefaults.standard.set(elapsedTime, forKey: bestTimeKey(levelId: levelId))
        }

        // Highscore
        let currentBestScore = bestScore(levelId: levelId)
        if score > currentBestScore {
            UserDefaults.standard.set(score, forKey: bestScoreKey(levelId: levelId))
        }
    }
}
