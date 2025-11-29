import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotosPickerImage: Transferable {
    let data: Data
    let fileExtension: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            // Detect image type from data
            let fileExtension = detectImageType(from: data)
            return PhotosPickerImage(data: data, fileExtension: fileExtension)
        }
    }

    private static func detectImageType(from data: Data) -> String {
        guard data.count >= 8 else { return "jpg" }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpg"
        }

        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "gif"
        }

        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "webp"
        }

        // HEIC: check for ftyp box with heic/heix brand
        if data.count >= 12 {
            let ftypBytes = [UInt8](data[4..<12])
            let ftypString = String(bytes: ftypBytes, encoding: .ascii) ?? ""
            if ftypString.hasPrefix("ftyp") && (ftypString.contains("heic") || ftypString.contains("heix") || ftypString.contains("mif1")) {
                return "heic"
            }
        }

        return "jpg"
    }
}
