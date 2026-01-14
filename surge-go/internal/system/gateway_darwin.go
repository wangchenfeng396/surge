package system

import (
	"fmt"
	"os/exec"
	"strings"
)

// GetDefaultGateway returns the default gateway IP and interface name
func GetDefaultGateway() (string, string, error) {
	cmd := exec.Command("route", "-n", "get", "default")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", "", err
	}

	lines := strings.Split(string(output), "\n")
	var gateway, iface string

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "gateway:") {
			gateway = strings.TrimSpace(strings.TrimPrefix(line, "gateway:"))
		}
		if strings.HasPrefix(line, "interface:") {
			iface = strings.TrimSpace(strings.TrimPrefix(line, "interface:"))
		}
	}

	if gateway == "" {
		// Fallback: Try to get gateway from en0 or en1 (common physical interfaces)
		// This handles VPN cases where default route is utun* and has no gateway
		for _, ifaceName := range []string{"en0", "en1"} {
			out, err := exec.Command("ipconfig", "getoption", ifaceName, "router").Output()
			if err == nil {
				gw := strings.TrimSpace(string(out))
				if gw != "" {
					return gw, ifaceName, nil
				}
			}
		}

		return "", "", fmt.Errorf("gateway not found in route output or fallback interfaces")
	}

	return gateway, iface, nil
}
