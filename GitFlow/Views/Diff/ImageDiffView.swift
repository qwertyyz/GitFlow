import SwiftUI
import AppKit

/// View for comparing two images visually.
struct ImageDiffView: View {
    let oldImage: NSImage?
    let newImage: NSImage?
    let oldPath: String
    let newPath: String

    @State private var diffMode: DiffMode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5
    @State private var overlayOpacity: Double = 0.5
    @State private var showDifference = false

    enum DiffMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case slider = "Slider"
        case overlay = "Overlay"
        case difference = "Difference"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            switch diffMode {
            case .sideBySide:
                sideBySideView
            case .slider:
                sliderView
            case .overlay:
                overlayView
            case .difference:
                differenceView
            }

            Divider()

            // Info Bar
            infoBar
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Picker("View Mode", selection: $diffMode) {
                ForEach(DiffMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            Spacer()

            if diffMode == .overlay {
                HStack(spacing: 8) {
                    Text("Opacity:")
                    Slider(value: $overlayOpacity, in: 0...1)
                        .frame(width: 100)
                    Text("\(Int(overlayOpacity * 100))%")
                        .frame(width: 40)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Side by Side View

    private var sideBySideView: some View {
        HStack(spacing: 1) {
            // Old image
            VStack {
                Text("Before")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                imagePanel(image: oldImage, label: "Deleted")
                    .background(Color.red.opacity(0.05))
            }

            Divider()

            // New image
            VStack {
                Text("After")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                imagePanel(image: newImage, label: "Added")
                    .background(Color.green.opacity(0.05))
            }
        }
    }

    // MARK: - Slider View

    private var sliderView: some View {
        GeometryReader { geometry in
            ZStack {
                // Old image (full width)
                if let oldImage = oldImage {
                    Image(nsImage: oldImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // New image (clipped)
                if let newImage = newImage {
                    Image(nsImage: newImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                                .offset(x: -geometry.size.width * (1 - sliderPosition) / 2)
                        )
                }

                // Slider line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: geometry.size.width * (sliderPosition - 0.5))

                // Slider handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    )
                    .offset(x: geometry.size.width * (sliderPosition - 0.5))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = value.location.x / geometry.size.width
                                sliderPosition = min(max(newPosition, 0), 1)
                            }
                    )
            }
            .padding()
        }
    }

    // MARK: - Overlay View

    private var overlayView: some View {
        ZStack {
            // Old image (background)
            if let oldImage = oldImage {
                Image(nsImage: oldImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // New image (overlay)
            if let newImage = newImage {
                Image(nsImage: newImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(overlayOpacity)
            }
        }
        .padding()
    }

    // MARK: - Difference View

    private var differenceView: some View {
        VStack {
            if let diffImage = createDifferenceImage() {
                Image(nsImage: diffImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Unable to compute difference")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Image Panel

    private func imagePanel(image: NSImage?, label: String) -> some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }

    // MARK: - Info Bar

    private var infoBar: some View {
        HStack {
            if let oldImage = oldImage {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before: \(Int(oldImage.size.width)) x \(Int(oldImage.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let newImage = newImage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("After: \(Int(newImage.size.width)) x \(Int(newImage.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Difference Calculation

    private func createDifferenceImage() -> NSImage? {
        guard let oldImage = oldImage,
              let newImage = newImage,
              let oldCgImage = oldImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let newCgImage = newImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = max(oldCgImage.width, newCgImage.width)
        let height = max(oldCgImage.height, newCgImage.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Draw old image
        context.draw(oldCgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Set blend mode to difference
        context.setBlendMode(.difference)

        // Draw new image on top
        context.draw(newCgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let diffCgImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: diffCgImage, size: NSSize(width: width, height: height))
    }
}

// MARK: - Image Diff Detector

/// Utility to detect if a file is an image that can be diffed.
enum ImageDiffDetector {
    static let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif", "ico"
    ]

    /// Checks if a file path is a supported image format.
    static func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// Loads an image from the repository at a specific ref.
    static func loadImage(from repository: URL, path: String, ref: String?, gitService: GitService) async -> NSImage? {
        // For working tree files (ref is nil), load directly
        if ref == nil {
            let fileURL = repository.appendingPathComponent(path)
            return NSImage(contentsOf: fileURL)
        }

        // For historical versions, we need to extract from git
        // This would use `git show ref:path`
        return nil
    }
}

// MARK: - Preview

#Preview {
    ImageDiffView(
        oldImage: NSImage(systemSymbolName: "photo", accessibilityDescription: nil),
        newImage: NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil),
        oldPath: "old/image.png",
        newPath: "new/image.png"
    )
    .frame(width: 800, height: 600)
}
