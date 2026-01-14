package policy

import (
	"context"
	"net"
	"testing"
)

// Mock implementation of Group for testing
type mockGroup struct {
	BaseGroup
}

func newMockGroup(name string, children []string) Group {
	return &mockGroup{
		BaseGroup: BaseGroup{
			NameStr:     name,
			ProxiesList: children,
		},
	}
}

func (m *mockGroup) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	return nil, nil // No-op
}

func (m *mockGroup) Now() string {
	if len(m.ProxiesList) > 0 {
		return m.ProxiesList[0]
	}
	return ""
}

func TestValidateCycles_NoCycle(t *testing.T) {
	groups := map[string]Group{
		"A": newMockGroup("A", []string{"B", "Proxy1"}),
		"B": newMockGroup("B", []string{"C", "Proxy2"}),
		"C": newMockGroup("C", []string{"Proxy3"}),
	}

	if err := ValidateCycles(groups); err != nil {
		t.Errorf("Unexpected error for valid graph: %v", err)
	}
}

func TestValidateCycles_SelfCycle(t *testing.T) {
	groups := map[string]Group{
		"A": newMockGroup("A", []string{"A"}),
	}

	err := ValidateCycles(groups)
	if err == nil {
		t.Error("Expected error for self cycle, got nil")
	} else if err.Error() != "cycle detected: A -> A" {
		t.Errorf("Unexpected error message: %v", err)
	}
}

func TestValidateCycles_SimpleCycle(t *testing.T) {
	groups := map[string]Group{
		"A": newMockGroup("A", []string{"B"}),
		"B": newMockGroup("B", []string{"A"}),
	}

	err := ValidateCycles(groups)
	if err == nil {
		t.Error("Expected error for simple cycle, got nil")
	}
	// Error could be A->B->A or B->A->B depending on map iteration order if not sorted.
	// We sorted keys, so A starts first. A->B->A
}

func TestValidateCycles_ComplexCycle(t *testing.T) {
	groups := map[string]Group{
		"A": newMockGroup("A", []string{"B", "C"}),
		"B": newMockGroup("B", []string{"D"}),
		"C": newMockGroup("C", []string{"E"}),
		"D": newMockGroup("D", []string{"A"}), // Cycle back to A
		"E": newMockGroup("E", []string{}),
	}

	err := ValidateCycles(groups)
	if err == nil {
		t.Error("Expected error for complex cycle, got nil")
	}
}

func TestValidateCycles_RealGroups(t *testing.T) {
	// Verify that real group implementations work with the validator
	// Note: We don't need a real resolver for this test as we only check Proxies() list

	selectG := NewSelectGroup("Select", []string{"Auto", "Dead"}, nil, "")
	urlTestG := NewURLTestGroup("Auto", []string{"Proxy1", "Proxy2"}, nil, "http://test.com", 300, 50)

	// Valid case
	groups := map[string]Group{
		"Select": selectG,
		"Auto":   urlTestG,
	}

	if err := ValidateCycles(groups); err != nil {
		t.Errorf("Unexpected error for valid real groups: %v", err)
	}

	// Cycle case: Auto -> Select -> Auto
	// We need to modify Auto to point to Select.
	// Since groups are usually immutable in structure, we create new ones for the cycle test.

	cycleG1 := NewSelectGroup("G1", []string{"G2"}, nil, "")
	cycleG2 := NewSelectGroup("G2", []string{"G1"}, nil, "") // Cycle

	badGroups := map[string]Group{
		"G1": cycleG1,
		"G2": cycleG2,
	}

	if err := ValidateCycles(badGroups); err == nil {
		t.Error("Expected error for real group cycle, got nil")
	}
}
