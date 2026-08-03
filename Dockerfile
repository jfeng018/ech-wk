# ECH Workers 客户端 - 多架构 Docker 镜像 (amd64 / arm64)
# 构建阶段:编译 Go 核心 ech-workers.go (含 tproxy_linux.go / tproxy_other.go)
FROM golang:1.23-alpine AS builder
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY *.go ./
# 仓库无 go.mod,按需初始化并拉取唯一依赖 gorilla/websocket
RUN go mod init ech-workers && \
    go get github.com/gorilla/websocket@v1.5.3 && \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /ech-workers .

# 运行阶段:最小化 alpine,仅含二进制 + CA 证书
FROM alpine:3.20
RUN apk add --no-cache ca-certificates && rm -rf /var/cache/apk/*
COPY --from=builder /ech-workers /usr/bin/ech-workers
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
WORKDIR /app

# 环境变量约定与 README「Docker部署」一致 (ARG_* → -f/-l/-token/-ip/-ech/-routing 等)
ENV ARG_F="" \
    ARG_L="0.0.0.0:30000" \
    ARG_TOKEN="" \
    ARG_USERNAME="" \
    ARG_PASSWORD="" \
    ARG_IP="" \
    ARG_DNS="dns.alidns.com/dns-query" \
    ARG_ECH="cloudflare-ech.com" \
    ARG_ROUTING="global" \
    ARG_TPROXY=""

ENTRYPOINT ["/entrypoint.sh"]
