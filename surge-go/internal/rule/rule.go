package rule

import (
	"net"
)

// RequestMetadata contains information about the request being matched
type RequestMetadata struct {
	Type        string // tcp, udp, etc.
	Host        string // Domain or IP string
	IP          net.IP // Parsed IP address (nil if domain)
	Port        int
	ProcessPath string // Process name/path (optional)
	SourceIP    net.IP // Source IP (optional)
	SourcePort  int    // Source Port (optional)
	DnsIP       net.IP // Resolved IP if Host was a domain (optional)
}

// Rule defines the interface for all routing rules
type Rule interface {
	// Match checks if the request matches the rule
	Match(metadata *RequestMetadata) bool

	// Adapter returns the policy/proxy name if matched
	Adapter() string

	// Type returns the rule type string (e.g., "DOMAIN-SUFFIX")
	Type() string

	// Payload returns the rule payload (e.g., "google.com")
	Payload() string

	// HitCount returns the number of times this rule was matched
	HitCount() int64

	// IncrementHitCount increments the usage counter
	IncrementHitCount()

	// ResetHitCount resets the usage counter
	ResetHitCount()

	// IsEnabled returns true if the rule is enabled
	IsEnabled() bool

	// SetEnabled sets the enabled state
	SetEnabled(enabled bool)

	// Comment returns the comment associated with the rule
	Comment() string

	// SetComment sets the comment
	SetComment(comment string)
}

// BaseRule provides common fields for rules
type BaseRule struct {
	RuleType    string
	AdapterName string
	RulePayload string
	NoResolve   bool
	hitCount    int64
	enabled     bool
	comment     string
}

func (r *BaseRule) Match(metadata *RequestMetadata) bool {
	return false
}

func (r *BaseRule) Adapter() string {
	return r.AdapterName
}

func (r *BaseRule) Type() string {
	return r.RuleType
}

func (r *BaseRule) Payload() string {
	return r.RulePayload
}

func (r *BaseRule) HitCount() int64 {
	return r.hitCount
}

func (r *BaseRule) IncrementHitCount() {
	r.hitCount++
}

func (r *BaseRule) ResetHitCount() {
	r.hitCount = 0
}

func (r *BaseRule) IsEnabled() bool {
	return r.enabled
}

func (r *BaseRule) SetEnabled(enabled bool) {
	r.enabled = enabled
}

func (r *BaseRule) Comment() string {
	return r.comment
}

func (r *BaseRule) SetComment(comment string) {
	r.comment = comment
}
