import SwiftUI

/// 设置窗口:服务器列表 + 编辑表单(字段与 gui.py 一致)。
struct SettingsView: View {
    @EnvironmentObject var config: ConfigStore
    @State private var selectedID: String?

    var body: some View {
        HSplitView {
            // 左侧:服务器列表
            List(config.servers, selection: $selectedID) { s in
                Text(s.name.isEmpty ? "未命名" : s.name)
                    .tag(s.id)
            }
            .frame(minWidth: 170)
            .onAppear {
                if selectedID == nil {
                    selectedID = config.current_server_id.isEmpty
                        ? config.servers.first?.id
                        : config.current_server_id
                }
            }

            // 右侧:编辑表单
            Group {
                if let server = config.servers.first(where: { $0.id == selectedID }) {
                    EditorView(server: binding(for: server))
                } else {
                    VStack(spacing: 8) {
                        Text("选择一个服务器,或点 + 新建")
                            .foregroundStyle(.secondary)
                        if config.servers.isEmpty {
                            Button("新建服务器") { config.addServer() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    config.addServer()
                    selectedID = config.servers.last?.id
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .help("新增服务器")

                Button {
                    if let id = selectedID { config.deleteServer(id) }
                } label: {
                    Label("删除", systemImage: "minus")
                }
                .help("删除选中服务器")
                .disabled(config.servers.count <= 1)
            }
        }
    }

    private func binding(for server: ServerConfig) -> Binding<ServerConfig> {
        Binding(
            get: { config.servers.first { $0.id == server.id } ?? server },
            set: { newValue in
                config.update(newValue)
                if selectedID == nil { selectedID = newValue.id }
            }
        )
    }
}

/// 单服务器编辑表单
struct EditorView: View {
    @Binding var server: ServerConfig

    var body: some View {
        Form {
            Section("基本设置") {
                TextField("名称", text: $server.name)
                TextField("服务器地址", text: $server.server, prompt: Text("your-worker.workers.dev:443"))
                TextField("监听地址", text: $server.listen, prompt: Text("127.0.0.1:30000"))
            }
            Section("认证与令牌") {
                TextField("身份令牌", text: $server.token)
                TextField("代理认证用户名", text: $server.username, prompt: Text("可选"))
                SecureField("代理认证密码", text: $server.password)
            }
            Section("高级") {
                TextField("优选 IP/域名", text: $server.ip)
                TextField("DoH 服务器", text: $server.dns)
                TextField("ECH 域名", text: $server.ech)
                Picker("分流模式", selection: $server.routing_mode) {
                    Text("全局代理").tag("global")
                    Text("跳过中国大陆").tag("bypass_cn")
                    Text("直连模式").tag("none")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
