//
//  GameView.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SwiftUI
import SpriteKit

struct GameView: View {

    @Binding var showGame: Bool

    @State private var scene: GameScene

    init(showGame: Binding<Bool>) {
        _showGame = showGame

        // Szene wie bisher erstellen
        let s = GameScene()
        let screenSize = UIScreen.current?.bounds.size ?? .zero
        s.size = screenSize
        s.scaleMode = .resizeFill

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

#Preview {
    GameView(showGame: .constant(true))
}
