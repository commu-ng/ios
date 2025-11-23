import SwiftUI

struct ReactionPickerSheet: View {
    let onSelectEmoji: (String) -> Void
    @Environment(\.dismiss) var dismiss

    let emojis = ["👍", "❤️", "😂", "😮", "😢", "😡", "🙏", "👏", "🎉", "🔥", "💯", "✨", "💪", "🤔", "👀", "😍", "🥰", "😊", "😎", "🤩", "😭", "😳", "🙈", "🎈"]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            onSelectEmoji(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("messages.add_reaction", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
