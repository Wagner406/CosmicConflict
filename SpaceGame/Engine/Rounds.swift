//
//  Rounds.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Konfiguration pro Runde

    /// Intervall & Anzahl der Gegner-Schiffe pro Runde
    func roundConfig(for round: Int) -> (spawnInterval: TimeInterval, totalEnemies: Int) {
        switch round {
        case 1:
            return (5.0, 5)    // alle 5s, 5 Schiffe
        case 2:
            return (4.0, 10)   // alle 4s, 10 Schiffe
        case 3:
            return (3.0, 15)   // alle 3s, 15 Schiffe
        case 4:
            return (2.0, 15)   // alle 2s, 15 Schiffe
        case 5:
            return (1.0, 15)   // jede Sekunde, 15 Schiffe
        default:
            return (1.0, 0)
        }
    }

    // MARK: - Runde starten / fortschalten

    /// Neue Runde vorbereiten (Zähler + HUD)
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

        let config = roundConfig(for: currentRound)

        // Bereits alle Gegner für diese Runde gespawnt?
        if enemiesSpawnedThisRound >= config.totalEnemies {
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

    /// Spawnt ein verfolgendes Gegner-Schiff zufällig am Rand der Map
    func spawnEnemyShipAtEdge() {
        guard let level = levelNode else { return }

        // Wichtig: hier muss deine Fabrik-Funktion für das Gegner-Schiff stehen.
        // Falls du eine andere Funktion verwendest, hier anpassen:
        let enemy = makeChaserShip()

        let minX = level.frame.minX
        let maxX = level.frame.maxX
        let minY = level.frame.minY
        let maxY = level.frame.maxY

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

        let config = roundConfig(for: currentRound)
        if enemiesKilledThisRound >= config.totalEnemies {
            advanceToNextRound()
        }
    }

    func advanceToNextRound() {
        if currentRound < 5 {
            let nextRound = currentRound + 1

            // Banner „Round X!“ für NÄCHSTE Runde
            showRoundAnnouncement(forRound: nextRound)

            // Nach kurzer Pause wirklich starten
            run(.sequence([
                .wait(forDuration: 2.0),
                .run { [weak self] in
                    self?.startRound(nextRound)
                }
            ]))
        } else {
            handleLevelCompleted()
        }
    }

    // MARK: - Banner & Level-Ende

    /// „Round X!“ mittig im Bildschirm anzeigen
    func showRoundAnnouncement(forRound round: Int) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Round \(round)!"
        label.fontSize = 40
        label.fontColor = .white
        label.zPosition = 300
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        cameraNode.addChild(label)

        let fadeIn  = SKAction.fadeIn(withDuration: 0.3)
        let wait    = SKAction.wait(forDuration: 1.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove  = SKAction.removeFromParent()

        label.run(.sequence([fadeIn, wait, fadeOut, remove]))
    }

    func handleLevelCompleted() {
        // Nur einmal ausführen
        if isLevelCompleted { return }
        isLevelCompleted = true

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "LEVEL COMPLETE"
        label.fontSize = 32
        label.fontColor = .yellow
        label.zPosition = 300
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        cameraNode.addChild(label)

        let fadeIn  = SKAction.fadeIn(withDuration: 0.5)
        let wait    = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove  = SKAction.removeFromParent()

        label.run(.sequence([fadeIn, wait, fadeOut, remove]))

        // 5 Sekunden nach Level-Ende zurück ins Menü
        run(.wait(forDuration: 5.0)) { [weak self] in
            self?.onLevelCompleted?()
        }
    }
}
