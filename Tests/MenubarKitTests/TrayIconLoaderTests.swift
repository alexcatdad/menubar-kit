import AppKit
import Foundation
import Testing

@testable import MenubarKit

private let baseName = "TestTrayIcon"

@Test func trayIconLoaderAddsBothPNGsAtOneLogicalSize() throws {
    let resources = try temporaryResources(copying: ["\(baseName).png", "\(baseName)@2x.png"])
    defer { try? FileManager.default.removeItem(at: resources) }

    let image = try #require(TrayIconLoader.load(resourcesDirectory: resources, baseName: baseName))
    #expect(image.isTemplate)
    #expect(image.size == NSSize(width: 18, height: 18))

    let representations = image.representations.compactMap { $0 as? NSBitmapImageRep }
    #expect(representations.count == 2)
    #expect(Set(representations.map { "\($0.pixelsWide)x\($0.pixelsHigh)" }) == ["18x18", "36x36"])
    #expect(representations.allSatisfy { $0.size == NSSize(width: 18, height: 18) })
    #expect(representations.allSatisfy(TrayIconLoader.hasVisiblePixel))
}

@Test func trayIconLoaderFailsClosedWhenOneResourceIsMissing() throws {
    let resources = try temporaryResources(copying: ["\(baseName).png"])
    defer { try? FileManager.default.removeItem(at: resources) }

    #expect(TrayIconLoader.load(resourcesDirectory: resources, baseName: baseName) == nil)
    #expect(TrayIconLoader.load(resourcesDirectory: nil, baseName: baseName) == nil)
    #expect(TrayIconLoader.load(resourcesDirectory: resources, baseName: "") == nil)
}

@Test func trayIconLoaderRejectsWrongPixelSize() throws {
    // Both files are the 1x image, so the @2x one has the wrong size.
    let resources = try temporaryResources(copying: [])
    defer { try? FileManager.default.removeItem(at: resources) }
    let oneX = fixtures().appendingPathComponent("\(baseName).png")
    try FileManager.default.copyItem(at: oneX, to: resources.appendingPathComponent("\(baseName).png"))
    try FileManager.default.copyItem(at: oneX, to: resources.appendingPathComponent("\(baseName)@2x.png"))

    #expect(TrayIconLoader.load(resourcesDirectory: resources, baseName: baseName) == nil)
}

@Test func trayIconLoaderRejectsFullyTransparentImages() throws {
    let resources = try temporaryResources(copying: [])
    defer { try? FileManager.default.removeItem(at: resources) }
    try transparentPNG(pixels: 18).write(to: resources.appendingPathComponent("\(baseName).png"))
    try transparentPNG(pixels: 36).write(to: resources.appendingPathComponent("\(baseName)@2x.png"))

    #expect(TrayIconLoader.load(resourcesDirectory: resources, baseName: baseName) == nil)
}

private func fixtures() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true)
}

private func temporaryResources(copying names: [String]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MenubarKitTrayIconTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in names {
        try FileManager.default.copyItem(
            at: fixtures().appendingPathComponent(name), to: directory.appendingPathComponent(name))
    }
    return directory
}

private func transparentPNG(pixels: Int) throws -> Data {
    let rep = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
    return try #require(rep.representation(using: .png, properties: [:]))
}
