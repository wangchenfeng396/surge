package rule

import (
	"path/filepath"
	"strings"
)

// ProcessNameRule matches requests based on the process name (executable name)
type ProcessNameRule struct {
	BaseRule
	ExpectedName string
}

// NewProcessNameRule creates a new PROCESS-NAME rule
func NewProcessNameRule(payload string, adapter string, noResolve bool) *ProcessNameRule {
	return &ProcessNameRule{
		BaseRule: BaseRule{
			RuleType:    "PROCESS-NAME",
			AdapterName: adapter,
			RulePayload: payload,
			NoResolve:   noResolve,
		},
		ExpectedName: strings.ToLower(strings.TrimSpace(payload)),
	}
}

// Match checks if the request's process path matches the rule
func (r *ProcessNameRule) Match(metadata *RequestMetadata) bool {
	if metadata.ProcessPath == "" {
		return false
	}

	// If the rule expects a path (contains separator), match full path
	if strings.Contains(r.ExpectedName, "/") || strings.Contains(r.ExpectedName, "\\") {
		return strings.EqualFold(metadata.ProcessPath, r.ExpectedName)
	}

	// Otherwise match base name
	processName := filepath.Base(metadata.ProcessPath)
	return strings.EqualFold(processName, r.ExpectedName)
}
