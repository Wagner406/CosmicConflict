import SpriteKit

extension GameScene {

    // MARK: - Touch Input (Joystick + Shoot)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }

        let pScene = t.location(in: self)

        // HUD first (Pause etc.)
        if hudHandleTap(at: pScene) { return }
        if isGamePaused || isPlayerDead { return }

        // WICHTIG:
        // Wenn Joystick bereits aktiv ist → JEDER weitere Touch schießt
        if steeringTouch != nil {
            shoot()
            return
        }

        // Erster Finger: pending (Tap ODER Joystick)
        pendingJoystickTouch = t
        pendingJoystickStartHud = convert(pScene, to: hudNode)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        // Wenn wir noch im "pending" Zustand sind: prüfen ob Drag
        if let pending = pendingJoystickTouch, touches.contains(pending) {

            let pScene = pending.location(in: self)
            let pHud = convert(pScene, to: hudNode)

            let dx = pHud.x - pendingJoystickStartHud.x
            let dy = pHud.y - pendingJoystickStartHud.y
            let dist = hypot(dx, dy)

            // Noch nicht weit genug gezogen -> weiterhin pending (kein Joystick)
            if dist < joystickDeadZone {
                return
            }

            // Jetzt wird es ein echter Joystick-Finger
            steeringTouch = pending
            pendingJoystickTouch = nil

            showJoystick(at: pendingJoystickStartHud)
            updateJoystick(to: pHud)
            return
        }

        // Normaler Joystick-Update (wenn aktiv)
        guard let steeringTouch, touches.contains(steeringTouch) else { return }

        let pScene = steeringTouch.location(in: self)
        let pHud = convert(pScene, to: hudNode)
        updateJoystick(to: pHud)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        // Pending-Tap endet ohne Drag -> SHOOT
        if let pending = pendingJoystickTouch, touches.contains(pending) {
            pendingJoystickTouch = nil
            shoot()
            return
        }

        // Joystick-Finger endet -> Joystick weg
        if let steeringTouch, touches.contains(steeringTouch) {
            self.steeringTouch = nil
            hideJoystick()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Joystick Visuals (HUD)

    private func showJoystick(at pos: CGPoint) {
        hideJoystick()

        joystickBasePos = pos

        let base = SKShapeNode(circleOfRadius: joystickRadius)
        base.strokeColor = .white.withAlphaComponent(0.35)
        base.lineWidth = 2
        base.fillColor = .clear
        base.position = pos
        base.zPosition = 900

        let knob = SKShapeNode(circleOfRadius: joystickRadius * 0.35)
        knob.fillColor = .white.withAlphaComponent(0.75)
        knob.strokeColor = .clear
        knob.position = pos
        knob.zPosition = 901

        hudNode.addChild(base)
        hudNode.addChild(knob)

        joystickBaseNode = base
        joystickKnobNode = knob
    }

    private func updateJoystick(to pos: CGPoint) {
        let dx = pos.x - joystickBasePos.x
        let dy = pos.y - joystickBasePos.y
        let dist = hypot(dx, dy)

        // deadzone
        if dist < joystickDeadZone {
            joystickVector = .zero
            joystickStrength = 0
            joystickKnobNode?.position = joystickBasePos
            return
        }

        // clamp dist to radius (Limiter!)
        let clampedDist = min(dist, joystickRadius)

        // direction normalized
        let nx = dx / max(0.0001, dist)
        let ny = dy / max(0.0001, dist)

        joystickVector = CGVector(dx: nx, dy: ny)

        // strength 0...1 (capped)
        joystickStrength = clampedDist / joystickRadius

        // knob stays inside radius
        joystickKnobNode?.position = CGPoint(
            x: joystickBasePos.x + nx * clampedDist,
            y: joystickBasePos.y + ny * clampedDist
        )
    }

    private func hideJoystick() {
        joystickBaseNode?.removeFromParent()
        joystickKnobNode?.removeFromParent()
        joystickBaseNode = nil
        joystickKnobNode = nil
        joystickVector = .zero
        joystickStrength = 0
    }

    // MARK: - Laptop / Buttons (bleibt!)

    func startMoving(_ direction: ShipDirection) {
        currentDirection = direction
    }

    func stopMoving(_ direction: ShipDirection) {
        if currentDirection == direction {
            currentDirection = nil
        }
    }
}
