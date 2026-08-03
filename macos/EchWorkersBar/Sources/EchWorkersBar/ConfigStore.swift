import Foundation

/// 配置存储:读写 ~/Library/Application Support/ECHWorkersClient/config.json
/// —— 与 gui.py 使用同一路径与格式,两个 App 配置互通。
final class ConfigStore: ObservableObject {
    @Published var servers: [ServerConfig] = []
    @Published var current_server_id: String = ""

    static var configDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ECHWorkersClient", isDirectory: true)
    }
    static var configFile: URL {
        configDir.appendingPathComponent("config.json")
    }

    /// 当前选中服务器;无则回退到第一个。
    var currentServer: ServerConfig? {
        servers.first { $0.id == current_server_id } ?? servers.first
    }

    init() {
        load()
    }

    func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.configFile.path) else {
            // 首次运行:写一个默认服务器(镜像 gui.py add_default_server)
            servers = [ServerConfig(server: "example.com:443", ip: "saas.sin.fan")]
            current_server_id = servers[0].id
            save()
            return
        }
        do {
            let data = try Data(contentsOf: Self.configFile)
            let file = try JSONDecoder().decode(ConfigFile.self, from: data)
            servers = file.servers
            current_server_id = file.current_server_id
        } catch {
            // 解析失败则回退到空服务器并落盘一份干净配置
            servers = []
            current_server_id = ""
        }
        if servers.isEmpty {
            servers = [defaultServer()]
            current_server_id = servers[0].id
            save()
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: Self.configDir, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try enc.encode(ConfigFile(servers: servers, currentServerID: current_server_id))
            try data.write(to: Self.configFile, options: .atomic)
        } catch {
            NSLog("配置保存失败: \(error)")
        }
    }

    func defaultServer() -> ServerConfig {
        ServerConfig(server: "example.com:8443", ip: "saas.sin.fan")
    }

    // MARK: CRUD
    func addServer() {
        let s = defaultServer()
        servers.append(s)
        current_server_id = s.id
        save()
    }
    func deleteServer(_ id: String) {
        guard servers.count > 1 else { return }   // 至少保留一个
        servers.removeAll { $0.id == id }
        if current_server_id == id {
            current_server_id = servers.first?.id ?? ""
        }
        save()
    }
    func update(_ s: ServerConfig) {
        if let i = servers.firstIndex(where: { $0.id == s.id }) {
            servers[i] = s
        }
        save()
    }
}