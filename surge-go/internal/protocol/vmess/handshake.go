package vmess

import (
	"bytes"
	"crypto/md5"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"time"
)

// Command types
const (
	CommandTCP byte = 0x01
	CommandUDP byte = 0x02
)

// Address types
const (
	AddressTypeIPv4   byte = 0x01
	AddressTypeIPv6   byte = 0x03
	AddressTypeDomain byte = 0x02
)

// RequestOption options
const (
	RequestOptionChunkStream         byte = 0x01
	RequestOptionConnectionReuse     byte = 0x02
	RequestOptionChunkMasking        byte = 0x04
	RequestOptionGlobalPadding       byte = 0x08
	RequestOptionAuthenticatedLength byte = 0x10
)

// RequestHeader represents VMess request header
type RequestHeader struct {
	Version  byte
	Command  byte
	Option   byte
	Security byte
	Address  string
	Port     uint16
	UUID     []byte
}

// EncodeRequestHeader encodes request header for AEAD mode
func EncodeRequestHeader(header *RequestHeader, cmdKey []byte) ([]byte, []byte, []byte, []byte, error) {
	buf := new(bytes.Buffer)

	// Version (1 byte)
	buf.WriteByte(header.Version)

	// IV (16 bytes) - body key
	bodyIV := make([]byte, 16)
	if _, err := rand.Read(bodyIV); err != nil {
		return nil, nil, nil, nil, err
	}
	buf.Write(bodyIV)

	// Body Key (16 bytes)
	bodyKey := make([]byte, 16)
	if _, err := rand.Read(bodyKey); err != nil {
		return nil, nil, nil, nil, err
	}
	buf.Write(bodyKey)

	// Response header (1 byte)
	v := make([]byte, 1)
	rand.Read(v)
	buf.WriteByte(v[0]) // Random V

	// Option (1 byte)
	buf.WriteByte(header.Option)

	// Padding and Security (4 bits + 4 bits)
	pb := make([]byte, 1)
	rand.Read(pb)
	pLen := pb[0] % 16
	paddingSec := (pLen << 4) | (header.Security & 0x0F)
	buf.WriteByte(paddingSec)

	// Reserved (1 byte)
	buf.WriteByte(0)

	// Command (1 byte)
	buf.WriteByte(header.Command)

	// Port (2 bytes, big endian)
	portBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(portBytes, header.Port)
	buf.Write(portBytes)

	// Address Type and Address
	if err := encodeAddress(buf, header.Address); err != nil {
		return nil, nil, nil, nil, err
	}

	// Random padding (actual data matching pLen)
	padding := make([]byte, int(pLen))
	if _, err := rand.Read(padding); err != nil {
		return nil, nil, nil, nil, err
	}
	buf.Write(padding)

	// Calculate checksum (FNV1a)
	data := buf.Bytes()
	checksum := fnv1a(data)
	checksumBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(checksumBytes, checksum)
	buf.Write(checksumBytes)

	// Generate AuthID
	authid, err := CreateAEADHeader(header.UUID)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	fmt.Printf("[VMess] AuthID generated: %x\n", authid)

	// Encrypt header with raw UUID (standard for AEAD)
	headerData := buf.Bytes()
	encrypted, err := EncryptAEADHeader(header.UUID, headerData, authid)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	return encrypted, bodyKey, bodyIV, authid, nil
}

// EncodeLegacyRequestHeader encodes request header for legacy mode
func EncodeLegacyRequestHeader(header *RequestHeader, cmdKey []byte) ([]byte, []byte, []byte, int64, error) {
	buf := new(bytes.Buffer)

	// IV (16 bytes) - body key
	bodyIV := make([]byte, 16)
	if _, err := rand.Read(bodyIV); err != nil {
		return nil, nil, nil, 0, err
	}

	// Body Key (16 bytes)
	bodyKey := make([]byte, 16)
	if _, err := rand.Read(bodyKey); err != nil {
		return nil, nil, nil, 0, err
	}

	// 1. Version (1 byte)
	buf.WriteByte(header.Version)

	// 2. Body IV (16 bytes)
	buf.Write(bodyIV)

	// 3. Body Key (16 bytes)
	buf.Write(bodyKey)

	// 4. Response header V (1 byte)
	v := make([]byte, 1)
	rand.Read(v)
	buf.WriteByte(v[0])

	// 5. Option (1 byte)
	buf.WriteByte(header.Option)

	// 6. Padding and Security (4 bits + 4 bits)
	pb := make([]byte, 1)
	rand.Read(pb)
	paddingLen := pb[0] % 16
	buf.WriteByte((paddingLen << 4) | (header.Security & 0x0F))

	// 7. Reserved (1 byte)
	buf.WriteByte(0)

	// 8. Command (1 byte)
	buf.WriteByte(header.Command)

	// 9. Port (2 bytes, big endian)
	portBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(portBytes, header.Port)
	buf.Write(portBytes)

	// 10. Address Type and Address
	if err := encodeAddress(buf, header.Address); err != nil {
		return nil, nil, nil, 0, err
	}

	// 11. Random padding (actual data matching paddingLen)
	padding := make([]byte, int(paddingLen))
	if _, err := rand.Read(padding); err != nil {
		return nil, nil, nil, 0, err
	}
	buf.Write(padding)

	// 12. Checksum (4 bytes FNV1a)
	checksum := fnv1a(buf.Bytes())
	binary.Write(buf, binary.BigEndian, checksum)

	headerData := buf.Bytes()

	// Encryption
	now := time.Now().Unix()
	ts := make([]byte, 8)
	binary.BigEndian.PutUint64(ts, uint64(now))

	// Legacy Auth (User ID Hash)
	auth := CreateLegacyAuth(header.UUID, now)

	// Legacy Encryption Key and IV
	encKey := cmdKey // Standard legacy VMess uses CmdKey directly
	// IV = MD5(timestamp x 4)
	tsHash := md5.New()
	tsHash.Write(ts)
	tsHash.Write(ts)
	tsHash.Write(ts)
	tsHash.Write(ts)
	encIV := tsHash.Sum(nil)

	encrypted, err := EncryptLegacyHeader(encKey, encIV, headerData)
	if err != nil {
		return nil, nil, nil, 0, err
	}

	result := make([]byte, len(auth)+len(encrypted))
	copy(result, auth)
	copy(result[len(auth):], encrypted)

	return result, bodyKey, bodyIV, now, nil
}

// encodeAddress encodes address to bytes
func encodeAddress(buf *bytes.Buffer, address string) error {
	// Try to parse as IPv4/IPv6 or domain
	// Simplified: treat as domain if it contains non-numeric characters
	isDomain := false
	for _, c := range address {
		if (c < '0' || c > '9') && c != '.' && c != ':' {
			isDomain = true
			break
		}
	}

	if isDomain {
		// Domain name
		if len(address) > 255 {
			return errors.New("domain name too long")
		}
		buf.WriteByte(AddressTypeDomain)
		buf.WriteByte(byte(len(address)))
		buf.WriteString(address)
	} else if bytes.Contains([]byte(address), []byte(":")) {
		// IPv6
		buf.WriteByte(AddressTypeIPv6)
		// Parse IPv6 (simplified, should use net.ParseIP)
		ipv6 := make([]byte, 16)
		buf.Write(ipv6)
	} else {
		// IPv4
		buf.WriteByte(AddressTypeIPv4)
		// Parse IPv4 (simplified, should use net.ParseIP)
		ipv4 := make([]byte, 4)
		fmt.Sscanf(address, "%d.%d.%d.%d", &ipv4[0], &ipv4[1], &ipv4[2], &ipv4[3])
		buf.Write(ipv4)
	}

	return nil
}

// fnv1a calculates FNV-1a hash
func fnv1a(data []byte) uint32 {
	const (
		offset32 = 2166136261
		prime32  = 16777619
	)
	hash := uint32(offset32)
	for _, b := range data {
		hash ^= uint32(b)
		hash *= prime32
	}
	return hash
}

// DecodeResponseHeader decodes VMess response header
func DecodeResponseHeader(cmdKey []byte, reader io.Reader, authid []byte) (*ResponseHeader, error) {
	// Read just the first few bytes to see what's happening
	peek := make([]byte, 1)
	n, err := io.ReadAtLeast(reader, peek, 1)
	if err != nil {
		fmt.Printf("[VMess] Response peek failed: %v\n", err)
		return nil, err
	}
	fmt.Printf("[VMess] First byte from server: %x\n", peek[0])

	// Read the rest of the 20 bytes
	remaining := make([]byte, 20-n)
	if _, err := io.ReadFull(reader, remaining); err != nil {
		fmt.Printf("[VMess] Response read full failed: %v\n", err)
		return nil, err
	}
	encrypted := append(peek, remaining...)

	// Decrypt header
	decrypted, err := DecryptAEADHeader(cmdKey, encrypted, authid)
	if err != nil {
		return nil, err
	}

	if len(decrypted) < 4 {
		return nil, errors.New("response header too short")
	}

	response := &ResponseHeader{
		Version: decrypted[0],
		Option:  decrypted[1],
		Command: decrypted[2],
	}

	return response, nil
}

// DecodeLegacyResponseHeader decodes VMess response header for legacy mode
func DecodeLegacyResponseHeader(cmdKey []byte, reader io.Reader, now int64) (*ResponseHeader, error) {
	ts := make([]byte, 8)
	binary.BigEndian.PutUint64(ts, uint64(now))

	respKey := md5.Sum(cmdKey)
	tsHash := md5.New()
	tsHash.Write(ts)
	tsHash.Write(ts)
	tsHash.Write(ts)
	tsHash.Write(ts)
	reqIV := tsHash.Sum(nil)
	respIV := md5.Sum(reqIV)

	// Read 4 bytes
	encrypted := make([]byte, 4)
	if _, err := io.ReadFull(reader, encrypted); err != nil {
		return nil, err
	}

	decrypted, err := DecryptLegacyHeader(respKey[:], respIV[:], encrypted)
	if err != nil {
		return nil, err
	}

	return &ResponseHeader{
		Version: decrypted[0],
		Option:  decrypted[1],
		Command: decrypted[2],
	}, nil
}

// ResponseHeader represents VMess response header
type ResponseHeader struct {
	Version byte
	Option  byte
	Command byte
}

// CreateRequestHeader creates a new request header
func CreateRequestHeader(command byte, address string, port uint16, uuid []byte, security Security) *RequestHeader {
	// Map security to byte according to VMess standard:
	// 0: Legacy, 1: Old AES-128-GCM, 2: ChaCha20-Poly1305 (Old), 3: AES-128-GCM, 4: ChaCha20-Poly1305, 5: None
	var secByte byte
	switch security {
	case SecurityAES128GCM:
		secByte = 0x03
	case SecurityChacha20Poly1305:
		secByte = 0x04
	case SecurityNone:
		secByte = 0x05
	default:
		secByte = 0x03 // Default to AES-128-GCM
	}

	return &RequestHeader{
		Version:  1,
		Command:  command,
		Option:   RequestOptionChunkStream,
		Security: secByte,
		Address:  address,
		Port:     port,
		UUID:     uuid,
	}
}

// TimestampHash generates timestamp-based hash for authentication
func TimestampHash(uuid []byte) []byte {
	// Current time
	now := time.Now().Unix()

	// Create buffer with timestamp
	buf := new(bytes.Buffer)
	binary.Write(buf, binary.BigEndian, now)
	buf.Write(uuid)

	// Hash
	h := fnv1a(buf.Bytes())
	hashBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(hashBytes, h)

	return hashBytes
}
