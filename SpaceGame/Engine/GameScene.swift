//
//  GameScene.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    enum TankDirection {
        case forward
        case backward
        case rotateLeft
        case rotateRight
    }

    // MARK: - Level / Callback

    /// Welches Level gespielt wird (wird von GameView gesetzt)
    var level: GameLevel!

    /// Callback, um nach Level-Ende zurück ins Menü zu springen
    var onLevelCompleted: (() -> Void)?

    // MARK: - Properties

    var playerShip: SKSpriteNode!
    var levelNode: SKNode!
    
    // Environment (Stars, ToxicGas, Nebula, ShootingStars)
    private let environment = EnvironmentSystem()
    
    let bossCameraZoom: CGFloat = 2.1   // ✅ weiter raus (normal cameraZoom ist 1.5)

    /// Alle Gegner (Asteroiden + verfolgenden Schiffe)
    var enemies: [SKSpriteNode] = []

    /// Nur die verfolgenden Gegner-Schiffe (für AI, Schießen, Runden)
    var enemyShips: [SKSpriteNode] = []

    var currentDirection: TankDirection?
    var lastUpdateTime: TimeInterval = 0

    /// Zeitstempel für Thruster-Partikel, damit wir nicht zu viele spawnen
    var lastThrusterParticleTime: TimeInterval = 0

    /// Zeitstempel für Thruster-Partikel der Gegner-Schiffe
    var lastEnemyThrusterParticleTime: TimeInterval = 0

    /// Zeitstempel für Asteroiden-Staub
    var lastAsteroidParticleTime: TimeInterval = 0

    let moveSpeed: CGFloat = 400      // Spieler-Bewegung
    let rotateSpeed: CGFloat = 4      // Spieler-Rotation

    let enemyMoveSpeed: CGFloat = 90  // Verfolger-Geschwindigkeit

    // Stop-Slide (nur beim Loslassen)
    private var playerSlideVelocity = CGVector(dx: 0, dy: 0)
    private let slideDamping: CGFloat = 0.86   // 0.82 = kürzer, 0.90 = länger

    // Stop-Slide für Gegner-Schiffe (nur wenn sie in einem Frame nicht aktiv bewegt wurden)
    private var enemySlideVelocities: [ObjectIdentifier: CGVector] = [:]
    
    // Boss HUD
    var bossHealthBarBg: SKShapeNode?
    var bossHealthBarFill: SKShapeNode?
    var bossHealthLabel: SKLabelNode?
    var bossPhaseLabel: SKLabelNode?

    // Kamera
    let cameraNode = SKCameraNode()
    let cameraZoom: CGFloat = 1.5

    // Gegner-Feuerrate
    let enemyFireInterval: TimeInterval = 1.5
    var lastEnemyFireTime: TimeInterval = 0

    // Zufällige Asteroiden-Spawns (fliegende Asteroiden)
    var lastAsteroidSpawnTime: TimeInterval = 0
    var nextAsteroidSpawnInterval: TimeInterval = 0
    let maxFlyingAsteroids = 4

    // Hintergrund
    var spaceBackground: SKSpriteNode?
    
    // Spieler-HP / Runden
    var playerMaxHP: Int = 100
    var playerHP: Int = 100

    var roundLabel: SKLabelNode?
    /// Aktuelle Runde (1–5 … oder passend zur Level-Config)
    var currentRound: Int = 1

    // HUD
    let hudNode = SKNode()
    var playerHealthBar: SKSpriteNode?
    var powerUpLabel: SKLabelNode?      // Text oben rechts

    // Hit-Cooldown für den Spieler
    var playerLastHitTime: TimeInterval = 0
    let playerHitCooldown: TimeInterval = 1.0   // Sekunden Unverwundbarkeit
    var isPlayerInvulnerable: Bool = false

    // Zeit aus update(), damit didBegin weiß, welche Zeit gilt
    var currentTimeForCollisions: TimeInterval = 0

    // MARK: - Powerups

    enum PowerUpType: CaseIterable {
        case health
        case tripleShot
        case shield
    }

    var activePowerUpNode: SKSpriteNode?
    var lastPowerUpSpawnTime: TimeInterval = 0
    let powerUpMinInterval: TimeInterval = 15.0

    // Triple-Shot
    var isTripleShotActive: Bool = false
    var tripleShotEndTime: TimeInterval = 0

    // Shield
    var isShieldActive: Bool = false
    var shieldEndTime: TimeInterval = 0
    var shieldNode: SKSpriteNode?

    // MARK: - Runden/Waves

    /// Letzte Zeit, zu der ein Gegner-Schiff gespawnt wurde
    var lastEnemySpawnTime: TimeInterval = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits gespawnt wurden
    var enemiesSpawnedThisRound: Int = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits zerstört wurden
    var enemiesKilledThisRound: Int = 0

    /// Level komplett geschafft?
    var isLevelCompleted: Bool = false

    // MARK: - Boss (Level 2)

    var boss: SKSpriteNode?
    var bossPhase: BossPhase = .phase1

    var bossShieldNode: SKShapeNode?
    var bossIsShieldActive: Bool = false

    var bossNextMoveTime: TimeInterval = 0
    var bossPauseUntil: TimeInterval = 0
    var bossNextShotTime: TimeInterval = 0

    var bossBurstShotsRemaining: Int = 0
    var bossBurstNextShotTime: TimeInterval = 0

    var bossLastPauseTriggerTime: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Falls aus irgendeinem Grund kein Level gesetzt wurde → Fallback
        if level == nil {
            level = GameLevels.level1
        }

        setupLevel()        // nutzt jetzt LevelFactory und GameLevel
        environment.buildForCurrentLevel(in: self)      // Stars, Gas, Nebula, ShootingStars
        setupEnemies()      // Start-Asteroiden, evtl. später Boss-Setup
        setupPlayerShip()
        setupCamera()       // ruft auch setupHUD() auf

        // Slide-Init
        playerSlideVelocity = CGVector(dx: 0, dy: 0)
        enemySlideVelocities.removeAll()

        // fliegende Asteroiden
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // Powerup-Timer initialisieren
        lastPowerUpSpawnTime = 0

        // ✅ FIX: Musik erst starten, nachdem die Kamera existiert (SoundManager hängt Audio an camera wenn vorhanden)
        SoundManager.shared.startMusicIfNeeded(for: level.id, in: self)

        // Nur bei Wave-Levels Runden starten
        if level.type == .normal && (level.config.rounds?.isEmpty == false) {
            startRound(1)
            showRoundAnnouncement(forRound: 1)
        }

        // ✅ Boss-Setup für Level 2
        if level.type == .boss {
            setupBossIfNeeded()
            setupBossHUD()
            updateBossHUD()
            cameraNode.setScale(bossCameraZoom)
        }
    }

    // MARK: - Touch → Spieler schießt

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shoot()
    }

    // MARK: - Kollisionen

    func didBegin(_ contact: SKPhysicsContact) {
        let (first, second): (SKPhysicsBody, SKPhysicsBody)
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            first = contact.bodyA
            second = contact.bodyB
        } else {
            first = contact.bodyB
            second = contact.bodyA
        }

        // Spieler-Bullet trifft Enemy (Asteroid oder Gegner-Schiff / Boss)
        if first.categoryBitMask == PhysicsCategory.bullet &&
           second.categoryBitMask == PhysicsCategory.enemy {

            // Bullet entfernen
            first.node?.removeFromParent()

            guard let enemyNode = second.node as? SKSpriteNode else { return }

            // ✅ Boss special-case (Boss hat eigene HP/Phasen/Shield-Logik in BossFight.swift)
            if let b = boss, enemyNode == b {

                // Impact-Sparks
                spawnHitSparks(at: contact.contactPoint,
                               baseColor: .cyan,
                               count: 14,
                               zPos: b.zPosition + 3)

                // Boss Schaden (respektiert Shield)
                applyDamageToBoss(b, amount: 1)
                return
            }

            // Ist es ein EnemyShip oder ein Asteroid?
            let isShip = enemyShips.contains(enemyNode)

            // 1) Kurz aufblitzen lassen
            flashEnemy(enemyNode, isShip: isShip)

            // 2) Hit-Sparks-Farbe wählen
            let sparkColor: SKColor
            if isShip {
                // Schiffe → bläulich / energiemäßig
                sparkColor = SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1.0)
            } else {
                // Asteroiden → warm, wie Gesteins-/Metal-Splitter
                sparkColor = SKColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1.0)
            }

            // 3) Funken am Kontaktpunkt
            let hitPos = contact.contactPoint
            spawnHitSparks(at: hitPos,
                           baseColor: sparkColor,
                           count: isShip ? 12 : 9,
                           zPos: enemyNode.zPosition + 2)

            // 4) HP-Logik wie bisher
            if enemyNode.userData == nil {
                enemyNode.userData = NSMutableDictionary()
            }
            let currentHP = (enemyNode.userData?["hp"] as? Int) ?? 1
            let newHP     = max(0, currentHP - 1)

            enemyNode.userData?["hp"] = newHP
            updateEnemyHealthBar(for: enemyNode)

            if newHP <= 0 {

                if enemyShips.contains(enemyNode) {

                    // ✅ DAS WAR DER FEHLENDE TEIL
                    registerEnemyShipKilled(enemyNode)

                    SoundManager.shared.playRandomExplosion(in: self)

                    playEnemyShipExplosion(
                        at: enemyNode.position,
                        zPosition: enemyNode.zPosition
                    )

                    enemyNode.removeAllActions()
                    enemyNode.physicsBody = nil
                    enemyNode.removeFromParent()

                } else {
                    // Asteroid (kein Einfluss auf Runden)
                    playAsteroidDestruction(on: enemyNode)
                }

                enemies.removeAll { $0 == enemyNode }
            }
        }

        // Enemy-Bullet trifft Spieler-Schiff
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.enemyBullet {

            second.node?.removeFromParent()
            applyDamageToPlayer(amount: 10)
        }

        // Enemy (Asteroid oder Gegner-Schiff) rammt den Spieler
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.enemy {

            applyDamageToPlayer(amount: 5)
        }

        // Spieler sammelt Powerup ein
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.powerUp {

            if let node = second.node as? SKSpriteNode {
                handlePowerUpPickup(node)
            }
        }
    }

    // MARK: - Steuerung via SwiftUI Buttons

    func startMoving(_ direction: TankDirection) {
        currentDirection = direction
    }

    func stopMoving(_ direction: TankDirection) {
        if currentDirection == direction {
            currentDirection = nil
        }
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard let playerShip = playerShip, !isLevelCompleted else { return }

        currentTimeForCollisions = currentTime

        let deltaTime: CGFloat
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = CGFloat(currentTime - lastUpdateTime)
        }
        lastUpdateTime = currentTime

        // =========================
        // ✅ Spieler: normal bewegen, nur beim Loslassen leicht sliden
        // =========================
        if let direction = currentDirection {
            switch direction {
            case .forward:
                let angle = playerShip.zRotation
                let dx = -sin(angle) * moveSpeed * deltaTime
                let dy =  cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

                let dt = max(deltaTime, 0.001)
                playerSlideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .backward:
                let angle = playerShip.zRotation
                let dx =  sin(angle) * moveSpeed * deltaTime
                let dy = -cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

                let dt = max(deltaTime, 0.001)
                playerSlideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .rotateLeft:
                playerShip.zRotation += rotateSpeed * deltaTime

            case .rotateRight:
                playerShip.zRotation -= rotateSpeed * deltaTime
            }
        } else {
            // Stop-Slide (nur wenn kein Input)
            playerShip.position.x += playerSlideVelocity.dx * deltaTime
            playerShip.position.y += playerSlideVelocity.dy * deltaTime

            let damp = pow(slideDamping, deltaTime * 60)
            playerSlideVelocity.dx *= damp
            playerSlideVelocity.dy *= damp

            if abs(playerSlideVelocity.dx) < 5 { playerSlideVelocity.dx = 0 }
            if abs(playerSlideVelocity.dy) < 5 { playerSlideVelocity.dy = 0 }
        }

        // Spieler innerhalb der Map halten
        if let levelNode = levelNode {
            let marginX = playerShip.size.width / 2
            let marginY = playerShip.size.height / 2

            let minX = levelNode.frame.minX + marginX
            let maxX = levelNode.frame.maxX - marginX
            let minY = levelNode.frame.minY + marginY
            let maxY = levelNode.frame.maxY - marginY

            let clampedX = max(minX, min(maxX, playerShip.position.x))
            let clampedY = max(minY, min(maxY, playerShip.position.y))
            playerShip.position = CGPoint(x: clampedX, y: clampedY)
        }

        // Thruster-Partikel hinter dem Spieler-Schiff
        spawnThrusterParticle(currentTime: currentTime)

        // Thruster-Partikel hinter allen Gegner-Schiffen
        spawnEnemyThrusterParticles(currentTime: currentTime)

        // Particle: Staub / Schweif hinter fliegenden Asteroiden
        spawnAsteroidParticles(currentTime: currentTime)

        // Stars und Nebel
        environment.update(in: self, currentTime: currentTime)

        // =========================
        // ✅ Enemy: Stop-Slide (nur wenn updateChaser sie NICHT bewegt)
        // =========================
        var enemyPrePos: [ObjectIdentifier: CGPoint] = [:]
        for e in enemyShips {
            enemyPrePos[ObjectIdentifier(e)] = e.position
            if enemySlideVelocities[ObjectIdentifier(e)] == nil {
                enemySlideVelocities[ObjectIdentifier(e)] = CGVector(dx: 0, dy: 0)
            }
        }

        // Verfolger-AI für ALLE Gegner-Schiffe
        updateChaser(deltaTime: deltaTime)

        // Nach updateChaser prüfen: bewegt? Wenn nicht → leicht sliden
        let dtE = max(deltaTime, 0.001)
        for e in enemyShips {
            let key = ObjectIdentifier(e)
            let before = enemyPrePos[key] ?? e.position
            let after  = e.position

            let movedDx = after.x - before.x
            let movedDy = after.y - before.y
            let movedDist = hypot(movedDx, movedDy)

            if movedDist > 0.2 {
                // wurde aktiv bewegt → Velocity updaten
                enemySlideVelocities[key] = CGVector(dx: movedDx / dtE, dy: movedDy / dtE)
            } else {
                // wurde nicht bewegt → Stop-Slide anwenden
                var v = enemySlideVelocities[key] ?? CGVector(dx: 0, dy: 0)

                e.position.x += v.dx * deltaTime
                e.position.y += v.dy * deltaTime

                let damp = pow(slideDamping, deltaTime * 60)
                v.dx *= damp
                v.dy *= damp

                if abs(v.dx) < 3 { v.dx = 0 }
                if abs(v.dy) < 3 { v.dy = 0 }

                enemySlideVelocities[key] = v
            }
        }

        // Kamera folgt dem Spieler
        cameraNode.position = playerShip.position

        // Gegner schießen
        handleEnemyShooting(currentTime: currentTime)

        // zufällige fliegende Asteroiden spawnen
        handleFlyingAsteroidSpawning(currentTime: currentTime)

        // Powerup-Spawns steuern
        handlePowerUpSpawning(currentTime: currentTime)

        // Powerup-Dauer (Triple Shot / Shield) überprüfen
        updatePowerUpDurations(currentTime: currentTime)

        // Waves ODER Boss
        if level.type == .normal {
            handleEnemyWaveSpawning(currentTime: currentTime)
        } else if level.type == .boss {
            updateBossFight(currentTime: currentTime)
        }
    }

    // MARK: Partikel

    /// Neuer Thruster: runder Glow-Kern + Funken-Streaks hinter dem Spieler
    func spawnThrusterParticle(currentTime: TimeInterval) {
        guard let ship = playerShip else { return }

        // Max. ~30 Bursts pro Sekunde
        if currentTime - lastThrusterParticleTime < 0.03 {
            return
        }
        lastThrusterParticleTime = currentTime

        let angle = ship.zRotation

        // Deine Vorwärtsrichtung ist ( -sin,  cos ) → entspricht Winkel angle + π/2
        let forwardAngle = angle + .pi / 2
        let backAngle    = forwardAngle + .pi   // genau nach hinten

        // Punkt hinter dem Schiff
        let distanceBehind: CGFloat = ship.size.height * 0.6
        let baseX = ship.position.x + cos(backAngle) * distanceBehind
        let baseY = ship.position.y + sin(backAngle) * distanceBehind
        let basePos = CGPoint(x: baseX, y: baseY)

        // --- 1) Runder, glühender Kern ---
        let coreRadius = ship.size.width * 0.11

        let core = SKShapeNode(circleOfRadius: coreRadius)
        core.position = basePos
        core.zPosition = ship.zPosition - 1
        core.fillColor = .white
        core.strokeColor = .clear
        core.glowWidth = coreRadius * 1.6
        core.lineWidth = 0
        core.alpha = 0.95
        core.blendMode = .add
        addChild(core)

        let coreDuration: TimeInterval = 0.18
        let coreMove = SKAction.moveBy(
            x: cos(backAngle) * ship.size.height * 0.25,
            y: sin(backAngle) * ship.size.height * 0.25,
            duration: coreDuration
        )
        let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
        let coreScale = SKAction.scale(to: 0.25, duration: coreDuration)
        let coreGroup = SKAction.group([coreMove, coreFade, coreScale])
        core.run(.sequence([coreGroup, .removeFromParent()]))

        // --- 2) Funken-Streaks hinter dem Schiff ---
        let sparkCount = 3

        for _ in 0..<sparkCount {
            let length = ship.size.width * CGFloat.random(in: 0.24...0.34)
            let thickness = length * 0.22

            let spark = SKSpriteNode(
                color: .white,
                size: CGSize(width: length, height: thickness)
            )

            spark.position = basePos
            spark.zPosition = ship.zPosition - 1
            spark.alpha = 0.95
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            // leicht jitter um die genaue Gegenrichtung
            let jitter = CGFloat.random(in: -(.pi/10)...(.pi/10))
            let dirAngle = backAngle + jitter
            spark.zRotation = dirAngle

            let distance = ship.size.height * CGFloat.random(in: 0.35...0.7)
            let dx = cos(dirAngle) * distance
            let dy = sin(dirAngle) * distance

            let duration: TimeInterval = 0.2

            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.25, duration: duration)

            let group  = SKAction.group([move, fade, scale])
            spark.run(.sequence([group, .removeFromParent()]))

            addChild(spark)
        }
    }

    /// Neuer Thruster für Gegner: etwas dezenter, aber gleicher Stil
    func spawnEnemyThrusterParticles(currentTime: TimeInterval) {
        // etwas seltener als beim Spieler
        if currentTime - lastEnemyThrusterParticleTime < 0.045 {
            return
        }
        lastEnemyThrusterParticleTime = currentTime

        for enemy in enemyShips {
            let angle = enemy.zRotation

            let forwardAngle = angle + .pi / 2
            let backAngle    = forwardAngle + .pi

            let distanceBehind: CGFloat = enemy.size.height * 0.6
            let baseX = enemy.position.x + cos(backAngle) * distanceBehind
            let baseY = enemy.position.y + sin(backAngle) * distanceBehind
            let basePos = CGPoint(x: baseX, y: baseY)

            // --- 1) kleiner Kern ---
            let coreRadius = enemy.size.width * 0.09

            let core = SKShapeNode(circleOfRadius: coreRadius)
            core.position = basePos
            core.zPosition = enemy.zPosition - 1
            core.fillColor = .white
            core.strokeColor = .clear
            core.glowWidth = coreRadius * 1.4
            core.lineWidth = 0
            core.alpha = 0.85
            core.blendMode = .add
            addChild(core)

            let coreDuration: TimeInterval = 0.16
            let coreMove = SKAction.moveBy(
                x: cos(backAngle) * enemy.size.height * 0.22,
                y: sin(backAngle) * enemy.size.height * 0.22,
                duration: coreDuration
            )
            let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
            let coreScale = SKAction.scale(to: 0.25, duration: coreDuration)
            let coreGroup = SKAction.group([coreMove, coreFade, coreScale])
            core.run(.sequence([coreGroup, .removeFromParent()]))

            // --- 2) Funken-Streaks ---
            let sparkCount = 2

            for _ in 0..<sparkCount {
                let length = enemy.size.width * CGFloat.random(in: 0.20...0.30)
                let thickness = length * 0.22

                let spark = SKSpriteNode(
                    color: .white,
                    size: CGSize(width: length, height: thickness)
                )

                spark.position = basePos
                spark.zPosition = enemy.zPosition - 1
                spark.alpha = 0.9
                spark.blendMode = .add
                spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

                let jitter = CGFloat.random(in: -(.pi/12)...(.pi/12))
                let dirAngle = backAngle + jitter
                spark.zRotation = dirAngle

                let distance = enemy.size.height * CGFloat.random(in: 0.3...0.55)
                let dx = cos(dirAngle) * distance
                let dy = sin(dirAngle) * distance

                let duration: TimeInterval = 0.18

                let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
                let fade  = SKAction.fadeOut(withDuration: duration)
                let scale = SKAction.scaleX(to: 0.25, duration: duration)

                let group = SKAction.group([move, fade, scale])
                spark.run(.sequence([group, .removeFromParent()]))

                addChild(spark)
            }
        }
    }

    /// Staub-Schweif / Brocken-Wolke für Asteroiden (runde Gesteinsstücke)
    func spawnAsteroidParticles(currentTime: TimeInterval) {
        // begrenze Spawn-Rate global für alle Asteroiden
        if currentTime - lastAsteroidParticleTime < 0.08 {
            return
        }
        lastAsteroidParticleTime = currentTime

        // Alle Gegner, die NICHT in enemyShips sind → Asteroiden
        for asteroid in enemies where !enemyShips.contains(asteroid) && asteroid != boss {
            let isBoss = (boss != nil && asteroid == boss)
            let baseX = asteroid.position.x
            let baseY = asteroid.position.y

            // Zufall um den Asteroiden herum
            let jitterX = CGFloat.random(
                in: -asteroid.size.width * 0.4 ... asteroid.size.width * 0.4
            )
            let jitterY = CGFloat.random(
                in: -asteroid.size.height * 0.4 ... asteroid.size.height * 0.4
            )

            // runder Brocken-Radius relativ zur Asteroiden-Größe
            let radius = asteroid.size.width * CGFloat.random(in: 0.03...0.08)

            // leicht variierende Gesteinsfarbe (warm braun/orange)
            let baseR: CGFloat = 0.60
            let baseG: CGFloat = 0.45
            let baseB: CGFloat = 0.25
            let colorJitter: CGFloat = 0.06

            let r = max(0, min(1, baseR + CGFloat.random(in: -colorJitter...colorJitter)))
            let g = max(0, min(1, baseG + CGFloat.random(in: -colorJitter...colorJitter)))
            let b = max(0, min(1, baseB + CGFloat.random(in: -colorJitter...colorJitter)))

            let dustColor = SKColor(red: r, green: g, blue: b, alpha: 1.0)

            // runder Brocken als ShapeNode
            let chunk = SKShapeNode(circleOfRadius: radius)
            chunk.position = CGPoint(x: baseX + jitterX, y: baseY + jitterY)
            chunk.zPosition = asteroid.zPosition - 1
            chunk.fillColor = dustColor
            chunk.strokeColor = .clear
            chunk.glowWidth = 0       // matte Steine, kein Glow
            chunk.alpha = 0.95
            chunk.lineWidth = 0
            chunk.blendMode = .alpha  // Staub, kein Neon-Glow

            addChild(chunk)

            // Staub sinkt leicht nach unten und verschwindet
            let driftY: CGFloat = -asteroid.size.height * 0.3
            let driftX: CGFloat = CGFloat.random(in: -asteroid.size.width * 0.05 ... asteroid.size.width * 0.05)

            let move  = SKAction.moveBy(x: driftX, y: driftY, duration: 0.6)
            let fade  = SKAction.fadeOut(withDuration: 0.6)
            let scale = SKAction.scale(to: 0.3, duration: 0.6)

            let group  = SKAction.group([move, fade, scale])
            let finish = SKAction.removeFromParent()

            chunk.run(.sequence([group, finish]))
        }
    }

    /// Zerbrösel-Animation für einen Asteroiden (3x2 Sprite-Sheet)
    func playAsteroidDestruction(on asteroid: SKSpriteNode) {

        // ✅ FIX: Sound hier abspielen (nicht im didBegin doppelt / falsch)
        SoundManager.shared.playRandomExplosion(in: self)

        let sheet = SKTexture(imageNamed: "AstroidDestroyed")

        // Falls das Sheet fehlt → Fallback: nur ausblenden
        guard sheet.size() != .zero else {
            let fade = SKAction.fadeOut(withDuration: 0.15)
            asteroid.run(.sequence([fade, .removeFromParent()]))
            return
        }

        // ✅ FIX: Velocity sichern, damit der Asteroid beim Zerbröseln nicht "stehen bleibt"
        let savedVelocity = asteroid.physicsBody?.velocity ?? CGVector(dx: 0, dy: 0)

        let rows = 3
        let cols = 2
#if swift(>=5.0)
        var frames: [SKTexture] = []
#else
        var frames = [SKTexture]()
#endif

        // Reihenfolge: von oben links nach unten rechts
        for row in 0..<rows {
            for col in 0..<cols {
                let originX = CGFloat(col) / CGFloat(cols)
                let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)

                let rect = CGRect(
                    x: originX,
                    y: originY,
                    width: 1.0 / CGFloat(cols),
                    height: 1.0 / CGFloat(rows)
                )

                let frame = SKTexture(rect: rect, in: sheet)
                frames.append(frame)
            }
        }

        // Physik ausschalten, damit der kaputte Stein nicht mehr kollidiert
        asteroid.physicsBody = nil
        asteroid.removeAllActions()

        // Animation
        let animate = SKAction.animate(with: frames, timePerFrame: 0.05)

        // Parallel langsam ausblenden
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)

        // ✅ FIX: Drift weiterlaufen lassen (ca. 0.5s)
        let driftDuration: TimeInterval = 0.5
        let drift = SKAction.moveBy(
            x: savedVelocity.dx * driftDuration,
            y: savedVelocity.dy * driftDuration,
            duration: driftDuration
        )

        let group = SKAction.group([animate, fadeOut, drift])
        asteroid.run(.sequence([group, .removeFromParent()]))

        // Funken an der Position des Asteroiden
        spawnExplosionSparks(
            at: asteroid.position,
            baseColor: SKColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0),
            count: 18,
            zPos: asteroid.zPosition + 1
        )
    }

    /// Explosion für Gegner-Schiffe (2x3 Sprite-Sheet, blau)
    func playEnemyShipExplosion(at position: CGPoint, zPosition: CGFloat) {

        let sheet = SKTexture(imageNamed: "ExplosionEnemyShip") // Name im Asset-Katalog
        guard sheet.size() != .zero else { return }

        let rows = 2
        let cols = 3
#if swift(>=5.0)
        var frames: [SKTexture] = []
#else
        var frames = [SKTexture]()
#endif

        // von oben links nach unten rechts
        for row in 0..<rows {
            for col in 0..<cols {
                let originX = CGFloat(col) / CGFloat(cols)
                let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)

                let rect = CGRect(
                    x: originX,
                    y: originY,
                    width: 1.0 / CGFloat(cols),
                    height: 1.0 / CGFloat(rows)
                )

                let frame = SKTexture(rect: rect, in: sheet)
                frames.append(frame)
            }
        }

        // Breite eines Frames im Sheet
        let frameWidth = sheet.size().width / CGFloat(cols)

        // Explosion etwas größer als die Schiffe
        let desiredWidth = size.width * 0.3
        let scale = desiredWidth / frameWidth

        let explosion = SKSpriteNode(texture: frames.first)
        explosion.setScale(scale)
        explosion.position = position
        explosion.zPosition = zPosition + 1
        explosion.alpha = 1.0
        explosion.blendMode = .add

        addChild(explosion)

        // 💥 Shockwave-Effekt um die Explosion herum
        triggerExplosionShockwave(at: position)

        let animate = SKAction.animate(with: frames, timePerFrame: 0.05)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let group   = SKAction.group([animate, fadeOut])

        explosion.run(.sequence([group, .removeFromParent()]))

        // Funken dazu
        spawnExplosionSparks(at: position,
                             baseColor: .cyan,   // passt zum blauen Effekt
                             count: 24,
                             zPos: 60)
    }

    /// Kleiner Shockwave-Effekt rund um eine Explosion:
    /// - Ring, der sich ausdehnt und verblasst
    /// - kurzer Kamera-Punch / Shake
    func triggerExplosionShockwave(at position: CGPoint) {
        // --- 1) Ring-Effekt ---
        let radius: CGFloat = 80

        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = position
        ring.zPosition = 999   // über allem drüber
        ring.strokeColor = SKColor.cyan
        ring.lineWidth = 6
        ring.glowWidth = 10
        ring.fillColor = .clear
        ring.alpha = 0.9

        addChild(ring)

        // Start klein, dann expandieren
        ring.setScale(0.2)

        let scaleUp = SKAction.scale(to: 1.4, duration: 0.18)
        let fadeOut = SKAction.fadeOut(withDuration: 0.18)
        let group   = SKAction.group([scaleUp, fadeOut])

        ring.run(.sequence([group, .removeFromParent()]))

        // --- 2) Kamera-Punch / Minishake ---
        guard let cam = camera else { return }

        let originalScale = cam.xScale
        let punchIn  = SKAction.scale(to: originalScale * 0.92, duration: 0.05)
        let punchOut = SKAction.scale(to: originalScale, duration: 0.12)
        punchIn.timingMode  = .easeOut
        punchOut.timingMode = .easeIn

        let punchSequence = SKAction.sequence([punchIn, punchOut])

        // kleines Wackeln
        let shakeAmount: CGFloat = 8
        let shakeDuration: TimeInterval = 0.16

        let moveLeft  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveRight = SKAction.moveBy(x:  shakeAmount * 2, y: 0, duration: shakeDuration / 4)
        let moveBack  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveUp    = SKAction.moveBy(x: 0, y: shakeAmount, duration: shakeDuration / 4)
        let moveDown  = SKAction.moveBy(x: 0, y: -shakeAmount, duration: shakeDuration / 4)

        let shakeSeq = SKAction.sequence([moveLeft, moveRight, moveBack, moveUp, moveDown])

        cam.run(punchSequence)
        cam.run(shakeSeq)
    }

    /// Funkensplitter bei einer Explosion
    func spawnExplosionSparks(at position: CGPoint,
                              baseColor: SKColor = .yellow,
                              count: Int = 20,
                              zPos: CGFloat = 50) {
        for _ in 0..<count {
            // zufällige Größe
            let length = CGFloat.random(in: 14...26)
            let thickness = CGFloat.random(in: 3...6)

            let spark = SKSpriteNode(
                color: baseColor,
                size: CGSize(width: length, height: thickness)
            )

            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 1.0
            spark.blendMode = .add          // schön leuchtend

            // Anker an einem Ende, damit er „rausfliegt“
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            // Zufällige Richtung
            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            // Zufällige Flugweite
            let distance = CGFloat.random(in: 80...180)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let duration: TimeInterval = 0.35

            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            let group  = SKAction.group([move, fade, scale])
            let finish = SKAction.removeFromParent()

            spark.run(.sequence([group, finish]))
            addChild(spark)
        }
    }

    // MARK: - Treffereffekte (Flash + Hit-Sparks)

    /// Kurzer Farb-Flash auf einem Gegner, wenn er getroffen wird
    func flashEnemy(_ enemy: SKSpriteNode, isShip: Bool) {
        let originalColor = enemy.color
        let originalBlend = enemy.colorBlendFactor

        // Schiffe leicht cyan, Asteroiden neutral weiß
        let flashColor: SKColor = isShip
            ? SKColor(red: 0.6, green: 0.95, blue: 1.0, alpha: 1.0)
            : .white

        let flashIn = SKAction.run {
            enemy.color = flashColor
            enemy.colorBlendFactor = 1.0
        }

        let wait = SKAction.wait(forDuration: 0.06)

        let flashOut = SKAction.run {
            enemy.color = originalColor
            enemy.colorBlendFactor = originalBlend
        }

        let seq = SKAction.sequence([flashIn, wait, flashOut])
        enemy.run(seq, withKey: "hitFlash")
    }

    /// Starke, kurze Treffer-Funken (kleiner als Explosion)
    func spawnHitSparks(at position: CGPoint,
                        baseColor: SKColor,
                        count: Int = 10,
                        zPos: CGFloat = 60) {
        for _ in 0..<count {
            let length = CGFloat.random(in: 18...32)
            let thickness = CGFloat.random(in: 3...5)

            let spark = SKSpriteNode(
                color: baseColor,
                size: CGSize(width: length, height: thickness)
            )

            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            let distance = CGFloat.random(in: 60...120)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let duration: TimeInterval = 0.18

            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            let group  = SKAction.group([move, fade, scale])
            let finish = SKAction.removeFromParent()

            spark.run(.sequence([group, finish]))
            addChild(spark)
        }
    }

    // MARK: - Schaden am Spieler

    func applyDamageToPlayer(amount: Int) {
        // 1) Schild aktiv? → gar kein Schaden
        if isShieldActive {
            return
        }

        // 2) Normaler Hit-Cooldown (kurze Unverwundbarkeit mit Blinken)
        if isPlayerInvulnerable &&
            (currentTimeForCollisions - playerLastHitTime) < playerHitCooldown {
            return
        }

        playerLastHitTime = currentTimeForCollisions
        isPlayerInvulnerable = true

        playerHP = max(0, playerHP - amount)
        updatePlayerHealthBar()

        startPlayerInvulnerabilityBlink()
    }

    func startPlayerInvulnerabilityBlink() {
        guard let ship = playerShip else { return }

        ship.removeAction(forKey: "invulnBlink")

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let blink   = SKAction.sequence([fadeOut, fadeIn])
        let repeatBlink = SKAction.repeat(blink, count: 5)

        let end = SKAction.run { [weak self] in
            self?.isPlayerInvulnerable = false
            self?.playerShip.alpha = 1.0
        }

        let sequence = SKAction.sequence([repeatBlink, end])
        ship.run(sequence, withKey: "invulnBlink")
    }

    // MARK: - Powerup-Verwaltung (Dauer etc.)

    func updatePowerUpDurations(currentTime: TimeInterval) {
        // Triple Shot endet?
        if isTripleShotActive && currentTime >= tripleShotEndTime {
            isTripleShotActive = false
            if !isShieldActive {
                setActivePowerUpLabel(nil)
            } else {
                setActivePowerUpLabel("Shield")
            }
        }

        // Shield endet?
        if isShieldActive && currentTime >= shieldEndTime {
            isShieldActive = false
            if !isPlayerInvulnerable {
                playerShip.alpha = 1.0
            }
            shieldNode?.removeFromParent()
            shieldNode = nil

            if !isTripleShotActive {
                setActivePowerUpLabel(nil)
            } else {
                setActivePowerUpLabel("Triple Shot")
            }
        }
    }
    
    override func didSimulatePhysics() {
        super.didSimulatePhysics()

        // ✅ Boss-Shield folgt Boss
        if level.type == .boss {
            bossFollowShieldIfNeeded()
        }
    }

    // MARK: - Gegner-HP-Konfiguration nach Runde

    func enemyMaxHPForCurrentRound() -> Int {
        // Für Boss-Level könntest du hier später anders skalieren, z.B. über level.config.bossMaxHP
        switch currentRound {
        case 1, 2:
            return 1     // Runde 1–2: 1 Treffer
        case 3, 4:
            return 2     // Runde 3–4: 2 Treffer
        default:
            return 3     // Runde 5+: 3 Treffer
        }
    }
}
