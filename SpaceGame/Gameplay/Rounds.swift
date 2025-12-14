//
//  Rounds.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Round Config über GameLevel

    /// Holt die Konfiguration für eine bestimmte Runde aus der Level-Config
    func roundConfig(for round: Int) -> RoundConfig? {
        // Falls das Level Runden definiert hat → aus Config lesen
        if let rounds = level.config.rounds, !rounds.isEmpty {
            guard round >= 1 && round <= rounds.count else { return nil }
            return rounds[round - 1]
        } else {
            // Fallback: dein alter Hardcoded-Plan
            switch round {
            case 1:
                return RoundConfig(spawnInterval: 5.0, enemyCount: 5)
            case 2:
                return RoundConfig(spawnInterval: 4.0, enemyCount: 10)
            case 3:
                return RoundConfig(spawnInterval: 3.0, enemyCount: 15)
            case 4:
                return RoundConfig(spawnInterval: 2.0, enemyCount: 15)
            case 5:
                return RoundConfig(spawnInterval: 1.0, enemyCount: 15)
            default:
                return nil
            }
        }
    }

    /// Neue Runde vorbereiten
    func startRound(_ round: Int) {
        currentRound = round
        enemiesSpawnedThisRound = 0
        enemiesKilledThisRound = 0
        lastEnemySpawnTime = 0

        updateRoundLabel()
        print("Starte Runde \(round)")
    }

    /// Wird in update(currentTime:) aufgerufen
    func handleEnemyWaveSpawning(currentTime: TimeInterval) {
        if isLevelCompleted { return }
        guard levelNode != nil else { return }
        guard level.type == .normal else { return }

        guard let config = roundConfig(for: currentRound) else { return }

        // Bereits alle Gegner für diese Runde gespawnt?
        if enemiesSpawnedThisRound >= config.enemyCount {
            return
        }

        // Erstes Mal: sofort spawnen
        if lastEnemySpawnTime == 0 ||
            currentTime - lastEnemySpawnTime >= config.spawnInterval {

            lastEnemySpawnTime = currentTime
            spawnEnemyShipAtEdge()
            enemiesSpawnedThisRound += 1
        }
    }

    /// Spawnt ein verfolgenden Gegner-Schiff zufällig am Rand der Map
    func spawnEnemyShipAtEdge() {
        guard let levelNode = levelNode else { return }

        let enemy = makeChaserShip()   // kommt aus deiner Setup-Extension

        let minX = levelNode.frame.minX
        let maxX = levelNode.frame.maxX
        let minY = levelNode.frame.minY
        let maxY = levelNode.frame.maxY

        let side = Int.random(in: 0..<4)
        var pos = CGPoint.zero

        switch side {
        case 0: // links
            pos = CGPoint(x: minX, y: CGFloat.random(in: minY...maxY))
        case 1: // rechts
            pos = CGPoint(x: maxX, y: CGFloat.random(in: minY...maxY))
        case 2: // unten
            pos = CGPoint(x: CGFloat.random(in: minX...maxX), y: minY)
        default: // oben
            pos = CGPoint(x: CGFloat.random(in: minX...maxX), y: maxY)
        }

        enemy.position = pos
        addChild(enemy)

        enemies.append(enemy)
        enemyShips.append(enemy)
    }

    /// Wird aufgerufen, wenn ein Gegner-Schiff endgültig zerstört wurde
    func registerEnemyShipKilled(_ enemy: SKSpriteNode) {
        if let index = enemyShips.firstIndex(of: enemy) {
            enemyShips.remove(at: index)
        }

        enemiesKilledThisRound += 1

        guard let config = roundConfig(for: currentRound) else { return }

        if enemiesKilledThisRound >= config.enemyCount {
            advanceToNextRound()
        }
    }

    func advanceToNextRound() {
        // Wie viele Runden hat das Level?
        let totalRounds: Int
        if let rounds = level.config.rounds, !rounds.isEmpty {
            totalRounds = rounds.count
        } else {
            totalRounds = 5   // Fallback
        }

        if currentRound < totalRounds {
            let next = currentRound + 1
            startRound(next)
            showRoundAnnouncement(forRound: next)
        } else {
            handleLevelCompleted()
        }
    }

    // MARK: - Visual: "Round X!" Banner

    func showRoundAnnouncement(forRound round: Int) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Round \(round)!"
        label.fontSize = 40
        label.fontColor = .yellow
        label.zPosition = 300
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        hudNode.addChild(label)

        let fadeIn  = SKAction.fadeIn(withDuration: 0.3)
        let wait    = SKAction.wait(forDuration: 1.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove  = SKAction.removeFromParent()

        label.run(.sequence([fadeIn, wait, fadeOut, remove]))
    }

    // MARK: - Level komplett geschafft

    func handleLevelCompleted() {
        guard !isLevelCompleted else { return }
        isLevelCompleted = true

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "LEVEL COMPLETE"
        label.fontSize = 32
        label.fontColor = .yellow
        label.zPosition = 300
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        hudNode.addChild(label)
        label.run(SKAction.fadeIn(withDuration: 0.5))

        // Nach 5 Sekunden zurück ins Menü
        let wait = SKAction.wait(forDuration: 5.0)
        let callback = SKAction.run { [weak self] in
            self?.onLevelCompleted?()
        }
        hudNode.run(SKAction.sequence([wait, callback]))
    }
}
