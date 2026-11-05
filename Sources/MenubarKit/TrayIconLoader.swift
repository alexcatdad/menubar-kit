import AppKit

/// Loads a menu bar glyph as an 18x18pt template image from two bundled PNGs:
/// `<baseName>.png` (18x18 px) and `<baseName>@2x.png` (36x36 px).
///
/// Loading fails closed: if either file is missing, has the wrong pixel size,
/// has no alpha channel or is fully transparent, the result is `nil` and the
/// caller shows its SF Symbol fallback instead of a broken glyph.
public enum TrayIconLoader {
    /// The logical size every tray glyph is drawn at, in points.
    public static let logicalSize = NSSize(width: 18, height: 18)

    /// Loads `<baseName>.png` and `<baseName>@2x.png` from `resourcesDirectory`.
    ///
    /// - Parameters:
    ///   - resourcesDirectory: Usually `Bundle.main.resourceURL`.
    ///   - baseName: The file name without scale suffix or extension, for example `"ScratchpadTrayIcon"`.
    public static func load(resourcesDirectory: URL?, baseName: String) -> NSImage? {
        guard let resourcesDirectory, !baseName.isEmpty else { return nil }

        let representations: [(name: String, pixels: Int)] = [
            ("\(baseName).png", Int(logicalSize.width)),
            ("\(baseName)@2x.png", Int(logicalSize.width) * 2),
        ]

        var imageRepresentations: [NSBitmapImageRep] = []
        for resource in representations {
            let url = resourcesDirectory.appendingPathComponent(resource.name)
            guard let data = try? Data(contentsOf: url),
                let representation = NSBitmapImageRep(data: data),
                representation.pixelsWide == resource.pixels,
                representation.pixelsHigh == resource.pixels,
                representation.hasAlpha,
                hasVisiblePixel(representation)
            else {
                return nil
            }

            representation.size = logicalSize
            imageRepresentations.append(representation)
        }

        let image = NSImage(size: logicalSize)
        imageRepresentations.forEach(image.addRepresentation)
        image.isTemplate = true
        return image
    }

    static func hasVisiblePixel(_ representation: NSBitmapImageRep) -> Bool {
        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                guard let color = representation.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if color.alphaComponent > 0 { return true }
            }
        }
        return false
    }
}
