import SwiftUI

struct MarkdownHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Text Formatting
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.text_formatting", comment: ""))

                        MarkdownExample(
                            syntax: "**bold**",
                            description: NSLocalizedString("markdown.bold", comment: "")
                        )

                        MarkdownExample(
                            syntax: "*italic*",
                            description: NSLocalizedString("markdown.italic", comment: "")
                        )

                        MarkdownExample(
                            syntax: "~~strikethrough~~",
                            description: NSLocalizedString("markdown.strikethrough", comment: "")
                        )

                        MarkdownExample(
                            syntax: "`code`",
                            description: NSLocalizedString("markdown.inline_code", comment: "")
                        )
                    }

                    // Headings
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.headings", comment: ""))

                        VStack(alignment: .leading, spacing: 8) {
                            MarkdownExample(syntax: "# Heading 1", description: "")
                            MarkdownExample(syntax: "## Heading 2", description: "")
                            MarkdownExample(syntax: "### Heading 3", description: "")
                        }
                    }

                    // Links
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.links", comment: ""))

                        MarkdownExample(
                            syntax: "[link text](https://example.com)",
                            description: NSLocalizedString("markdown.create_links", comment: "")
                        )

                        Text(NSLocalizedString("markdown.auto_links", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Images
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.images", comment: ""))

                        MarkdownExample(
                            syntax: "![alt text](image-url)",
                            description: NSLocalizedString("markdown.insert_image", comment: "")
                        )

                        Text(NSLocalizedString("markdown.image_upload_tip", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Lists
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.lists", comment: ""))

                        Text(NSLocalizedString("markdown.unordered_list", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        CodeBlock(code: """
- Item 1
- Item 2
- Item 3
""")

                        Text(NSLocalizedString("markdown.ordered_list", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        CodeBlock(code: """
1. First item
2. Second item
3. Third item
""")
                    }

                    // Blockquotes
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.blockquotes", comment: ""))

                        CodeBlock(code: "> This is a quote")
                    }

                    // Code Blocks
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.code_blocks", comment: ""))

                        CodeBlock(code: """
```
code block
with multiple lines
```
""")
                    }

                    // Line Breaks
                    Section {
                        SectionHeader(title: NSLocalizedString("markdown.line_breaks", comment: ""))

                        Text(NSLocalizedString("markdown.line_breaks_tip", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        CodeBlock(code: """
First paragraph.

Second paragraph.
""")
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("markdown.guide_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("markdown.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}

struct MarkdownExample: View {
    let syntax: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(syntax)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(4)

            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CodeBlock: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

#Preview {
    MarkdownHelpView()
}
