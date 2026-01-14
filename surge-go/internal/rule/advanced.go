package rule

import (
	"fmt"
	"strconv"
	"strings"
)

// ProtocolRule matches traffic protocol (TCP/UDP)
type ProtocolRule struct {
	BaseRule
	Protocol string
}

func NewProtocolRule(protocol, adapter string, noResolve bool) *ProtocolRule {
	return &ProtocolRule{
		BaseRule: BaseRule{
			RuleType:    "PROTOCOL",
			RulePayload: strings.ToLower(protocol),
			AdapterName: adapter,
			NoResolve:   noResolve,
		},
		Protocol: strings.ToLower(protocol),
	}
}

func (r *ProtocolRule) Match(metadata *RequestMetadata) bool {
	// metadata.Type usually contains "tcp", "udp", "tcp4", "udp6" etc.
	// We matched simple prefix
	if r.Protocol == "tcp" {
		return strings.HasPrefix(metadata.Type, "tcp")
	}
	if r.Protocol == "udp" {
		return strings.HasPrefix(metadata.Type, "udp")
	}
	return strings.EqualFold(metadata.Type, r.Protocol)
}

// DestPortRule matches destination port
type DestPortRule struct {
	BaseRule
	Port int
}

func NewDestPortRule(portStr, adapter string, noResolve bool) (*DestPortRule, error) {
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("invalid port: %s", portStr)
	}
	return &DestPortRule{
		BaseRule: BaseRule{
			RuleType:    "DEST-PORT",
			RulePayload: portStr,
			AdapterName: adapter,
			NoResolve:   noResolve,
		},
		Port: port,
	}, nil
}

func (r *DestPortRule) Match(metadata *RequestMetadata) bool {
	return metadata.Port == r.Port
}

// AndRule matches if all sub-rules match
type AndRule struct {
	BaseRule
	Rules []Rule
}

func NewAndRule(rules []Rule, adapter string, noResolve bool) *AndRule {
	return &AndRule{
		BaseRule: BaseRule{
			RuleType:    "AND",
			RulePayload: "...", // Complex payload representation
			AdapterName: adapter,
			NoResolve:   noResolve,
		},
		Rules: rules,
	}
}

func (r *AndRule) Match(metadata *RequestMetadata) bool {
	for _, rule := range r.Rules {
		if !rule.Match(metadata) {
			return false
		}
	}
	return true
}
