import Foundation
import ServiceManagement

/// 系统代理设置 (macOS networksetup SOCKS)。
/// 部分 networksetup 操作需要管理员权限,失败时会由 networksetup 报错并在日志中体现。
struct SystemProxy {
    /// 设置或关闭 SOCKS 系统代理(对所有网络服务生效)
    static func setSocks(on: Bool, host: String = "127.0.0.1", port: Int) {
        for svc in services() {
            if on {
                _ = run("/usr/sbin/networksetup", ["-setsocksfirewallproxy", svc, host, String(port)])
                _ = run("/usr/sbin/networksetup", ["-setsocksfirewallproxystate", svc, "on"])
            } else {
                _ = run("/usr/sbin/networksetup", ["-setsocksfirewallproxystate", svc, "off"])
            }
        }
    }

    /// 列出所有启用的网络服务(去掉 * 禁用的与首行标题)
    static func services() -> [String] {
        guard let out = run("/usr/sbin/networksetup", ["-listallnetworkservices"]) else { return [] }
        return out
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter {
                !$0.isEmpty &&
                !$0.hasPrefix("*") &&
                $0 != "An asterisk (*) denotes that a network service is disabled."
            }
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

/// 开机自启 (登录时启动),基于 SMAppService (macOS 13+)
enum AutoStart {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("开机自启设置失败: \(error)")
        }
    }
}
