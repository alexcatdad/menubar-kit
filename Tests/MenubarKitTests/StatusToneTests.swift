import Foundation
import Testing

@testable import MenubarKit

@Test func everyToneHasItsOwnSymbolShape() {
    let symbols = StatusTone.allCases.map(\.symbol)
    #expect(Set(symbols).count == StatusTone.allCases.count)
    #expect(StatusTone.ok.symbol == "checkmark.circle.fill")
    #expect(StatusTone.warning.symbol == "exclamationmark.triangle.fill")
    #expect(StatusTone.error.symbol == "xmark.octagon.fill")
    #expect(StatusTone.off.symbol == "stop.circle.fill")
    #expect(StatusTone.update.symbol == "arrow.up.circle.fill")
}

@Test func onlyOkHidesTheAttentionBadge() {
    #expect(StatusTone.allCases.filter { !$0.needsAttention } == [.ok])
}

@Test func statusFallsBackToToneWord() {
    #expect(MenubarStatus(tone: .error, headline: "Broken").word == "Error")
    #expect(MenubarStatus(tone: .ok, word: "Connected", headline: "Fine").word == "Connected")
}

@Test func trayAccessibilityLabelNamesAppThenStatus() {
    #expect(TrayAccessibility.label(appName: "Scratchpad", statusWord: "Paused") == "Scratchpad, Paused")
}

@Test func versionLabelOmitsRedundantBuild() {
    #expect(VersionLabel.format(version: "1.2.3", build: "45") == "1.2.3 (45)")
    #expect(VersionLabel.format(version: "1.2.3", build: "1.2.3") == "1.2.3")
    #expect(VersionLabel.format(version: "1.2.3", build: "") == "1.2.3")
    #expect(VersionLabel.format(version: "1.2.3", build: nil) == "1.2.3")
    #expect(VersionLabel.format(version: nil, build: nil) == "unknown")
}

@Test func panelIsThreeHundredFortyPointsWide() {
    #expect(MenubarMetrics.panelWidth == 340)
    #expect(MenubarMetrics.trayIconSize == TrayIconLoader.logicalSize.width)
}

@Test func refreshSpinnerTurnsOncePerSecond() {
    let base = Date(timeIntervalSinceReferenceDate: 1000)
    #expect(RefreshButton.angle(at: base) == 0)
    #expect(abs(RefreshButton.angle(at: base.addingTimeInterval(0.25)) - 90) < 0.001)
}
