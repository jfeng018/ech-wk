import SwiftUI
import AppKit

/// 菜单栏应用入口 —— 无 Dock 图标、动态菜单栏图标、极简原生 UI。
@main
struct EchWorkersBarApp: App {
    @StateObject private var config = ConfigStore()
    @StateObject private var proxy = ProxyManager()

    init() {
        // 菜单栏应用:隐藏 Dock 图标
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        // 菜单栏图标:运行中绿点 / 已停止灰点
        MenuBarExtra {
            MenuBarView()
                .environmentObject(config)
                .environmentObject(proxy)
                .frame(width: 320)
        } label: {
            Image(systemName: proxy.isRunning ? "circle.fill" : "circle")
                .foregroundStyle(proxy.isRunning ? Color.green : Color.gray)
        }
        .menuBarExtraStyle(.window)

        // 设置窗口
        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(config)
                .environmentObject(proxy)
        }
        .windowResizability(.contentSize)
    }
}
