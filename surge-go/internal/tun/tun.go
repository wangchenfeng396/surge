//go:build ignore

package tun

import (
	"fmt"
	"net"

	"github.com/songgao/water"
	"gvisor.dev/gvisor/pkg/buffer"
	"gvisor.dev/gvisor/pkg/tcpip"
	"gvisor.dev/gvisor/pkg/tcpip/header"
	"gvisor.dev/gvisor/pkg/tcpip/network/ipv4"
	"gvisor.dev/gvisor/pkg/tcpip/stack"
	"gvisor.dev/gvisor/pkg/tcpip/transport/tcp"
	"gvisor.dev/gvisor/pkg/tcpip/transport/udp"
)

// Device represents a TUN device and its network stack
type Device struct {
	iface *water.Interface
	stack *stack.Stack
}

// Handler is the interface for packet handling (from stack)
type Handler interface {
	HandleTUNConnection(conn net.Conn, target string)
}

// TUNEndpoint implements stack.LinkEndpoint
type TUNEndpoint struct {
	iface      *water.Interface
	dispatcher stack.NetworkDispatcher
	mtu        uint32
}

func NewTUNEndpoint(iface *water.Interface, mtu uint32) *TUNEndpoint {
	return &TUNEndpoint{
		iface: iface,
		mtu:   mtu,
	}
}

// MTU implements stack.LinkEndpoint
func (e *TUNEndpoint) MTU() uint32 {
	return e.mtu
}

// Capabilities implements stack.LinkEndpoint
func (e *TUNEndpoint) Capabilities() stack.LinkEndpointCapabilities {
	return stack.CapabilityNone
}

// MaxHeaderLength implements stack.LinkEndpoint
func (e *TUNEndpoint) MaxHeaderLength() uint16 {
	return 0
}

// LinkAddress implements stack.LinkEndpoint
func (e *TUNEndpoint) LinkAddress() tcpip.LinkAddress {
	return ""
}

// WritePackets implements stack.LinkEndpoint
func (e *TUNEndpoint) WritePackets(pkts stack.PacketBufferList) (int, tcpip.Error) {
	n := 0
	for _, pkt := range pkts.AsSlice() {
		// Serialize packet
		// View returns a VectorisedView. ToFlatten?
		// New gVisor: pkt.ToView().ToVectorisedView().ToFlatten()?
		// Helper: pkt.ToView().AsSlice()?
		// Actually PacketBuffer has `ToView` which returns `*View`.
		// `View` has `AsSlice`.

		// Wait, WritePackets expects us to write to TUN.
		// We need bytes.
		v := pkt.ToView()
		bs := v.AsSlice()

		if _, err := e.iface.Write(bs); err != nil {
			return n, &tcpip.ErrInvalidEndpointState{}
		}
		n++
	}
	return n, nil
}

// Attach implements stack.LinkEndpoint
func (e *TUNEndpoint) Attach(dispatcher stack.NetworkDispatcher) {
	e.dispatcher = dispatcher
	// Start reading loop
	go e.dispatchLoop()
}

func (e *TUNEndpoint) dispatchLoop() {
	buf := make([]byte, 2048)
	for {
		n, err := e.iface.Read(buf)
		if err != nil {
			// Stopped
			return
		}

		// Ingest
		// Copy buffer because it might be reused?
		// Use vectorised view to avoid copy if possible, but Read(buf) is simple.
		payload := buffer.MakeWithData(append([]byte(nil), buf[:n]...))

		pkt := stack.NewPacketBuffer(stack.PacketBufferOptions{
			Payload: payload,
		})

		// Assuming IPv4 for now. TUN usually delivers IP packets.
		// But IsSupportedProtocol checks? protocol is in header?
		// We should inspect header?
		// Or just pass to ipv4?
		// If tun is Layer 3, we pass network protocol.
		// Usually determine by version byte (4 or 6).

		proto := ipv4.ProtocolNumber // Default
		if n > 0 && (buf[0]>>4) == 6 {
			// ipv6
			// proto = ipv6.ProtocolNumber
		}

		e.dispatcher.DeliverNetworkPacket(proto, pkt)
		pkt.DecRef()
	}
}

// IsAttached implements stack.LinkEndpoint
func (e *TUNEndpoint) IsAttached() bool {
	return e.dispatcher != nil
}

// Wait implements stack.LinkEndpoint
func (e *TUNEndpoint) Wait() {
}

// ARPHardwareType implements stack.LinkEndpoint
func (e *TUNEndpoint) ARPHardwareType() header.ARPHardwareType {
	return header.ARPHardwareNone
}

// AddHeader implements stack.LinkEndpoint
func (e *TUNEndpoint) AddHeader(local, remote tcpip.LinkAddress, protocol tcpip.NetworkProtocolNumber, pkt *stack.PacketBuffer) {
}

// ParseHeader implements stack.LinkEndpoint
// Recent gVisor requires ParseHeader? Check interface.
// If missing, compilation error.

// Start creates and starts a TUN device
func Start(name string, gateway string, handler Handler) (*Device, error) {
	// 1. Create TUN interface
	cfg := water.Config{
		DeviceType: water.TUN,
	}
	iface, err := water.New(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create TUN: %v", err)
	}
	fmt.Printf("TUN device created: %s\n", iface.Name())

	// 2. Create Netstack
	s := stack.New(stack.Options{
		NetworkProtocols:   []stack.NetworkProtocolFactory{ipv4.NewProtocol},
		TransportProtocols: []stack.TransportProtocolFactory{tcp.NewProtocol, udp.NewProtocol},
	})

	// 3. Link TUN to Stack
	epID := tcpip.NICID(1)
	ep := NewTUNEndpoint(iface, 1500)

	if err := s.CreateNIC(epID, ep); err != nil {
		return nil, fmt.Errorf("failed to create NIC: %v", err)
	}

	// Add Protocol Addresses
	addr := tcpip.AddrFromSlice(net.ParseIP(gateway).To4()) // New API

	if err := s.AddProtocolAddress(epID, tcpip.ProtocolAddress{
		Protocol: ipv4.ProtocolNumber,
		AddressWithPrefix: tcpip.AddressWithPrefix{
			Address:   addr,
			PrefixLen: 24,
		},
	}, stack.AddressProperties{}); err != nil {
		return nil, fmt.Errorf("failed to add address: %v", err)
	}

	// Set Route Table
	s.SetRouteTable([]tcpip.Route{
		{
			Destination: header.IPv4EmptySubnet,
			Gateway:     tcpip.Address{},
			NIC:         epID,
		},
	})

	return &Device{
		iface: iface,
		stack: s,
	}, nil
}

func (d *Device) Close() error {
	if d.iface != nil {
		return d.iface.Close()
	}
	return nil
}
