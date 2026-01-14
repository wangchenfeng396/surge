package rule

import (
	"strings"
)

// DomainRule matches exact domain
type DomainRule struct {
	BaseRule
}

func NewDomainRule(domain, adapter string) *DomainRule {
	return &DomainRule{
		BaseRule: BaseRule{
			RuleType:    "DOMAIN",
			RulePayload: strings.ToLower(domain),
			AdapterName: adapter,
		},
	}
}

func (r *DomainRule) Match(metadata *RequestMetadata) bool {
	if metadata.Host == "" {
		return false
	}
	return strings.EqualFold(metadata.Host, r.RulePayload)
}

// DomainSuffixRule matches domain suffix
type DomainSuffixRule struct {
	BaseRule
}

func NewDomainSuffixRule(suffix, adapter string) *DomainSuffixRule {
	// Ensure suffix starts with dot implies consistency, but usually configs don't have it.
	// "google.com" matches "www.google.com" and "google.com"
	return &DomainSuffixRule{
		BaseRule: BaseRule{
			RuleType:    "DOMAIN-SUFFIX",
			RulePayload: strings.ToLower(suffix),
			AdapterName: adapter,
		},
	}
}

func (r *DomainSuffixRule) Match(metadata *RequestMetadata) bool {
	if metadata.Host == "" {
		return false
	}
	host := strings.ToLower(metadata.Host)
	suffix := r.RulePayload

	if host == suffix {
		return true
	}
	if strings.HasSuffix(host, suffix) {
		// Ensure it's a dot boundary or exact match
		// e.g. suffix "google.com" matches "mail.google.com"
		// but should NOT match "agoogle.com"
		if len(host) > len(suffix) && host[len(host)-len(suffix)-1] == '.' {
			return true
		}
	}
	return false
}

// DomainKeywordRule matches domain keyword
type DomainKeywordRule struct {
	BaseRule
}

func NewDomainKeywordRule(keyword, adapter string) *DomainKeywordRule {
	return &DomainKeywordRule{
		BaseRule: BaseRule{
			RuleType:    "DOMAIN-KEYWORD",
			RulePayload: strings.ToLower(keyword),
			AdapterName: adapter,
		},
	}
}

func (r *DomainKeywordRule) Match(metadata *RequestMetadata) bool {
	if metadata.Host == "" {
		return false
	}
	return strings.Contains(strings.ToLower(metadata.Host), r.RulePayload)
}
