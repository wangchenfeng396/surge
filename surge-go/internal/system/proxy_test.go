package system

import (
	"runtime"
	"testing"
)

func TestProxyManager_EnableDisable(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("System proxy tests only run on macOS")
	}

	manager := NewProxyManager()

	// Test initial state
	if manager.IsEnabled() {
		t.Error("Expected proxy to be disabled initially")
	}

	// Note: Actuallyenabling system proxy requires admin privileges
	// and would affect the system, so we only test the state management

	// Test GetStatus
	enabled, port := manager.GetStatus()
	if enabled {
		t.Error("Expected proxy to be disabled")
	}
	if port != 0 {
		t.Error("Expected port to be 0 when disabled")
	}
}

func TestProxyManager_Concurrent(t *testing.T) {
	manager := NewProxyManager()

	// Concurrent status checks should not crash
	done := make(chan bool)
	for i := 0; i < 10; i++ {
		go func() {
			_ = manager.IsEnabled()
			_, _ = manager.GetStatus()
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}
}

func TestProxyManager_InvalidPort(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("System proxy tests only run on macOS")
	}

	manager := NewProxyManager()

	// Test with invalid ports
	testCases := []int{-1, 0, 65536, 100000}

	for _, port := range testCases {
		err := manager.Enable(port)
		if err == nil {
			t.Errorf("Expected error for invalid port %d", port)
		}
	}
}
