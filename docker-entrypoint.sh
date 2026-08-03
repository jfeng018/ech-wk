#!/bin/sh
# ECH Workers 容器入口：将 ARG_* 环境变量组装为 ech-workers 命令行参数
# 用法与 README「Docker部署」一致，新增 ARG_USERNAME/ARG_PASSWORD/ARG_DNS/ARG_TPROXY

set -eu

if [ -z "${ARG_F:-}" ]; then
    echo "错误: 必须设置 ARG_F (服务端地址，如 your-worker.workers.dev:443)" >&2
    exit 1
fi

set --
[ -n "${ARG_F}" ] && set -- "$@" -f "$ARG_F"
[ -n "${ARG_L:-}" ] && set -- "$@" -l "$ARG_L"
[ -n "${ARG_TOKEN:-}" ] && set -- "$@" -token "$ARG_TOKEN"
[ -n "${ARG_USERNAME:-}" ] && set -- "$@" -username "$ARG_USERNAME"
[ -n "${ARG_PASSWORD:-}" ] && set -- "$@" -password "$ARG_PASSWORD"
[ -n "${ARG_IP:-}" ] && set -- "$@" -ip "$ARG_IP"
[ -n "${ARG_DNS:-}" ] && set -- "$@" -dns "$ARG_DNS"
[ -n "${ARG_ECH:-}" ] && set -- "$@" -ech "$ARG_ECH"
[ -n "${ARG_ROUTING:-}" ] && set -- "$@" -routing "$ARG_ROUTING"
[ -n "${ARG_TPROXY:-}" ] && set -- "$@" -tproxy "$ARG_TPROXY"

exec /usr/bin/ech-workers "$@"
