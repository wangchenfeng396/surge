package config

import (
	"fmt"
	"strings"
)

func splitList(s string) []string {
	parts := strings.Split(s, ",")
	var res []string
	for _, p := range parts {
		res = append(res, strings.TrimSpace(p))
	}
	return res
}

func splitConfig(s string) []string {
	var parts []string
	var current strings.Builder
	inQuotes := false
	parenCount := 0

	for _, r := range s {
		switch r {
		case '"':
			inQuotes = !inQuotes
			current.WriteRune(r)
		case '(':
			parenCount++
			current.WriteRune(r)
		case ')':
			parenCount--
			current.WriteRune(r)
		case ',':
			if !inQuotes && parenCount == 0 {
				parts = append(parts, strings.TrimSpace(current.String()))
				current.Reset()
				continue
			}
			current.WriteRune(r)
		default:
			current.WriteRune(r)
		}
	}
	if current.Len() > 0 {
		parts = append(parts, strings.TrimSpace(current.String()))
	}
	return parts
}

func mustInt(s string) int {
	var i int
	fmt.Sscanf(s, "%d", &i)
	return i
}
