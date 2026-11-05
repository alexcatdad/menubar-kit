import AppKit

/// Renders the two PNGs `TrayIconLoader` expects: `<name>.png` (18x18 px) and
/// `<name>@2x.png` (36x36 px), black on transparent, ready to mark as a template.
///
/// Draw a custom glyph with `NSBezierPath` (in an 18x18pt rect, origin bottom
/// left), or start from an SF Symbol with `symbol(_:pointSize:weight:)`. Run it
/// at development time and commit the PNGs; the app only loads them. The
/// `make-tray-glyph` executable wraps this for SF Symbols (see the README).
public enum TrayGlyphRenderer {
    /// Draws into `TrayIconLoader.logicalSize` points.
    public typealias Drawing = (NSRect) -> Void

    /// PNG data for one scale (1 → 18x18 px, 2 → 36x36 px).
    public static func pngData(scale: Int, draw: Drawing) -> Data? {
        let size = TrayIconLoader.logicalSize
        guard scale > 0,
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width) * scale,
                pixelsHigh: Int(size.height) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return nil }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.black.setFill()
        NSColor.black.setStroke()
        draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    /// Writes `<baseName>.png` and `<baseName>@2x.png` into `directory`.
    ///
    /// - Returns: The two file URLs, 1x first.
    @discardableResult
    public static func write(baseName: String, to directory: URL, draw: Drawing) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written: [URL] = []
        for (scale, suffix) in [(1, ""), (2, "@2x")] {
            guard let data = pngData(scale: scale, draw: draw) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let url = directory.appendingPathComponent("\(baseName)\(suffix).png")
            try data.write(to: url, options: .atomic)
            written.append(url)
        }
        return written
    }

    /// A drawing of SF Symbol `name`, aspect-fit and centred in the glyph rect.
    /// `nil` if the symbol does not exist on this macOS.
    public static func symbol(
        _ name: String, pointSize: CGFloat = 15, weight: NSFont.Weight = .regular
    ) -> Drawing? {
        guard
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
                        .applying(NSImage.SymbolConfiguration(hierarchicalColor: .black)))
        else { return nil }
        return { bounds in
            let size = image.size
            let scale = min(1, bounds.width / size.width, bounds.height / size.height)
            let fitted = NSSize(width: size.width * scale, height: size.height * scale)
            let rect = NSRect(
                x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                width: fitted.width, height: fitted.height)
            image.draw(in: rect)
        }
    }
}
