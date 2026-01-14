package rule

import (
	"fmt"
	"net"
)

// IPCIDRRule matches IP against CIDR range
type IPCIDRRule struct {
	BaseRule
	ipNet *net.IPNet
}

func NewIPCIDRRule(cidr, adapter string, noResolve bool) (*IPCIDRRule, error) {
	_, ipNet, err := net.ParseCIDR(cidr)
	if err != nil {
		// Try parsing as single IP
		ip := net.ParseIP(cidr)
		if ip != nil {
			// Convert single IP to CIDR /32 or /128
			bits := 32
			if ip.To4() == nil {
				bits = 128
			}
			_, ipNet, _ = net.ParseCIDR(fmt.Sprintf("%s/%d", ip.String(), bits))
		} else {
			return nil, err
		}
	}

	return &IPCIDRRule{
		BaseRule: BaseRule{
			RuleType:    "IP-CIDR",
			RulePayload: cidr,
			AdapterName: adapter,
			NoResolve:   noResolve,
		},
		ipNet: ipNet,
	}, nil
}

func (r *IPCIDRRule) Match(metadata *RequestMetadata) bool {
	// If metadata has IP, check it
	if metadata.IP != nil {
		return r.ipNet.Contains(metadata.IP)
	}

	// If metadata has DNS resolved IP, check it
	if metadata.DnsIP != nil {
		return r.ipNet.Contains(metadata.DnsIP)
	}

	// If NoResolve is true, we don't try to resolve domain
	if r.NoResolve {
		return false
	}

	// TODO: If we have a mechanism to resolve domain on the fly, do it here?
	// Usually IP-CIDR matching happens after optional DNS resolution in the engine.
	// For now, assume metadata contains all necessary info.
	return false
}
