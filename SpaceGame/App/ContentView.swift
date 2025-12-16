import SwiftUI

struct ContentView: View {

    @State private var showGame = false
    @State private var selectedLevel: GameLevel? = nil

    var body: some View {

        if showGame, let selectedLevel {
            // GameView bekommt jetzt das Level + Binding zurück ins Menü
            GameView(showGame: $showGame, level: selectedLevel)
        } else {

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Text("Space Game")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Text("Demo Build")
                        .foregroundColor(.gray)

                    // Level 1 Button
                    Button("Play Level 1") {
                        selectedLevel = GameLevels.level1
                        showGame = true
                    }
                    .font(.title2.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)

                    // Level 2 Button (Boss)
                    Button("Play Level 2 (Boss)") {
                        selectedLevel = GameLevels.level2
                        showGame = true
                    }
                    .font(.title3.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .foregroundColor(.white)
                }
            }
        }
    }
}
