import AppKit
import Foundation
import Testing

@testable import MenubarKit

private func loadFixtureIcon() throws -> NSImage {
    let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
    return try #require(TrayIconLoader.load(resourcesDirectory: fixtures, baseName: "TestTrayIcon"))
}

private func bitmap(_ image: NSImage, scale: Int) throws -> NSBitmapImageRep {
    try #require(
        image.representations.compactMap { $0 as? NSBitmapImageRep }
            .first { $0.pixelsHigh == Int(image.size.height) * scale })
}

/// Whether any pixel right of the 18pt glyph area is visible.
private func hasVisiblePixelRightOfGlyph(_ rep: NSBitmapImageRep, scale: Int) -> Bool {
    for y in 0..<rep.pixelsHigh {
        for x in (18 * scale)..<rep.pixelsWide {
            if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0 {
                return true
            }
        }
    }
    return false
}

@Test func okToneIsTheBareGlyph() throws {
    let image = TrayIconComposer.image(icon: try loadFixtureIcon(), fallbackSymbol: "note.text", tone: .ok)
    #expect(image.isTemplate)
    #expect(image.size == NSSize(width: 18, height: 18))
    let reps = image.representations.compactMap { $0 as? NSBitmapImageRep }
    #expect(Set(reps.map(\.pixelsWide)) == [18, 36])
    #expect(reps.allSatisfy(TrayIconLoader.hasVisiblePixel))
}

@Test(arguments: [StatusTone.warning, .error, .off, .update])
func attentionTonesCompositeTheBadgeIntoOneTemplateImage(tone: StatusTone) throws {
    let icon = try loadFixtureIcon()
    let ok = TrayIconComposer.image(icon: icon, fallbackSymbol: "note.text", tone: .ok)
    let badged = TrayIconComposer.image(icon: icon, fallbackSymbol: "note.text", tone: tone)

    #expect(badged.isTemplate)
    #expect(badged.size.height == 18)
    #expect(badged.size.width > ok.size.width)
    for scale in [1, 2] {
        let rep = try bitmap(badged, scale: scale)
        #expect(hasVisiblePixelRightOfGlyph(rep, scale: scale))
        #expect(rep.tiffRepresentation != (try bitmap(ok, scale: scale)).tiffRepresentation)
    }
}

@Test func fallbackSymbolIsDrawnWhenIconIsMissing() throws {
    let ok = TrayIconComposer.image(icon: nil, fallbackSymbol: "note.text", tone: .ok)
    #expect(ok.isTemplate)
    #expect(ok.size == NSSize(width: 18, height: 18))
    #expect(TrayIconLoader.hasVisiblePixel(try bitmap(ok, scale: 2)))

    let badged = TrayIconComposer.image(icon: nil, fallbackSymbol: "note.text", tone: .error)
    #expect(hasVisiblePixelRightOfGlyph(try bitmap(badged, scale: 2), scale: 2))
}
