package stats

import (
	"sync"
	"time"
)

// Collector collects and manages statistics
type Collector struct {
	mu             sync.RWMutex
	uploadBytes    uint64
	downloadBytes  uint64
	uploadSpeed    uint64
	downloadSpeed  uint64
	activeConns    int
	totalConns     uint64
	processes      map[int]*ProcessStats
	devices        map[string]*DeviceStats
	latency        *LatencyStats
	trafficHistory []TrafficPoint
}

// ProcessStats represents statistics for a process
type ProcessStats struct {
	PID           int       `json:"pid"`
	Name          string    `json:"name"`
	UploadBytes   uint64    `json:"upload_bytes"`
	DownloadBytes uint64    `json:"download_bytes"`
	Connections   int       `json:"connections"`
	LastActive    time.Time `json:"last_active"`
}

// DeviceStats represents statistics for a connected device
type DeviceStats struct {
	IP            string    `json:"ip"`
	MAC           string    `json:"mac"`
	Hostname      string    `json:"hostname"`
	UploadBytes   uint64    `json:"upload_bytes"`
	DownloadBytes uint64    `json:"download_bytes"`
	Connections   int       `json:"connections"`
	FirstSeen     time.Time `json:"first_seen"`
	LastSeen      time.Time `json:"last_seen"`
}

// LatencyStats represents latency measurements
type LatencyStats struct {
	Router int `json:"router"`
	DNS    int `json:"dns"`
	Proxy  int `json:"proxy"`
}

// TrafficPoint represents a point in traffic history
type TrafficPoint struct {
	Timestamp time.Time `json:"timestamp"`
	Upload    uint64    `json:"upload"`
	Download  uint64    `json:"download"`
}

// NetworkStats represents current network statistics
type NetworkStats struct {
	UploadBytes    uint64         `json:"upload_bytes"`
	DownloadBytes  uint64         `json:"download_bytes"`
	UploadSpeed    uint64         `json:"upload_speed"`
	DownloadSpeed  uint64         `json:"download_speed"`
	ActiveConns    int            `json:"active_connections"`
	TotalConns     uint64         `json:"total_connections"`
	Latency        *LatencyStats  `json:"latency"`
	TrafficHistory []TrafficPoint `json:"traffic_history"`
}

// NewCollector creates a new statistics collector
func NewCollector() *Collector {
	c := &Collector{
		processes:      make(map[int]*ProcessStats),
		devices:        make(map[string]*DeviceStats),
		latency:        &LatencyStats{},
		trafficHistory: make([]TrafficPoint, 0, 360), // 6 hours at 1min intervals
	}

	// Start background goroutine to update speeds
	go c.updateSpeeds()

	return c
}

// RecordUpload records uploaded bytes
func (c *Collector) RecordUpload(bytes uint64, pid int, deviceIP string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.uploadBytes += bytes

	if pid > 0 {
		if proc, ok := c.processes[pid]; ok {
			proc.UploadBytes += bytes
			proc.LastActive = time.Now()
		}
	}

	if deviceIP != "" {
		if dev, ok := c.devices[deviceIP]; ok {
			dev.UploadBytes += bytes
			dev.LastSeen = time.Now()
		}
	}
}

// RecordDownload records downloaded bytes
func (c *Collector) RecordDownload(bytes uint64, pid int, deviceIP string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.downloadBytes += bytes

	if pid > 0 {
		if proc, ok := c.processes[pid]; ok {
			proc.DownloadBytes += bytes
			proc.LastActive = time.Now()
		}
	}

	if deviceIP != "" {
		if dev, ok := c.devices[deviceIP]; ok {
			dev.DownloadBytes += bytes
			dev.LastSeen = time.Now()
		}
	}
}

// IncrementConnection increments active connection count
func (c *Collector) IncrementConnection() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.activeConns++
	c.totalConns++
}

// DecrementConnection decrements active connection count
func (c *Collector) DecrementConnection() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.activeConns > 0 {
		c.activeConns--
	}
}

// RegisterProcess registers a new process
func (c *Collector) RegisterProcess(pid int, name string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, exists := c.processes[pid]; !exists {
		c.processes[pid] = &ProcessStats{
			PID:        pid,
			Name:       name,
			LastActive: time.Now(),
		}
	}
}

// RegisterDevice registers a new device
func (c *Collector) RegisterDevice(ip, mac, hostname string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, exists := c.devices[ip]; !exists {
		now := time.Now()
		c.devices[ip] = &DeviceStats{
			IP:        ip,
			MAC:       mac,
			Hostname:  hostname,
			FirstSeen: now,
			LastSeen:  now,
		}
	}
}

// GetStats returns current statistics
func (c *Collector) GetStats() *NetworkStats {
	c.mu.RLock()
	defer c.mu.RUnlock()

	return &NetworkStats{
		UploadBytes:    c.uploadBytes,
		DownloadBytes:  c.downloadBytes,
		UploadSpeed:    c.uploadSpeed,
		DownloadSpeed:  c.downloadSpeed,
		ActiveConns:    c.activeConns,
		TotalConns:     c.totalConns,
		Latency:        c.latency,
		TrafficHistory: c.trafficHistory,
	}
}

// GetProcesses returns process statistics
func (c *Collector) GetProcesses() []*ProcessStats {
	c.mu.RLock()
	defer c.mu.RUnlock()

	procs := make([]*ProcessStats, 0, len(c.processes))
	for _, proc := range c.processes {
		procs = append(procs, proc)
	}
	return procs
}

// GetDevices returns device statistics
func (c *Collector) GetDevices() []*DeviceStats {
	c.mu.RLock()
	defer c.mu.RUnlock()

	devs := make([]*DeviceStats, 0, len(c.devices))
	for _, dev := range c.devices {
		devs = append(devs, dev)
	}
	return devs
}

// updateSpeeds updates upload/download speeds periodically
func (c *Collector) updateSpeeds() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	var lastUpload, lastDownload uint64

	for range ticker.C {
		c.mu.Lock()

		c.uploadSpeed = c.uploadBytes - lastUpload
		c.downloadSpeed = c.downloadBytes - lastDownload

		lastUpload = c.uploadBytes
		lastDownload = c.downloadBytes

		// Add to traffic history every minute
		if time.Now().Second() == 0 {
			c.trafficHistory = append(c.trafficHistory, TrafficPoint{
				Timestamp: time.Now(),
				Upload:    c.uploadBytes,
				Download:  c.downloadBytes,
			})

			// Keep only last 360 points (6 hours)
			if len(c.trafficHistory) > 360 {
				c.trafficHistory = c.trafficHistory[1:]
			}
		}

		c.mu.Unlock()
	}
}

// UpdateLatency updates latency statistics
func (c *Collector) UpdateLatency(router, dns, proxy int) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.latency.Router = router
	c.latency.DNS = dns
	c.latency.Proxy = proxy
}
