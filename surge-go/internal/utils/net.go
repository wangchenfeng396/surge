package utils

import (
	"log"
	"net"
	"strings"
)

// IPv6Enabled controls whether IPv6 connections are allowed
var IPv6Enabled = true // Default to true

// ResolveNetwork returns the appropriate network type ("tcp", "tcp4", "tcp6")
// based on the configuration and the input network type
func ResolveNetwork(network string) string {
	if !IPv6Enabled {
		if strings.HasSuffix(network, "6") {
			// If explicitly requesting IPv6 but it's disabled, fallback to IPv4
			// or keep it and let it fail? Surge likely prefers fail or fallback.
			// Ideally, "tcp" becomes "tcp4".
			return strings.Replace(network, "6", "4", 1)
		}
		if !strings.HasSuffix(network, "4") {
			return network + "4"
		}
	}
	return network
}

// IsIPv6 checks if the address is an IPv6 address
func IsIPv6(address string) bool {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		host = address // assume address is just host
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return false // Domain or invalid
	}
	return ip.To4() == nil
}

// SetIPv6Enabled sets the global IPv6 enabled state
func SetIPv6Enabled(enabled bool) {
	IPv6Enabled = enabled
	log.Printf("IPv6 support set to: %v", enabled)
}
