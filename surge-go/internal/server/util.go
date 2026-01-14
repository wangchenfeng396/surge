package server

import (
	"fmt"
)

// ResolveListenAddr returns the listen address based on config parameters
func ResolveListenAddr(port int, allowWifiAccess bool, ipv6 bool) string {
	host := "127.0.0.1"
	if allowWifiAccess {
		host = "0.0.0.0"
		if ipv6 {
			// If we want dual stack listener, usually [::] works for both if configured correctly,
			// but Go's net.Listen("tcp", ":port") handles both by default on dual stack systems.
			// "0.0.0.0" forces IPv4.
			// "[::]" implies IPv6 and possibly IPv4 (depending on OS config).
			// For safety and explicit behavior matching Surge:
			// "allow-wifi-access=true" -> usually means binding to INADDR_ANY.
			host = "" // Empty host means all interfaces in Go net.Listen
		}
	} else {
		// Localhost only
		if ipv6 {
			// Keeping it simple, listen on both localhost ipv4 and ipv6 is tricky with one listener unless using "localhost" which resolves to one.
			// Usually we want to bind specifically.
			// Let's stick to 127.0.0.1 for local only unless IPv6 is strictly required for local.
			host = "127.0.0.1"
		}
	}

	return fmt.Sprintf("%s:%d", host, port)
}
