import AppKit
import SwiftUI
import Testing
import UserNotifications

@testable import MenubarKit

/// Hosts `view` in an offscreen window, lays it out and draws it once, so
/// every `body` and button style it contains is evaluated.
@MainActor
private func render(_ view: some View, appearance: NSAppearance.Name = .aqua) -> NSSize {
    let host = NSHostingView(rootView: view.frame(width: MenubarMetrics.panelWidth))
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: MenubarMetrics.panelWidth, height: 600),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: appearance)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let size = host.fittingSize
    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
        host.cacheDisplay(in: host.bounds, to: rep)
    }
    window.contentView = nil
    return size
}

private struct QuietCenter: NotificationCenterClient {
    func requestAuthorization() async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func add(_ notification: MenubarNotification, playSound: Bool) async throws {}
}

@MainActor
@Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
func panelComponentsRender(appearance: NSAppearance.Name) {
    let status = MenubarStatus(tone: .warning, headline: "1 check failing", detail: "pr-nanny#42")
    let rows = StatusTone.allCases.map { MenubarStatusRow(title: $0.rawValue, value: $0.defaultWord, tone: $0) }
    let panel = MenubarPanel {
        StatusHeader(status, detailOverride: "Refreshing…") {
            RefreshButton(isRefreshing: true) {}
        }
        StatusHeader(tone: .ok, headline: "All clear", detail: "")
        StatusHeader(tone: .error, headline: InlineCode.attributed("Run `task check`"), detail: AttributedString("x"))
        StatusHeader(status)
        RefreshButton(isRefreshing: false) {}
        ForEach(StatusTone.allCases, id: \.self) { StatusIcon(tone: $0) }
        StatusRowsTile(rows)
        TileHeader("Pull requests", linkTitle: "Open all") {}
        TileHeader("Plain")
        Text("Grouped").groupedTile()
        PanelNotice("Helper stopped")
        PanelNotice(InlineCode.attributed("Run `gh auth login`"), symbol: "key")
        PrimaryActionButton("Sign in") {}
        Button("Prominent") {}.buttonStyle(ProminentButtonStyle(fullWidth: true))
        Button("Compact") {}.buttonStyle(ProminentButtonStyle())
        Button("Icon") {}.buttonStyle(HeaderIconButtonStyle())
        MenuSection(quitTitle: "Quit", quitHelp: "Quit the app") {
            Button("Settings") {}.buttonStyle(MenuRowButtonStyle())
            OpenSettingsButton()
        }
        MenuSection {
            Text("No quit row")
        }
        VersionFooter(version: "2026.11.05.2", build: "7")
        VersionFooter(version: nil, build: nil)
        VersionFooter()
    }
    .menubarTheme(.amber)
    #expect(render(panel, appearance: appearance).height > 0)
}

@MainActor
@Test func listRowsRender() {
    let rows = VStack {
        ListRowButton("api", subtitle: "https://api.test", tone: .ok, value: ":3000") {}
        ListRowButton("worker", systemImage: "gearshape", value: nil) {}
        ListRowButton("bare") {}
        Button("Styled") {}.buttonStyle(ListRowButtonStyle())
    }
    #expect(render(rows).height > 0)
}

@MainActor
@Test func settingsFormRenders() {
    let defaults = UserDefaults.standard
    let enabledKey = "menubarKitTests.render.enabled"
    let soundKey = "menubarKitTests.render.sound"
    defer {
        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: soundKey)
    }
    let notifier = MenubarNotifier(center: QuietCenter(), preferences: { NotificationPreferences() })
    for enabled in [false, true] {
        defaults.set(enabled, forKey: enabledKey)
        let form = SettingsForm {
            NotificationSettingsSection(
                notifier: notifier, toggleTitle: "Notify me", explanation: "Silent by default.",
                enabledKey: enabledKey, soundEnabledKey: soundKey)
            NotificationSettingsSection(
                notifier: notifier, toggleTitle: "No sound", offersSound: false,
                enabledKey: enabledKey, soundEnabledKey: soundKey)
            Section("Notes") {
                SettingsNote("Plain note")
                SettingsNote(InlineCode.attributed("Uses `gh`"))
            }
            SettingsAboutSection(note: "Never uploads data.", repository: URL(string: "https://github.com/alexcatdad"))
            SettingsAboutSection()
        }
        #expect(render(form).height > 0)
    }
}

@MainActor
@Test func trayLabelsRender() {
    let status = MenubarStatus(tone: .error, headline: "Down")
    let labels = HStack {
        TrayLabel(icon: nil, fallbackSymbol: "bell", tone: .ok, appName: "Demo")
        TrayLabel(icon: nil, fallbackSymbol: "bell", status: status, appName: "Demo", isDevelopment: true)
    }
    #expect(render(labels).height > 0)
}

@Test func themeMapsEveryTone() {
    let theme = MenubarTheme(accent: .blue, accentInk: .indigo)
    #expect(theme.ink == MenubarTheme.defaultInk)
    #expect(theme.color(for: .ok) == .green)
    #expect(theme.color(for: .warning) == .orange)
    #expect(theme.color(for: .error) == .red)
    #expect(theme.color(for: .off) == .secondary)
    #expect(theme.color(for: .update) == .indigo)
    var environment = EnvironmentValues()
    environment.menubarTheme = theme
    #expect(environment.menubarTheme.accent == .blue)
}
