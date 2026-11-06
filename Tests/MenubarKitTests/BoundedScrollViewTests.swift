import AppKit
import SwiftUI
import Testing

@testable import MenubarKit

/// Lays `view` out in a hosting controller and returns its size when the
/// window proposes no height at all, as `MenuBarExtra` can.
@MainActor
private func minimalSize(of view: some View) -> CGSize {
    let controller = NSHostingController(rootView: view)
    controller.view.frame = NSRect(x: 0, y: 0, width: MenubarMetrics.panelWidth, height: 800)
    controller.view.layoutSubtreeIfNeeded()
    return controller.sizeThatFits(in: CGSize(width: MenubarMetrics.panelWidth, height: 0))
}

@MainActor
private func panel(rows: Int, maxHeight: CGFloat) -> some View {
    MenubarPanel {
        BoundedScrollView(maxHeight: maxHeight) {
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { index in
                    Text("Row \(index)").frame(height: 40)
                }
            }
        }
    }
}

@Test func heightIsCappedAndNeverZero() {
    #expect(BoundedScrollView<EmptyView>.height(content: 0, maxHeight: 280) == 280)
    #expect(BoundedScrollView<EmptyView>.height(content: 120, maxHeight: 280) == 120)
    #expect(BoundedScrollView<EmptyView>.height(content: 900, maxHeight: 280) == 280)
}

@MainActor
@Test func longListKeepsItsHeightWhenTheWindowProposesNone() {
    // 30 rows of 40pt overflow the 280pt cap; panel padding adds 24pt.
    #expect(minimalSize(of: panel(rows: 30, maxHeight: 280)).height >= 280 + 24)
}

@MainActor
@Test func shortListIsAsTallAsItsRows() {
    let height = minimalSize(of: panel(rows: 2, maxHeight: 280)).height
    #expect(height >= 2 * 40 + 24)
    #expect(height < 280)
}
