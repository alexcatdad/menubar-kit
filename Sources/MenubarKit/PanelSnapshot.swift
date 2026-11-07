import AppKit
import SwiftUI

/// Documentation screenshots of a panel or window, the same for every app.
///
/// The view is drawn offscreen (no screen capture, so nothing private on the
/// desktop can end up in the image) and placed on a frame that matches the
/// current macOS window style: rounded corners, a hairline border and a soft
/// shadow, on a transparent canvas. Use it from an environment-gated render
/// test with fixture data to regenerate the website screenshots.
@MainActor
public enum PanelSnapshot {
    /// What surrounds the view.
    public enum Chrome: Equatable, Sendable {
        /// The menu bar panel: a rounded card.
        case panel
        /// A window, such as Settings: a rounded card with a title bar.
        case window(title: String)
    }

    /// The corner radius of the frame, in points.
    public static let cornerRadius: CGFloat = 16
    /// The transparent margin around the frame that holds the shadow, in points.
    public static let margin: CGFloat = 32
    /// The title bar height for `.window`, in points.
    public static let titleBarHeight: CGFloat = 32

    /// A PNG of `view` at `width` points on the given chrome and appearance,
    /// at `scale` pixels per point. Nil when drawing fails.
    public static func png(
        of view: some View,
        width: CGFloat = MenubarMetrics.panelWidth,
        chrome: Chrome = .panel,
        appearance appearanceName: NSAppearance.Name = .aqua,
        scale: CGFloat = 2
    ) -> Data? {
        guard let appearance = NSAppearance(named: appearanceName) else { return nil }
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let fill = background(isDark: isDark, chrome: chrome)
        guard
            let content = drawContent(
                of: view.frame(width: width).background(Color(nsColor: fill)).environment(
                    \.colorScheme, isDark ? .dark : .light),
                width: width, appearance: appearance)
        else { return nil }
        let titleHeight: CGFloat = chrome == .panel ? 0 : titleBarHeight
        let card = NSRect(
            x: margin, y: margin, width: content.size.width, height: content.size.height + titleHeight)
        let canvas = NSSize(width: card.width + margin * 2, height: card.height + margin * 2)
        guard
            let output = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int((canvas.width * scale).rounded()),
                pixelsHigh: Int((canvas.height * scale).rounded()), bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        // Points, not pixels: set before creating the context so drawing is scaled.
        output.size = canvas
        guard let context = NSGraphicsContext(bitmapImageRep: output) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        appearance.performAsCurrentDrawingAppearance {
            let shape = NSBezierPath(roundedRect: card, xRadius: cornerRadius, yRadius: cornerRadius)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(isDark ? 0.5 : 0.22)
            shadow.shadowBlurRadius = 20
            shadow.shadowOffset = NSSize(width: 0, height: -6)
            shadow.set()
            fill.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            content.draw(in: NSRect(x: card.minX, y: card.minY, width: content.size.width, height: content.size.height))
            if case .window(let title) = chrome {
                drawTitleBar(
                    title, in: NSRect(x: card.minX, y: card.maxY - titleHeight, width: card.width, height: titleHeight),
                    isDark: isDark)
            }
            NSGraphicsContext.restoreGraphicsState()

            let border = NSBezierPath(
                roundedRect: card.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius - 0.5, yRadius: cornerRadius - 0.5)
            border.lineWidth = 1
            (isDark ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.1)).setStroke()
            border.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        return output.representation(using: .png, properties: [:])
    }

    /// Lays `view` out in an offscreen window and draws it into a bitmap.
    private static func drawContent(of view: some View, width: CGFloat, appearance: NSAppearance)
        -> NSBitmapImageRep?
    {
        let host = NSHostingView(rootView: view.frame(width: width))
        host.appearance = appearance
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 900),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        defer { window.contentView = nil }
        guard host.bounds.width > 0, host.bounds.height > 0,
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)
        else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        rep.size = host.bounds.size
        return rep
    }

    /// The frame's fill: the panel material and the window background,
    /// flattened to opaque colours so the image reads on any page.
    static func background(isDark: Bool, chrome: Chrome) -> NSColor {
        switch (chrome, isDark) {
        case (.panel, false): NSColor(white: 0.965, alpha: 1)
        case (.panel, true): NSColor(white: 0.155, alpha: 1)
        case (.window, false): NSColor(white: 0.93, alpha: 1)
        case (.window, true): NSColor(white: 0.18, alpha: 1)
        }
    }

    private static func drawTitleBar(_ title: String, in rect: NSRect, isDark: Bool) {
        let lights: [NSColor] = [
            NSColor(red: 1, green: 0.373, blue: 0.341, alpha: 1),
            NSColor(red: 0.996, green: 0.737, blue: 0.18, alpha: 1),
            NSColor(red: 0.157, green: 0.784, blue: 0.251, alpha: 1),
        ]
        for (index, color) in lights.enumerated() {
            let dot = NSRect(x: rect.minX + 14 + CGFloat(index) * 20, y: rect.midY - 6, width: 12, height: 12)
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: isDark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.12, alpha: 1),
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
}
