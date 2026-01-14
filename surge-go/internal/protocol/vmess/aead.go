package vmess

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/md5"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"io"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/sha3"
)

const (
	// AEAD header length
	AuthLenAEAD = 16
)

// AEAD encryption helpers

// CreateAEADHeader creates AEAD authentication header
func CreateAEADHeader(uuid []byte) ([]byte, error) {
	header := make([]byte, AuthLenAEAD)

	// 1. Timestamp (4 bytes, BigEndian)
	ts := uint32(time.Now().Unix())
	binary.BigEndian.PutUint32(header[0:4], ts)

	// 2. Random bytes (4 bytes)
	if _, err := rand.Read(header[4:8]); err != nil {
		return nil, err
	}

	// 3. CRC32 checksum (4 bytes)
	checksum := crc32.ChecksumIEEE(header[0:8])
	binary.BigEndian.PutUint32(header[8:12], checksum)

	// 4. XOR sum (4 bytes)
	for i := 0; i < 4; i++ {
		header[12+i] = header[0+i] ^ header[4+i] ^ header[8+i]
	}

	// Encrypt with UUID
	key := kdf16(uuid, []byte("AES Auth ID Encryption"))
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	encrypted := make([]byte, AuthLenAEAD)
	block.Encrypt(encrypted, header)

	return encrypted, nil
}

// CreateLegacyAuth creates legacy authentication hash (HMAC-MD5)
func CreateLegacyAuth(uuid []byte, timestamp int64) []byte {
	h := hmac.New(md5.New, uuid)
	ts := make([]byte, 8)
	binary.BigEndian.PutUint64(ts, uint64(timestamp))
	h.Write(ts)
	return h.Sum(nil)
}

// EncryptLegacyHeader encrypts header with legacy AES-CFB
func EncryptLegacyHeader(key, iv, data []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	stream := cipher.NewCFBEncrypter(block, iv)
	encrypted := make([]byte, len(data))
	stream.XORKeyStream(encrypted, data)
	return encrypted, nil
}

// DecryptLegacyHeader decrypts header with legacy AES-CFB
func DecryptLegacyHeader(key, iv, data []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	stream := cipher.NewCFBDecrypter(block, iv)
	decrypted := make([]byte, len(data))
	stream.XORKeyStream(decrypted, data)
	return decrypted, nil
}

// kdf16 generates a 16-byte key from seed using KDF
func kdf16(seed []byte, path []byte) []byte {
	// V2Ray KDF: HMAC-SHA256(key=seed, data=path)
	h := hmac.New(sha256.New, seed)
	h.Write(path)
	res := h.Sum(nil)
	return res[:16]
}

// kdf generates variable length key
func kdf(seed []byte, path []byte, size int) []byte {
	// V2Ray KDF: HMAC-SHA256(key=path, data=seed)
	h := hmac.New(sha256.New, path)
	h.Write(seed)
	v := h.Sum(nil)
	for len(v) < size {
		h.Reset()
		h.Write(v)
		v = append(v, h.Sum(nil)...)
	}
	return v[:size]
}

// hmacSHA256 computes HMAC-SHA256
func hmacSHA256(key, data []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(data)
	return h.Sum(nil)
}

// CreateAEADCipher creates AEAD cipher for encryption/decryption
func CreateAEADCipher(security Security, key []byte) (cipher.AEAD, error) {
	switch security {
	case SecurityAES128GCM:
		block, err := aes.NewCipher(key[:16])
		if err != nil {
			return nil, err
		}
		return cipher.NewGCM(block)
	case SecurityChacha20Poly1305:
		if len(key) < 32 {
			newKey := make([]byte, 32)
			copy(newKey, key)
			key = newKey
		}
		return chacha20poly1305.New(key[:32])
	default:
		return nil, errors.New("unsupported AEAD cipher")
	}
}

// SealAEAD encrypts data with AEAD
func SealAEAD(aead cipher.AEAD, nonce, plaintext, additionalData []byte) []byte {
	ciphertext := aead.Seal(nil, nonce, plaintext, additionalData)
	return ciphertext
}

// OpenAEAD decrypts data with AEAD
func OpenAEAD(aead cipher.AEAD, nonce, ciphertext, additionalData []byte) ([]byte, error) {
	return aead.Open(nil, nonce, ciphertext, additionalData)
}

// GenerateRequestNonce generates nonce for request encryption
func GenerateRequestNonce(timestamp int64, counter uint32) []byte {
	nonce := make([]byte, 12)
	binary.BigEndian.PutUint64(nonce[0:8], uint64(timestamp))
	binary.BigEndian.PutUint32(nonce[8:12], counter)
	return nonce
}

// GenerateResponseNonce generates nonce for response decryption
func GenerateResponseNonce(counter uint32) []byte {
	nonce := make([]byte, 12)
	binary.BigEndian.PutUint32(nonce[8:12], counter)
	return nonce
}

// EncryptAEADHeader encrypts VMess request header with AEAD
func EncryptAEADHeader(key []byte, header []byte, authid []byte) ([]byte, error) {
	if len(authid) != AuthLenAEAD {
		return nil, errors.New("invalid authid length")
	}

	// 1. Encrypt Header Length (2 bytes)
	lenKey := kdf16(key, []byte("VMess Header AEAD Key_Length"))
	lenNonce := kdf(key, []byte("VMess Header AEAD Nonce_Length"), 12)
	lenAead, err := CreateAEADCipher(SecurityAES128GCM, lenKey)
	if err != nil {
		return nil, err
	}

	lenBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(lenBytes, uint16(len(header)))
	encryptedLen := SealAEAD(lenAead, lenNonce, lenBytes, authid)

	// 2. Encrypt Header
	aeadKey := kdf16(key, []byte("VMess Header AEAD Key"))
	aeadNonce := kdf(key, []byte("VMess Header AEAD Nonce"), 12)
	aead, err := CreateAEADCipher(SecurityAES128GCM, aeadKey)
	if err != nil {
		return nil, err
	}
	encryptedHeader := SealAEAD(aead, aeadNonce, header, authid)

	// Return: AuthID + EncryptedLength (18) + EncryptedHeader
	result := make([]byte, len(authid)+len(encryptedLen)+len(encryptedHeader))
	copy(result, authid)
	copy(result[len(authid):], encryptedLen)
	copy(result[len(authid)+len(encryptedLen):], encryptedHeader)

	return result, nil
}

// DecryptAEADHeader decrypts VMess response header with AEAD
func DecryptAEADHeader(key []byte, data []byte, authid []byte) ([]byte, error) {
	// Standard VMess AEAD response header uses the request's AuthID as AD.

	// Create connection nonce (RESPONSE PATHS)
	aeadKey := kdf16(key, []byte("AEAD Resp Header Key"))
	aeadNonce := kdf(key, []byte("AEAD Resp Header Nonce"), 12)

	// Create AEAD cipher
	aead, err := CreateAEADCipher(SecurityAES128GCM, aeadKey)
	if err != nil {
		return nil, err
	}

	// Decrypt header using request's AuthID as AD
	decrypted, err := OpenAEAD(aead, aeadNonce, data, authid)
	if err != nil {
		return nil, err
	}

	return decrypted, nil
}

// LengthParser parses packet length
type LengthParser interface {
	SizeBytes() int32
	Encode(size uint16) []byte
	Decode(b []byte) (uint16, error)
}

// ShakeSizeParser creates a length parser based on nonce
func ShakeSizeParser(nonce []byte) LengthParser {
	return NewShakeParser(nonce)
}

// ShakeParser uses SHAKE128 for length masking
type ShakeParser struct {
	shake sha3.ShakeHash
}

func NewShakeParser(nonce []byte) *ShakeParser {
	s := sha3.NewShake128()
	s.Write(nonce)
	return &ShakeParser{shake: s}
}

func (p *ShakeParser) SizeBytes() int32 {
	return 2
}

func (p *ShakeParser) Encode(size uint16) []byte {
	b := make([]byte, 2)
	binary.BigEndian.PutUint16(b, size)

	mask := make([]byte, 2)
	p.shake.Read(mask)

	b[0] ^= mask[0]
	b[1] ^= mask[1]
	return b
}

func (p *ShakeParser) Decode(b []byte) (uint16, error) {
	if len(b) < 2 {
		return 0, errors.New("insufficient bytes")
	}

	mask := make([]byte, 2)
	p.shake.Read(mask)

	decoded := make([]byte, 2)
	decoded[0] = b[0] ^ mask[0]
	decoded[1] = b[1] ^ mask[1]

	return binary.BigEndian.Uint16(decoded), nil
}

// GenerateChunkNonce generates nonce for AEAD chunky encryption
func GenerateChunkNonce(nonce []byte, counter uint16) []byte {
	chunkNonce := make([]byte, 12)
	// V2Ray uses BigEndian counter at the beginning of the nonce
	binary.BigEndian.PutUint16(chunkNonce[0:2], counter)
	copy(chunkNonce[2:12], nonce[2:12])
	return chunkNonce
}

// NewCmdKey generates command key from UUID bytes
func NewCmdKey(uuid []byte) []byte {
	// Standard VMess command key derivation
	h := md5.New()
	h.Write(uuid)
	h.Write([]byte("c48619fe-8f02-49e0-b9e9-edf763e17e21"))
	return h.Sum(nil)
}

// ChunkReader reads AEAD encrypted chunks
type ChunkReader struct {
	reader  io.Reader
	aead    cipher.AEAD
	nonce   []byte
	counter uint16
	parser  LengthParser
	buffer  []byte
}

// NewChunkReader creates a new chunk reader
func NewChunkReader(r io.Reader, aead cipher.AEAD, nonce []byte) *ChunkReader {
	return &ChunkReader{
		reader:  r,
		aead:    aead,
		nonce:   nonce,
		counter: 0,
		parser:  ShakeSizeParser(nonce),
	}
}

// Read reads decrypted data
func (r *ChunkReader) Read(p []byte) (int, error) {
	if len(r.buffer) > 0 {
		n := copy(p, r.buffer)
		r.buffer = r.buffer[n:]
		return n, nil
	}

	// Read chunk length
	sizeBytes := make([]byte, r.parser.SizeBytes())
	if _, err := io.ReadFull(r.reader, sizeBytes); err != nil {
		return 0, err
	}

	size, err := r.parser.Decode(sizeBytes)
	if err != nil {
		return 0, err
	}

	if size == 0 {
		return 0, io.EOF
	}

	// Read encrypted chunk
	encrypted := make([]byte, int(size)+r.aead.Overhead())
	if _, err := io.ReadFull(r.reader, encrypted); err != nil {
		return 0, err
	}

	// Decrypt
	chunkNonce := GenerateChunkNonce(r.nonce, r.counter)
	r.counter++

	decrypted, err := r.aead.Open(nil, chunkNonce, encrypted, nil)
	if err != nil {
		return 0, err
	}

	// Copy to output
	n := copy(p, decrypted)
	if n < len(decrypted) {
		r.buffer = decrypted[n:]
	}

	return n, nil
}

// ChunkWriter writes AEAD encrypted chunks
type ChunkWriter struct {
	writer  io.Writer
	aead    cipher.AEAD
	nonce   []byte
	counter uint16
	parser  LengthParser
}

// NewChunkWriter creates a new chunk writer
func NewChunkWriter(w io.Writer, aead cipher.AEAD, nonce []byte) *ChunkWriter {
	return &ChunkWriter{
		writer:  w,
		aead:    aead,
		nonce:   nonce,
		counter: 0,
		parser:  ShakeSizeParser(nonce),
	}
}

// Write writes encrypted data
func (w *ChunkWriter) Write(p []byte) (int, error) {
	total := 0
	chunkSize := 16384 // 16KB chunks

	for len(p) > 0 {
		size := len(p)
		if size > chunkSize {
			size = chunkSize
		}

		chunk := p[:size]
		p = p[size:]

		// Encrypt chunk
		chunkNonce := GenerateChunkNonce(w.nonce, w.counter)
		w.counter++

		encrypted := w.aead.Seal(nil, chunkNonce, chunk, nil)

		// Write length
		sizeBytes := w.parser.Encode(uint16(len(chunk)))
		if _, err := w.writer.Write(sizeBytes); err != nil {
			return total, err
		}

		// Write encrypted data
		if _, err := w.writer.Write(encrypted); err != nil {
			return total, err
		}

		total += size
	}

	return total, nil
}
