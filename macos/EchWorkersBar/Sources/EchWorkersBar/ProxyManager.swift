import Foundation
import AppKit

/// 代理进程管理:拉起 ech-workers 二进制,捕获 stdout/stderr 作为日志流。
final class ProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var logLines: [String] = []

    private var process: Process?
    private let maxLogLines = 500

    // MARK: 启停
    func start(server: ServerConfig) {
        stop()

        guard let bin = findBinary() else {
            appendLog("错误: 找不到 ech-workers 可执行文件")
            appendLog("请将其放在 App 同目录、资源目录或系统 PATH 中")
            return
        }

        let args = buildArguments(for: server)
        if server.server.isEmpty {
            appendLog("错误: 服务器地址为空,请在设置中填写")
            return
        }

        let p = Process()
        p.executableURL = bin
        p.arguments = args

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.appendLog("[进程] ech-workers 已退出")
            }
        }

        do {
            try p.run()
        } catch {
            appendLog("启动失败: \(error.localizedDescription)")
            return
        }

        process = p
        isRunning = true

        let fh = pipe.fileHandleForReading
        fh.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        appendLog("[进程] 已启动 (\(server.server)) 监听 \(server.listen)")
    }

    func stop() {
        guard let p = process else { return }
        p.terminate()
        process = nil
        isRunning = false
    }

    /// 退出应用时调用
    func shutdown() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func clearLog() {
        logLines.removeAll()
    }

    // MARK: 参数组装 (与 gui.py ProcessThread.run 一致,仅非空/非默认传)
    private func buildArguments(for server: ServerConfig) -> [String] {
        var args: [String] = []
        func add(_ flag: String, _ value: String) {
            args += [flag, value]
        }
        add("-f", server.server)
        if !server.listen.isEmpty { add("-l", server.listen) }
        if !server.token.isEmpty { add("-token", server.token) }
        if !server.ip.isEmpty { add("-ip", server.ip) }
        if !server.dns.isEmpty && server.dns != "dns.alidns.com/dns-query" { add("-dns", server.dns) }
        if !server.ech.isEmpty && server.ech != "cloudflare-ech.com" { add("-ech", server.ech) }
        if !server.username.isEmpty { add("-username", server.username) }
        if !server.password.isEmpty { add("-password", server.password) }
        if !server.routing_mode.isEmpty { add("-routing", server.routing_mode) }
        return args
    }

    // MARK: 二进制发现 (与 gui.py _find_executable 一致)
    private func findBinary() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("ech-workers"))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("ech-workers"))
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("ech-workers"))

        for u in candidates where fm.isExecutableFile(atPath: u.path) {
            return u
        }
        // PATH 搜索
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let u = URL(fileURLWithPath: String(dir)).appendingPathComponent("ech-workers")
                if fm.isExecutableFile(atPath: u.path) { return u }
            }
        }
        return nil
    }

    // MARK: 日志
    private func appendLog(_ text: String) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            logLines.append(String(line))
        }
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
    }
}
