import AppKit
import Foundation
import Testing

@testable import MenubarKit

private func codeRuns(_ text: AttributedString) -> [String] {
    text.runs.compactMap { run in
        run.inlinePresentationIntent == .code ? String(text[run.range].characters) : nil
    }
}

@Test func inlineCodeMarksBacktickSpans() {
    let text = InlineCode.attributed("Run `task check` in `~/src/my_app`.")
    #expect(String(text.characters) == "Run task check in ~/src/my_app.")
    #expect(codeRuns(text) == ["task check", "~/src/my_app"])
}

@Test func inlineCodeLeavesOtherMarkupAndUnmatchedBackticksLiteral() {
    let text = InlineCode.attributed("*not bold* [link](x) `ok` and a stray ` tick")
    #expect(String(text.characters) == "*not bold* [link](x) ok and a stray ` tick")
    #expect(codeRuns(text) == ["ok"])
    #expect(InlineCode.plain("no code") == "no code")
    #expect(String(InlineCode.attributed("a `` b").characters) == "a  b")
}

@Test func listRowReadsAsOneLabel() {
    #expect(
        ListRowButton.accessibilityLabel(title: "api", subtitle: "https://api.test", value: ":3000")
            == "api, https://api.test, :3000")
    #expect(ListRowButton.accessibilityLabel(title: "api", subtitle: "", value: nil) == "api")
}

@Test func notificationSettingsNoteFollowsPermission() {
    let note = { (enabled: Bool, permission: NotificationPermission?, error: String?) in
        NotificationSettingsSection.note(
            enabled: enabled, permission: permission, requestError: error, explanation: "Silent by default.")
    }
    #expect(note(false, .denied, nil) == "Silent by default.")
    #expect(note(true, .authorized, nil) == "Silent by default.")
    #expect(note(true, .denied, nil)?.contains("blocked") == true)
    #expect(note(true, .notDetermined, nil)?.contains("will ask") == true)
    #expect(note(true, .notDetermined, "No bundle") == "macOS could not ask for permission: No bundle")
}

@Test func trayGlyphRendererWritesWhatTheLoaderAccepts() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("menubar-kit-glyph-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let drawing = try #require(TrayGlyphRenderer.symbol("circle.fill"))
    let urls = try TrayGlyphRenderer.write(baseName: "Glyph", to: directory, draw: drawing)
    #expect(urls.map(\.lastPathComponent) == ["Glyph.png", "Glyph@2x.png"])

    let image = try #require(TrayIconLoader.load(resourcesDirectory: directory, baseName: "Glyph"))
    #expect(image.isTemplate)
    let pixels = image.representations.map(\.pixelsWide).sorted()
    #expect(pixels == [18, 36])
}

@Test func trayGlyphRendererDrawsCustomShapesAndRejectsUnknownSymbols() throws {
    #expect(TrayGlyphRenderer.symbol("not.a.real.symbol.name") == nil)
    let data = try #require(
        TrayGlyphRenderer.pngData(scale: 2) { rect in
            NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).fill()
        })
    let rep = try #require(NSBitmapImageRep(data: data))
    #expect(rep.pixelsWide == 36)
    #expect(TrayIconLoader.hasVisiblePixel(rep))
    let centre = try #require(rep.colorAt(x: 18, y: 18)?.usingColorSpace(.deviceRGB))
    #expect(centre.alphaComponent == 1)
    #expect(centre.redComponent == 0)
    #expect(TrayGlyphRenderer.pngData(scale: 0) { _ in } == nil)
}
