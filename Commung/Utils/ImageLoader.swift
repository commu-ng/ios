import SwiftUI
import Kingfisher

struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image?
    let contentMode: SwiftUI.ContentMode

    init(
        url: URL?,
        placeholder: Image? = Image(systemName: "photo"),
        contentMode: SwiftUI.ContentMode = .fit
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
    }

    var body: some View {
        if let url = url {
            KFImage(url)
                .placeholder {
                    placeholder?
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            placeholder?
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .foregroundColor(.gray.opacity(0.3))
        }
    }
}

struct CachedCircularImage: View {
    let url: URL?
    let size: CGFloat

    init(url: URL?, size: CGFloat = 40) {
        self.url = url
        self.size = size
    }

    var body: some View {
        if let url = url {
            KFImage(url)
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
        }
    }
}

extension KFImage {
    func commonImageModifiers() -> some View {
        self
            .cacheMemoryOnly()
            .fade(duration: 0.2)
            .onProgress { receivedSize, totalSize in
                // Optional: Handle download progress
            }
            .onSuccess { result in
                // Optional: Handle success
            }
            .onFailure { error in
                // Optional: Handle failure
                print("Image loading failed: \(error)")
            }
    }
}
