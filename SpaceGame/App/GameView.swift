import SwiftUI
import SpriteKit

struct GameView: View {

    @Binding var showGame: Bool
    let level: GameLevel
    let isGodModeEnabled: Bool

    @State private var scene: GameScene

    init(
        showGame: Binding<Bool>,
        level: GameLevel,
        isGodModeEnabled: Bool
    ) {
        _showGame = showGame
        self.level = level
        self.isGodModeEnabled = isGodModeEnabled

        let s = GameScene()
        s.scaleMode = .resizeFill

        // Level setzen
        s.level = level

        // GodMode an Scene weitergeben
        s.isGodModeEnabled = isGodModeEnabled

        // Callback zurück ins Menü
        s.onLevelCompleted = {
            showGame.wrappedValue = false
        }

        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // ───── Controls ─────
            VStack {
                Spacer()

                HStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.9))
                            .onLongPressGesture(
                                minimumDuration: 0,
                                pressing: { isPressing in
                                    isPressing
                                        ? scene.startMoving(.forward)
                                        : scene.stopMoving(.forward)
                                },
                                perform: {}
                            )

                        HStack(spacing: 16) {
                            arrow("left", .rotateLeft)
                            arrow("down", .backward)
                            arrow("right", .rotateRight)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Helper
    private func arrow(_ dir: String, _ action: GameScene.ShipDirection) -> some View {
        Image(systemName: "arrow.\(dir).circle.fill")
            .font(.system(size: 50))
            .foregroundColor(.white.opacity(0.9))
            .onLongPressGesture(
                minimumDuration: 0,
                pressing: { isPressing in
                    isPressing
                        ? scene.startMoving(action)
                        : scene.stopMoving(action)
                },
                perform: {}
            )
    }
}
