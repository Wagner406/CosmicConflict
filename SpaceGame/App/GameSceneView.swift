import SwiftUI
import SpriteKit

struct GameView: View {

    @Binding var showGame: Bool
    let level: GameLevel

    @State private var scene: GameScene

    init(showGame: Binding<Bool>, level: GameLevel) {
        _showGame = showGame
        self.level = level

        let s = GameScene()

        // WICHTIG: Scene-Size NICHT manuell setzen.
        // SpriteView + resizeFill übernimmt das und passt bei Rotation/iPad/Mac korrekt an.
        s.scaleMode = .resizeFill

        // Level in die Szene geben
        s.level = level

        // Callback: nach Level-Ende zurück ins Menü
        s.onLevelCompleted = {
            showGame.wrappedValue = false
        }

        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 16) {
                        // OBEN
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color.white.opacity(0.9))
                            .onLongPressGesture(
                                minimumDuration: 0,
                                maximumDistance: .infinity,
                                pressing: { isPressing in
                                    if isPressing {
                                        scene.startMoving(.forward)
                                    } else {
                                        scene.stopMoving(.forward)
                                    }
                                },
                                perform: {}
                            )

                        HStack(spacing: 16) {
                            // LINKS
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color.white.opacity(0.9))
                                .onLongPressGesture(
                                    minimumDuration: 0,
                                    maximumDistance: .infinity,
                                    pressing: { isPressing in
                                        if isPressing {
                                            scene.startMoving(.rotateLeft)
                                        } else {
                                            scene.stopMoving(.rotateLeft)
                                        }
                                    },
                                    perform: {}
                                )

                            // UNTEN
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color.white.opacity(0.9))
                                .onLongPressGesture(
                                    minimumDuration: 0,
                                    maximumDistance: .infinity,
                                    pressing: { isPressing in
                                        if isPressing {
                                            scene.startMoving(.backward)
                                        } else {
                                            scene.stopMoving(.backward)
                                        }
                                    },
                                    perform: {}
                                )

                            // RECHTS
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color.white.opacity(0.9))
                                .onLongPressGesture(
                                    minimumDuration: 0,
                                    maximumDistance: .infinity,
                                    pressing: { isPressing in
                                        if isPressing {
                                            scene.startMoving(.rotateRight)
                                        } else {
                                            scene.stopMoving(.rotateRight)
                                        }
                                    },
                                    perform: {}
                                )
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }
}
