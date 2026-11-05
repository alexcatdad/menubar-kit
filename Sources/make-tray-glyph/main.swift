// Writes a tray glyph pair (<name>.png, <name>@2x.png) from an SF Symbol.
//
//   swift run make-tray-glyph --symbol pawprint.fill --name PawProxyTrayIcon --output Resources
//
// Options: --point-size (default 15), --weight ultralight|thin|light|regular|medium|semibold|bold|heavy|black.
// For a custom shape, call TrayGlyphRenderer.write(baseName:to:draw:) from a script or test.

import AppKit
import MenubarKit

let usage = """
    usage: make-tray-glyph --symbol <SF Symbol> --name <base name> [--output <dir>] [--point-size <pt>] [--weight <weight>]
    """

let weights: [String: NSFont.Weight] = [
    "ultralight": .ultraLight, "thin": .thin, "light": .light, "regular": .regular, "medium": .medium,
    "semibold": .semibold, "bold": .bold, "heavy": .heavy, "black": .black,
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n" + usage + "\n").utf8))
    exit(64)
}

var options: [String: String] = [:]
var arguments = CommandLine.arguments.dropFirst()
while let flag = arguments.popFirst() {
    guard flag.hasPrefix("--"), let value = arguments.popFirst() else { fail("unexpected argument: \(flag)") }
    options[String(flag.dropFirst(2))] = value
}

guard let symbolName = options["symbol"] else { fail("missing --symbol") }
guard let name = options["name"], !name.isEmpty else { fail("missing --name") }
let output = URL(fileURLWithPath: options["output"] ?? FileManager.default.currentDirectoryPath)
guard let pointSize = Double(options["point-size"] ?? "15"), pointSize > 0 else { fail("bad --point-size") }
guard let weight = weights[options["weight"] ?? "regular"] else { fail("bad --weight") }
guard let drawing = TrayGlyphRenderer.symbol(symbolName, pointSize: pointSize, weight: weight) else {
    fail("no SF Symbol named \(symbolName) on this macOS")
}

do {
    for url in try TrayGlyphRenderer.write(baseName: name, to: output, draw: drawing) {
        print(url.path)
    }
} catch {
    fail("could not write the glyph: \(error.localizedDescription)")
}
