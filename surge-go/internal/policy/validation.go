package policy

import (
	"fmt"
	"sort"
	"strings"
)

// ValidateCycles checks for circular dependencies in policy groups
// groups map key is the group name, and value is the Group interface
func ValidateCycles(groups map[string]Group) error {
	visited := make(map[string]int) // 0: unvisited, 1: visiting, 2: visited

	// We need a stable order for deterministic error messages
	var names []string
	for name := range groups {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		if visited[name] == 0 {
			if path, err := dfs(name, groups, visited); err != nil {
				return fmt.Errorf("cycle detected: %s", strings.Join(path, " -> "))
			}
		}
	}
	return nil
}

func dfs(current string, groups map[string]Group, visited map[string]int) ([]string, error) {
	visited[current] = 1 // Mark as visiting

	group, exists := groups[current]
	if !exists {
		// If it's not a group, it might be a payload proxy or direct/reject, which are leaves.
		// We treat non-existent groups as leaves (valid proxies).
		visited[current] = 2
		return nil, nil
	}

	for _, childName := range group.Proxies() {
		status := visited[childName]
		if status == 1 {
			// Found a cycle
			return []string{current, childName}, fmt.Errorf("cycle")
		}
		if status == 0 {
			if path, err := dfs(childName, groups, visited); err != nil {
				// Prepend current to path for tracing
				return append([]string{current}, path...), err
			}
		}
	}

	visited[current] = 2 // Mark as visited
	return nil, nil
}
