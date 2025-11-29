import SwiftUI

struct MarkdownTextView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdownBlocks(content).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private func parseMarkdownBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph: [String] = []
        var inCodeBlock = false
        var codeBlockContent: [String] = []

        for line in lines {
            // Code block
            if line.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.codeBlock(codeBlockContent.joined(separator: "\n")))
                    codeBlockContent = []
                    inCodeBlock = false
                } else {
                    if !currentParagraph.isEmpty {
                        blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                        currentParagraph = []
                    }
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }

            // Heading
            if line.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.heading(1, String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.heading(2, String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.heading(3, String(line.dropFirst(4))))
            }
            // Blockquote
            else if line.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.blockquote(String(line.dropFirst(2))))
            }
            // Unordered list
            else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.listItem(String(line.dropFirst(2))))
            }
            // Ordered list
            else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                blocks.append(.orderedListItem(String(line[match.upperBound...])))
            }
            // Empty line - end paragraph
            else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
            }
            // Regular text
            else {
                currentParagraph.append(line)
            }
        }

        // Don't forget remaining paragraph
        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(currentParagraph.joined(separator: " ")))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderInlineMarkdown(text)
                .font(level == 1 ? .title : level == 2 ? .title2 : .title3)
                .fontWeight(.bold)

        case .paragraph(let text):
            renderInlineMarkdown(text)
                .font(.body)

        case .blockquote(let text):
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 3)
                renderInlineMarkdown(text)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.vertical, 4)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                renderInlineMarkdown(text)
                    .font(.body)
            }

        case .orderedListItem(let text):
            HStack(alignment: .top, spacing: 8) {
                renderInlineMarkdown(text)
                    .font(.body)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    private func renderInlineMarkdown(_ text: String) -> Text {
        if let attributedString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributedString)
        } else {
            return Text(text)
        }
    }
}

private enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case blockquote(String)
    case listItem(String)
    case orderedListItem(String)
    case codeBlock(String)
}
