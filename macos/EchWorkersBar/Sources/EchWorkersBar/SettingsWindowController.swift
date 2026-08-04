import AppKit
import SwiftUI

/// 设置窗口控制器:用 AppKit NSWindow + NSHostingController 承载 SwiftUI 设置视图。
/// 显式 makeKeyAndOrderFront + activate,不受 `.accessory`(无 Dock)策略影响,
/// 避免 MenuBarExtra 里 openWindow 打开独立 Scene 时窗口不激活/不显示的问题。
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(config: ConfigStore, proxy: ProxyManager) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
            .environmentObject(config)
            .environmentObject(proxy)
        let host = NSHostingController(rootView: view)

        let w = NSWindow(contentViewController: host)
        w.title = "设置"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 560, height: 460))
        w.center()
        w.setFrameAutosaveName("EchWorkersBarSettings")
        w.isReleasedWhenClosed = false
        self.window = w

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
