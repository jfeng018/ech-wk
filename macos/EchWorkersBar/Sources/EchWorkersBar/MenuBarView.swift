import SwiftUI
import AppKit

/// 菜单栏弹窗内容:状态 + 启停 + 服务器切换 + 最近日志 + 设置/退出。
/// 极简信息密度的原生菜单栏风格。
struct MenuBarView: View {
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var proxy: ProxyManager

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
                        proxy.clearLog()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
                .frame(maxHeight: 220)
            }

            Divider()
            Button("设置…") {
                SettingsWindowController.shared.show(config: config, proxy: proxy)
            }
            Button("退出 ECH Workers") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
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
}
