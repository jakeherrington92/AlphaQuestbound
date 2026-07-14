import SwiftUI

struct ComingSoonView: View {
    let title: String

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Coming soon")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
