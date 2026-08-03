import Foundation

/// 服务器配置 —— 与 gui.py 的 config.json 结构完全一致,保证两 App 配置互通。
/// 字段名用 snake_case 直接对应 JSON 键,无需 CodingKeys。
struct ServerConfig: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var server: String
    var listen: String
    var token: String
    var ip: String
    var dns: String
    var ech: String
    var routing_mode: String
    var username: String
    var password: String

    init(id: String = UUID().uuidString,
         name: String = "默认服务器",
         server: String = "",
         listen: String = "127.0.0.1:30000",
         token: String = "",
         ip: String = "",
         dns: String = "dns.alidns.com/dns-query",
         ech: String = "cloudflare-ech.com",
         routing_mode: String = "bypass_cn",
         username: String = "",
         password: String = "") {
        self.id = id
        self.name = name
        self.server = server
        self.listen = listen
        self.token = token
        self.ip = ip
        self.dns = dns
        self.ech = ech
        self.routing_mode = routing_mode
        self.username = username
        self.password = password
    }

    /// 兼容旧配置:某些字段可能缺失,缺失时给默认值而非解码失败。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "默认服务器"
        server = try c.decodeIfPresent(String.self, forKey: .server) ?? ""
        listen = try c.decodeIfPresent(String.self, forKey: .listen) ?? "127.0.0.1:30000"
        token = try c.decodeIfPresent(String.self, forKey: .token) ?? ""
        ip = try c.decodeIfPresent(String.self, forKey: .ip) ?? ""
        dns = try c.decodeIfPresent(String.self, forKey: .dns) ?? "dns.alidns.com/dns-query"
        ech = try c.decodeIfPresent(String.self, forKey: .ech) ?? "cloudflare-ech.com"
        routing_mode = try c.decodeIfPresent(String.self, forKey: .routing_mode) ?? "bypass_cn"
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
    }
}

/// config.json 顶层结构,与 gui.py 保存的一致:
/// {"servers": [...], "current_server_id": "..."}
struct ConfigFile: Codable {
    var servers: [ServerConfig]
    var current_server_id: String

    init(servers: [ServerConfig], currentServerID: String) {
        self.servers = servers
        self.current_server_id = currentServerID
    }
}
