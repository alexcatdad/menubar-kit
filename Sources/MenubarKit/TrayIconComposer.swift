import AppKit

/// Builds the single template image a `MenuBarExtra` label shows.
///
/// `MenuBarExtra` renders its label as one image (plus text), so a badge laid
/// out as a second SwiftUI `Image` is dropped. The attention badge is
/// therefore drawn into the same template image as the glyph: 18x18pt glyph,
/// 3pt gap, then a heavy 9pt `exclamationmark`, vertically centred.
public enum TrayIconComposer {
    /// Gap between glyph and badge, in points.
    public static let badgeSpacing: CGFloat = 3
    /// Point size of the fallback SF Symbol drawn when no tray PNG is available.
    public static let fallbackPointSize: CGFloat = 14

    /// The tray image for `tone`.
    ///
    /// - Parameters:
    ///   - icon: From `TrayIconLoader.load`. `nil` draws `fallbackSymbol` instead.
    ///   - fallbackSymbol: SF Symbol name used when `icon` is `nil`.
    ///   - tone: Anything but `.ok` appends the badge.
    /// - Returns: A template image, 18pt high, with 1x and 2x bitmap representations.
    public static func image(icon: NSImage?, fallbackSymbol: String, tone: StatusTone) -> NSImage {
        let glyphSize = TrayIconLoader.logicalSize
        let glyph = icon ?? symbol(fallbackSymbol, pointSize: fallbackPointSize, weight: .regular)
        let badge = tone.needsAttention ? symbol("exclamationmark", pointSize: 9, weight: .heavy) : nil

        var size = glyphSize
        if let badge {
            size.width += badgeSpacing + ceil(badge.size.width)
        }

        let image = NSImage(size: size)
        for scale in [1, 2] {
            guard
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
            else { continue }
            rep.size = size

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            if let glyph {
                glyph.draw(in: fit(glyph.size, in: NSRect(origin: .zero, size: glyphSize)))
            }
            if let badge {
                let origin = NSPoint(
                    x: glyphSize.width + badgeSpacing,
                    y: ((size.height - badge.size.height) / 2).rounded()
                )
                badge.draw(in: NSRect(origin: origin, size: badge.size))
            }
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        return image
    }

    private static func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))
    }

    /// Aspect-fits `size` into `bounds`, centred, never scaling up past `bounds`.
    private static func fit(_ size: NSSize, in bounds: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: bounds.minX + (bounds.width - fitted.width) / 2,
            y: bounds.minY + (bounds.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
