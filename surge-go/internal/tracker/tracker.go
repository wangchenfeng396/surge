package tracker

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/capture"
	"github.com/surge-proxy/surge-go/internal/protocol"
)

// Connection represents an active connection
type Connection struct {
	ID            string    `json:"id"`
	PID           int       `json:"pid"`
	ProcessName   string    `json:"process_name"`
	SourceIP      string    `json:"source_ip"`
	TargetAddress string    `json:"target_address"`
	Rule          string    `json:"rule"`
	Policy        string    `json:"policy"`
	StartTime     time.Time `json:"start_time"`
	UploadBytes   uint64    `json:"upload"`
	DownloadBytes uint64    `json:"download"`
}

// Tracker manages active connections
type Tracker struct {
	mu           sync.RWMutex
	conns        map[string]*Connection
	CaptureStore *capture.Store
}

// NewTracker creates a new tracker
func NewTracker(store *capture.Store) *Tracker {
	return &Tracker{
		conns:        make(map[string]*Connection),
		CaptureStore: store,
	}
}

// Track registers a new connection and returns a wrapper
func (t *Tracker) Track(conn net.Conn, meta *Connection) net.Conn {
	t.mu.Lock()
	defer t.mu.Unlock()

	// Generate ID if empty
	if meta.ID == "" {
		meta.ID = fmt.Sprintf("%d-%d", time.Now().UnixNano(), len(t.conns))
	}
	meta.StartTime = time.Now()

	t.conns[meta.ID] = meta

	return &TrackedConn{
		Conn:    conn,
		tracker: t,
		id:      meta.ID,
		connObj: meta,
	}
}

// Unregister removes a connection
func (t *Tracker) Unregister(id string) {
	t.mu.Lock()
	conn, ok := t.conns[id]
	if ok {
		delete(t.conns, id)
	}
	t.mu.Unlock()

	// Add to capture store
	if ok && t.CaptureStore != nil {
		req := &capture.Request{
			ID:            conn.ID,
			URL:           conn.TargetAddress,
			Method:        "TCP", // Default for now
			Timestamp:     conn.StartTime,
			Duration:      time.Since(conn.StartTime).Seconds(),
			Policy:        conn.Policy,
			Rule:          conn.Rule,
			SourceIP:      conn.SourceIP,
			UploadBytes:   conn.UploadBytes,
			DownloadBytes: conn.DownloadBytes,
			StatusCode:    200, // Assume success
		}
		t.CaptureStore.Add(req)
	}
}

// GetConnections returns a list of active connections
func (t *Tracker) GetConnections() []*Connection {
	t.mu.RLock()
	defer t.mu.RUnlock()

	list := make([]*Connection, 0, len(t.conns))
	for _, c := range t.conns {
		list = append(list, c)
	}
	return list
}

// TrackedConn wraps net.Conn to update stats
type TrackedConn struct {
	net.Conn
	tracker *Tracker
	id      string
	connObj *Connection
}

func (c *TrackedConn) Read(b []byte) (n int, err error) {
	n, err = c.Conn.Read(b)
	if n > 0 {
		c.connObj.DownloadBytes += uint64(n)
	}
	return
}

func (c *TrackedConn) Write(b []byte) (n int, err error) {
	n, err = c.Conn.Write(b)
	if n > 0 {
		c.connObj.UploadBytes += uint64(n)
	}
	return
}

func (c *TrackedConn) Close() error {
	c.tracker.Unregister(c.id)
	return c.Conn.Close()
}

// TrackingDialer implements protocol.Dialer and tracks connections
type TrackingDialer struct {
	Dialer  protocol.Dialer
	Tracker *Tracker
	Meta    *Connection
}

func (d *TrackingDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	conn, err := d.Dialer.DialContext(ctx, network, address)
	if err != nil {
		return nil, err
	}

	// Track connection
	// We need a copy of Meta because it might be reused or modified
	meta := *d.Meta
	meta.TargetAddress = address // Ensure address is captured if not already

	tracked := d.Tracker.Track(conn, &meta)
	return tracked, nil
}

func (d *TrackingDialer) Name() string {
	return d.Dialer.Name()
}

func (d *TrackingDialer) Type() string {
	return d.Dialer.Type()
}

func (d *TrackingDialer) Test(url string, timeout time.Duration) (int, error) {
	return d.Dialer.Test(url, timeout)
}

func (d *TrackingDialer) Close() error {
	// Dialer may handle closing of resources
	return nil
}
