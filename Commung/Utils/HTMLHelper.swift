import Foundation
import UIKit
import SwiftUI

extension String {
    func htmlToAttributedString(font: UIFont = .systemFont(ofSize: 16), color: UIColor = .label) -> NSAttributedString? {
        guard let data = data(using: .utf8) else { return nil }

        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]

            let attributedString = try NSMutableAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )

            // Create paragraph style with spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 16
            paragraphStyle.lineSpacing = 6

            // Apply the desired font, color, and paragraph style to the entire string
            let range = NSRange(location: 0, length: attributedString.length)
            attributedString.addAttribute(.font, value: font, range: range)
            attributedString.addAttribute(.foregroundColor, value: color, range: range)
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

            return attributedString
        } catch {
            print("Error converting HTML to AttributedString: \(error)")
            return nil
        }
    }
}
