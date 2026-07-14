import SwiftUI

struct AttributeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let attribute: AttributeType

    var body: some View {
        NavigationStack {
            ZStack {
                QuestboundTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(attribute.displayName)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(attribute.usageDescription)
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
