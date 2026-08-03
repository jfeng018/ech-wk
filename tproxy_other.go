//go:build !linux

package main

// 非 Linux 平台的 TPROXY stub：runTProxyServer 仅提示不支持。
// TPROXY 依赖 Linux 的 getsockopt(SO_ORIGINAL_DST)，Windows/macOS 无法编译 Linux 专属 syscall 常量。

import (
	"log"
	"runtime"
)

// runTProxyServer 在非 Linux 平台仅提示不支持
func runTProxyServer(addr string) {
	log.Printf("[TPROXY] 透明代理仅支持 Linux 平台，当前系统: %s", runtime.GOOS)
}
