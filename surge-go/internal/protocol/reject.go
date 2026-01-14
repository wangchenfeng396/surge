package protocol

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"time"
)

// RejectDialer implements Dialer interface for rejecting connections immediately
type RejectDialer struct {
	name string
}

// NewRejectDialer creates a new RejectDialer
func NewRejectDialer(name string) *RejectDialer {
	if name == "" {
		name = "REJECT"
	}
	return &RejectDialer{name: name}
}

func (r *RejectDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	return nil, errors.New("connection rejected by policy")
}

func (r *RejectDialer) Name() string { return r.name }
func (r *RejectDialer) Type() string { return "reject" }
func (r *RejectDialer) Test(url string, timeout time.Duration) (int, error) {
	return 0, errors.New("reject dialer cannot be tested")
}
func (r *RejectDialer) Close() error { return nil }

// RejectNoDropDialer is an alias for RejectDialer but with a specific name/intent
type RejectNoDropDialer struct {
	*RejectDialer
}

func NewRejectNoDropDialer() *RejectNoDropDialer {
	return &RejectNoDropDialer{RejectDialer: NewRejectDialer("REJECT-NO-DROP")}
}

// RejectDropDialer drops the connection by waiting until timeout
type RejectDropDialer struct {
	name string
}

func NewRejectDropDialer() *RejectDropDialer {
	return &RejectDropDialer{name: "REJECT-DROP"}
}

func (r *RejectDropDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	// Simulate silent drop by hanging until deadline
	if deadline, ok := ctx.Deadline(); ok {
		time.Sleep(time.Until(deadline))
	} else {
		// Default wait if no deadline
		time.Sleep(30 * time.Second)
	}
	return nil, context.DeadlineExceeded
}

func (r *RejectDropDialer) Name() string { return r.name }
func (r *RejectDropDialer) Type() string { return "reject-drop" }
func (r *RejectDropDialer) Test(url string, timeout time.Duration) (int, error) {
	// Test should simply fail/timeout
	time.Sleep(timeout)
	return 0, context.DeadlineExceeded
}
func (r *RejectDropDialer) Close() error { return nil }

// RejectTinyGifDialer serves a 1x1 transparent GIF
type RejectTinyGifDialer struct {
	name string
}

func NewRejectTinyGifDialer() *RejectTinyGifDialer {
	return &RejectTinyGifDialer{name: "REJECT-TINYGIF"}
}

func (r *RejectTinyGifDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	// Construct HTTP response with 1x1 GIF
	// GIF 1x1 Transparent
	gifBytes := []byte{
		0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
		0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
		0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
	}

	header := "HTTP/1.1 200 OK\r\n" +
		"Content-Type: image/gif\r\n" +
		"Content-Length: 43\r\n" +
		"Connection: close\r\n" +
		"\r\n"

	data := append([]byte(header), gifBytes...)

	return &bufferConn{
		Reader: bytes.NewReader(data),
		// We don't care about writes, they go to blackhole
	}, nil
}

func (r *RejectTinyGifDialer) Name() string { return r.name }
func (r *RejectTinyGifDialer) Type() string { return "reject-tinygif" }
func (r *RejectTinyGifDialer) Test(url string, timeout time.Duration) (int, error) {
	return 0, errors.New("reject-tinygif dialer cannot be tested")
}
func (r *RejectTinyGifDialer) Close() error { return nil }

// bufferConn mimics a net.Conn serving static data
type bufferConn struct {
	io.Reader
}

func (b *bufferConn) Read(p []byte) (n int, err error) {
	return b.Reader.Read(p)
}
func (b *bufferConn) Write(p []byte) (n int, err error) {
	return len(p), nil // Discard writes
}
func (b *bufferConn) Close() error { return nil }
func (b *bufferConn) LocalAddr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
}
func (b *bufferConn) RemoteAddr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
}
func (b *bufferConn) SetDeadline(t time.Time) error      { return nil }
func (b *bufferConn) SetReadDeadline(t time.Time) error  { return nil }
func (b *bufferConn) SetWriteDeadline(t time.Time) error { return nil }
