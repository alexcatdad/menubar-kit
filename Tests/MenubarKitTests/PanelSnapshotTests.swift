import AppKit
import SwiftUI
import Testing

@testable import MenubarKit

@MainActor
private func image(_ data: Data?) throws -> NSBitmapImageRep {
    try #require(data.flatMap(NSBitmapImageRep.init(data:)))
}

@MainActor
@Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
func panelSnapshotFramesThePanel(appearance: NSAppearance.Name) throws {
    let panel = MenubarPanel {
        StatusHeader(tone: .ok, headline: "All clear", detail: "3 items")
        StatusRowsTile([MenubarStatusRow(title: "Service", value: "Running", tone: .ok)])
    }
    let rep = try image(PanelSnapshot.png(of: panel, appearance: appearance))
    let expectedWidth = (MenubarMetrics.panelWidth + PanelSnapshot.margin * 2) * 2
    #expect(rep.pixelsWide == Int(expectedWidth))
    #expect(rep.pixelsHigh > Int(PanelSnapshot.margin * 4))
    // The corner is transparent canvas; the centre is the opaque card.
    #expect(rep.colorAt(x: 0, y: 0)?.alphaComponent == 0)
    #expect(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)?.alphaComponent == 1)
    writeArtifact(rep, name: "panel-\(appearance.rawValue)")
}

@MainActor
@Test func windowChromeAddsATitleBar() throws {
    let form = Text("Settings body").padding()
    let panel = try image(PanelSnapshot.png(of: form, width: 300, appearance: .aqua, scale: 1))
    let window = try image(
        PanelSnapshot.png(of: form, width: 300, chrome: .window(title: "Settings"), appearance: .darkAqua, scale: 1))
    #expect(window.pixelsHigh - panel.pixelsHigh == Int(PanelSnapshot.titleBarHeight))
    #expect(window.pixelsWide == panel.pixelsWide)
    #expect(
        PanelSnapshot.background(isDark: true, chrome: .panel)
            != PanelSnapshot.background(isDark: false, chrome: .panel))
    #expect(
        PanelSnapshot.background(isDark: true, chrome: .window(title: "x"))
            != PanelSnapshot.background(isDark: false, chrome: .window(title: "x")))
    writeArtifact(window, name: "window-dark")
}

/// Writes the image into `$MENUBARKIT_RENDER_ARTIFACTS` when it is set.
@MainActor
private func writeArtifact(_ rep: NSBitmapImageRep, name: String) {
    guard let directory = ProcessInfo.processInfo.environment["MENUBARKIT_RENDER_ARTIFACTS"], !directory.isEmpty,
        let png = rep.representation(using: .png, properties: [:])
    else { return }
    try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
}
