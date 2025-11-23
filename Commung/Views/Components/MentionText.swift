import SwiftUI

struct MentionText: View {
    let content: String
    let font: Font
    @EnvironmentObject var profileContext: ProfileContext

    init(_ content: String, font: Font = .body) {
        self.content = content
        self.font = font
    }

    private var segments: [TextSegment] {
        parseContent(content)
    }

    var body: some View {
        // Use a FlowLayout-like approach with Text concatenation
        segments.reduce(Text("")) { result, segment in
            switch segment {
            case .text(let string):
                return result + Text(attributedText(string))
            case .mention(let username):
                return result + Text("@\(username)")
                    .foregroundColor(.blue)
            }
        }
        .font(font)
        // Overlay with invisible NavigationLinks for mentions
        .overlay(
            MentionLinksOverlay(segments: segments)
                .environmentObject(profileContext)
        )
    }

    private func attributedText(_ string: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: string, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(string)
    }

    private func parseContent(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        let pattern = "@([a-zA-Z0-9_]+)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: range)

        var lastEnd = 0

        for match in matches {
            // Add text before the mention
            if match.range.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let textPart = nsText.substring(with: textRange)
                segments.append(.text(textPart))
            }

            // Add the mention
            if match.numberOfRanges > 1 {
                let usernameRange = match.range(at: 1)
                let username = nsText.substring(with: usernameRange)
                segments.append(.mention(username))
            }

            lastEnd = match.range.location + match.range.length
        }

        // Add remaining text
        if lastEnd < nsText.length {
            let remainingText = nsText.substring(from: lastEnd)
            segments.append(.text(remainingText))
        }

        return segments
    }
}

enum TextSegment {
    case text(String)
    case mention(String)
}

// Invisible overlay that provides tappable areas for mentions
struct MentionLinksOverlay: View {
    let segments: [TextSegment]
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        // Extract just the mentions for navigation
        let mentions = segments.compactMap { segment -> String? in
            if case .mention(let username) = segment {
                return username
            }
            return nil
        }

        // Create a menu for navigating to profiles
        // This is a workaround since we can't make individual Text segments tappable directly
        if !mentions.isEmpty {
            Menu {
                ForEach(mentions, id: \.self) { username in
                    NavigationLink(destination: ProfileDetailView(username: username).environmentObject(profileContext)) {
                        Label("@\(username)", systemImage: "person.circle")
                    }
                }
            } label: {
                Color.clear
            }
        }
    }
}

// A view that renders text with highlighted @mentions
// Mentions are styled in blue and accessible via context menu
// Taps pass through to parent NavigationLink (e.g., to post detail)
struct TappableMentionText: View {
    let content: String
    let font: Font
    @EnvironmentObject var profileContext: ProfileContext
    @State private var selectedUsername: String?

    init(_ content: String, font: Font = .body) {
        self.content = content
        self.font = font
    }

    private var mentionUsernames: [String] {
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: content, options: [], range: range)

        return matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let usernameRange = match.range(at: 1)
            return nsContent.substring(with: usernameRange)
        }
    }

    private var attributedContent: AttributedString {
        // First try to parse as markdown
        var result: AttributedString
        if let attributed = try? AttributedString(markdown: content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            result = attributed
        } else {
            result = AttributedString(content)
        }

        // Apply mention styling
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }

        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: content, options: [], range: range)

        // Apply styling to mentions (in reverse order to preserve indices)
        for match in matches.reversed() {
            if let swiftRange = Range(match.range, in: content) {
                let mentionText = String(content[swiftRange])
                if let attrRange = result.range(of: mentionText) {
                    result[attrRange].foregroundColor = .blue
                }
            }
        }

        return result
    }

    var body: some View {
        let uniqueMentions = Array(Set(mentionUsernames))

        if uniqueMentions.isEmpty {
            // No mentions - just show text
            Text(attributedContent)
                .font(font)
        } else {
            // Has mentions - show text with context menu for profile navigation
            Text(attributedContent)
                .font(font)
                .contextMenu {
                    ForEach(uniqueMentions, id: \.self) { username in
                        Button {
                            selectedUsername = username
                        } label: {
                            Label("@\(username)", systemImage: "person.circle")
                        }
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { selectedUsername != nil },
                    set: { if !$0 { selectedUsername = nil } }
                )) {
                    if let username = selectedUsername {
                        ProfileDetailView(username: username)
                            .environmentObject(profileContext)
                    }
                }
        }
    }
}

#Preview {
    NavigationView {
        VStack(alignment: .leading, spacing: 20) {
            TappableMentionText("Hello @john, how are you?")

            TappableMentionText("Check out @alice and @bob's posts!")

            TappableMentionText("No mentions here, just plain text.")

            TappableMentionText("**Bold** and @user mention")
        }
        .padding()
    }
    .environmentObject(ProfileContext())
}
