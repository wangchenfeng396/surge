package rule

import (
	"fmt"
	"strings"
)

// ParseRule parses a rule line into a Rule object
// Format: TYPE,PAYLOAD,ADAPTER,OPTIONS
// Example: DOMAIN-SUFFIX,google.com,Proxy,no-resolve
func ParseRule(line string) (Rule, error) {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
		return nil, nil // Empty or comment
	}

	parts := splitRuleLine(line)
	if len(parts) < 2 {
		// FINAL might be just FINAL,Proxy
		if strings.EqualFold(parts[0], "FINAL") && len(parts) >= 2 {
			// standard case
		} else {
			return nil, fmt.Errorf("invalid rule format: %s", line)
		}
	}

	ruleType := strings.ToUpper(strings.TrimSpace(parts[0]))

	// Handle special case for FINAL
	if ruleType == "FINAL" {
		adapter := strings.TrimSpace(parts[1])
		return NewFinalRule(adapter), nil
	}

	payload := strings.TrimSpace(parts[1])
	adapter := ""
	if len(parts) > 2 {
		adapter = strings.TrimSpace(parts[2])
	}

	// Options
	noResolve := false
	if len(parts) > 3 {
		for _, opt := range parts[3:] {
			if strings.EqualFold(strings.TrimSpace(opt), "no-resolve") {
				noResolve = true
			}
		}
	}

	switch ruleType {
	case "DOMAIN":
		return NewDomainRule(payload, adapter), nil
	case "DOMAIN-SUFFIX":
		return NewDomainSuffixRule(payload, adapter), nil
	case "DOMAIN-KEYWORD":
		return NewDomainKeywordRule(payload, adapter), nil
	case "IP-CIDR", "IP-CIDR6":
		// IP-CIDR6 is often treated same as IP-CIDR in modern libs, valid for Go's ParseCIDR
		return NewIPCIDRRule(payload, adapter, noResolve)
	case "GEOIP":
		return NewGeoIPRule(payload, adapter, noResolve), nil
	case "PROCESS-NAME":
		return NewProcessNameRule(payload, adapter, noResolve), nil
	case "PROTOCOL":
		return NewProtocolRule(payload, adapter, noResolve), nil
	case "DEST-PORT":
		return NewDestPortRule(payload, adapter, noResolve)
	case "AND", "OR", "NOT":
		// AND, ((Protocol,HTTP), (Domain,example.com)), Proxy
		// First, extract the list of sub-rules enclosed in ((...))
		// The payload format is roughly: ((Type,Value),(Type,Value))
		// We need to strip outer parens if present and split by tuple

		subRulesStr := payload
		if strings.HasPrefix(subRulesStr, "((") && strings.HasSuffix(subRulesStr, "))") {
			subRulesStr = subRulesStr[1 : len(subRulesStr)-1] // Remove outer ( ) from ((...)) -> (...)
		}

		// Now we have (Type,Value),(Type,Value)
		// We need to split by comma, but respect parentheses
		var subRules []Rule
		var currentRuleStr strings.Builder
		parenCount := 0

		for _, char := range subRulesStr {
			if char == '(' {
				parenCount++
			} else if char == ')' {
				parenCount--
			}

			if char == ',' && parenCount == 0 {
				// End of a rule tuple
				rStr := currentRuleStr.String()
				rStr = strings.TrimSpace(rStr)
				if len(rStr) > 0 {
					// recursive parse: rule tuple (Type,Value) -> Type,Value,Adapter
					// We need to strip ( ) around the tuple: (Type,Value) -> Type,Value
					if strings.HasPrefix(rStr, "(") && strings.HasSuffix(rStr, ")") {
						rStr = rStr[1 : len(rStr)-1]
					}
					// Sub-rules in AND don't usually have their own adapter/policy, they inherit or are just conditions needed.
					// ParseRule expects TYPE,PAYLOAD,ADAPTER.
					// But inside AND, it's usually just TYPE,PAYLOAD.
					// We can append a dummy adapter to satisfy ParseRule, or update ParseRule to handle optional adapter.
					// Let's try appending dummy adapter if missing.
					if !strings.Contains(rStr, ",") {
						// Invalid sub-rule
						continue
					}
					// Check if it has enough parts. If only Type,Value, we add ",Dummy" to parse it.
					// But we should ignore the adapter from sub-rule result anyway.
					parts := strings.Split(rStr, ",")
					if len(parts) == 2 {
						rStr += ",DUMMY"
					}

					subRule, err := ParseRule(rStr)
					if err == nil && subRule != nil {
						subRules = append(subRules, subRule)
					}
				}
				currentRuleStr.Reset()
			} else {
				currentRuleStr.WriteRune(char)
			}
		}

		// Process the last rule
		rStr := currentRuleStr.String()
		rStr = strings.TrimSpace(rStr)
		if len(rStr) > 0 {
			if strings.HasPrefix(rStr, "(") && strings.HasSuffix(rStr, ")") {
				rStr = rStr[1 : len(rStr)-1]
			}
			parts := strings.Split(rStr, ",")
			if len(parts) == 2 {
				rStr += ",DUMMY"
			}
			subRule, err := ParseRule(rStr)
			if err == nil && subRule != nil {
				subRules = append(subRules, subRule)
			}
		}

		if ruleType == "AND" {
			return NewAndRule(subRules, adapter, noResolve), nil
		}
		return nil, fmt.Errorf("OR/NOT rules matching not implemented fully yet")
	case "RULE-SET":
		// RULE-SET,url,Proxy
		// This needs special handling: it should return a RuleSetRule (which we haven't defined yet)
		// Or maybe we treat it as a factory that returns a placeholder?
		// We need to define NewRuleSetRule first.
		return NewRuleSetRule(payload, adapter, nil)
	default:
		return nil, fmt.Errorf("unknown rule type: %s", ruleType)
	}
}

// CreateRuleFromConfig creates a Rule from parsed config
func CreateRuleFromConfig(ruleType, payload, adapter string, noResolve, enabled bool, comment string) (Rule, error) {
	var r Rule
	var err error

	ruleType = strings.ToUpper(strings.TrimSpace(ruleType))

	switch ruleType {
	case "FINAL":
		r = NewFinalRule(adapter)
	case "DOMAIN":
		r = NewDomainRule(payload, adapter)
	case "DOMAIN-SUFFIX":
		r = NewDomainSuffixRule(payload, adapter)
	case "DOMAIN-KEYWORD":
		r = NewDomainKeywordRule(payload, adapter)
	case "IP-CIDR", "IP-CIDR6":
		r, err = NewIPCIDRRule(payload, adapter, noResolve)
	case "GEOIP":
		r = NewGeoIPRule(payload, adapter, noResolve)
	case "PROCESS-NAME":
		r = NewProcessNameRule(payload, adapter, noResolve)
	case "PROTOCOL":
		r = NewProtocolRule(payload, adapter, noResolve)
	case "DEST-PORT":
		r, err = NewDestPortRule(payload, adapter, noResolve)
	case "AND", "OR", "NOT":
		// For complex logic rules, payload parsing is complex.
		// For now we assume payload is the full string like ((...))
		// We can reuse ParseRule for now or reimplement logic.
		// Reusing ParseRule is safer for complex logic but we need to inject enabled/comment after.
		// Reconstruct the line for ParseRule...
		// RuleConfig.Value for AND is ((...))
		fullLine := fmt.Sprintf("%s,%s,%s", ruleType, payload, adapter)
		r, err = ParseRule(fullLine)
	case "RULE-SET":
		r, err = NewRuleSetRule(payload, adapter, nil)
	default:
		return nil, fmt.Errorf("unknown rule type: %s", ruleType)
	}

	if err != nil {
		return nil, err
	}

	if r != nil {
		r.SetEnabled(enabled)
		r.SetComment(comment)
	}
	return r, nil
}

func splitRuleLine(line string) []string {
	var parts []string
	var current strings.Builder
	parenCount := 0

	for _, c := range line {
		if c == '(' {
			parenCount++
		} else if c == ')' {
			parenCount--
		}

		if c == ',' && parenCount == 0 {
			parts = append(parts, strings.TrimSpace(current.String()))
			current.Reset()
		} else {
			current.WriteRune(c)
		}
	}

	if current.Len() > 0 {
		parts = append(parts, strings.TrimSpace(current.String()))
	}

	return parts
}
