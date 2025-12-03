import SwiftUI

struct ContentView: View {

    @State private var showGame = false

    var body: some View {

        if showGame {
            GameView(showGame: $showGame)   // <– Binding übergeben
        } else {

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Text("Space Game")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Button("PLAY") {
                        showGame = true
                    }
                    .font(.title2.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
                }
            }
        }
    }
}
