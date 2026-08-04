import SwiftUI
import AppKit

/// 菜单栏弹窗内容:状态 + 启停 + 服务器切换 + 最近日志 + 系统代理/开机自启 + 设置/退出。
/// 极简信息密度的原生菜单栏风格。
struct MenuBarView: View {
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var proxy: ProxyManager
    @State private var systemProxyOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 状态区
            HStack(spacing: 6) {
                Circle()
                    .fill(proxy.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(proxy.isRunning ? "运行中" : "已停止")
                    .font(.headline)
                Spacer()
                Text(config.currentServer?.name ?? "未配置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 启停
            Button(proxy.isRunning ? "停止代理" : "启动代理") {
                if proxy.isRunning {
                    proxy.stop()
                } else if let server = config.currentServer {
                    proxy.start(server: server)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            // 服务器切换
            Picker("服务器", selection: serverBinding) {
                ForEach(config.servers) { s in
                    Text(s.name.isEmpty ? "未命名" : s.name).tag(s.id)
                }
            }
            .pickerStyle(.menu)

            // 最近日志
            if !proxy.logLines.isEmpty {
                Divider()
                HStack {
                    Text("最近日志")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        copyLog()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("复制全部日志")
                    Button {
                        proxy.clearLog()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("清空日志")
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(proxy.logLines.suffix(80).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Divider()

            // 系统代理
            HStack {
                Text("系统代理")
                    .font(.callout)
                Spacer()
                Button(systemProxyOn ? "关闭系统代理" : "设置系统代理") {
                    toggleSystemProxy()
                }
            }

            // 开机自启
            Toggle("开机自启", isOn: autostartBinding)
                .font(.callout)

            Divider()

            Button("设置…") {
                SettingsWindowController.shared.show(config: config, proxy: proxy)
            }
            Button("退出 ECH Workers") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    private var serverBinding: Binding<String> {
        Binding(
            get: { config.current_server_id },
            set: { newID in
                config.current_server_id = newID
                config.save()
            }
        )
    }

    private var autostartBinding: Binding<Bool> {
        Binding(
            get: { AutoStart.isEnabled },
            set: { newValue in
                AutoStart.setEnabled(newValue)
                proxy.log(newValue ? "[系统] 已开启开机自启" : "[系统] 已关闭开机自启")
            }
        )
    }

    private func toggleSystemProxy() {
        guard let port = config.listenPort else {
            proxy.log("[系统] 监听地址无效,无法设置系统代理")
            return
        }
        if systemProxyOn {
            SystemProxy.setSocks(on: false, port: port)
            systemProxyOn = false
            proxy.log("[系统] 已关闭系统代理")
        } else {
            SystemProxy.setSocks(on: true, port: port)
            systemProxyOn = true
            proxy.log("[系统] 已设置系统代理 (SOCKS 127.0.0.1:\(port))")
            if let server = config.currentServer, !server.username.isEmpty {
                proxy.log("[系统] 提示: 已启用代理认证,系统代理无法自动携带用户名/密码")
            }
        }
    }

    private func copyLog() {
        let text = proxy.logLines.joined(separator: "\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
