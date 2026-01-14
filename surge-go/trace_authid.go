package main

import (
	"crypto/aes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"hash/crc32"
	"time"
)

func main() {
	uuid, _ := hex.DecodeString("5eb7ee194ef7446b8d2345d066264afc")
	salt := []byte("AES Auth ID Encryption")
	h := hmac.New(sha256.New, salt)
	h.Write(uuid)
	key := h.Sum(nil)[:16]
	fmt.Printf("Derived Key: %x\n", key)

	block, _ := aes.NewCipher(key)
	authID, _ := hex.DecodeString("b285b7d8d2f76cf6c58c8a3667ec80b4")
	packet := make([]byte, 16)
	block.Decrypt(packet, authID)

	ts := binary.BigEndian.Uint32(packet[0:4])
	fmt.Printf("Decrypted Time: %d (%v)\n", ts, time.Unix(int64(ts), 0))
	fmt.Printf("Packet: %x\n", packet)

	checksum := crc32.ChecksumIEEE(packet[0:8])
	fmt.Printf("Expected Checksum: %x, Got: %x\n", checksum, binary.BigEndian.Uint32(packet[8:12]))

	xor := packet[0] ^ packet[4] ^ packet[8]
	fmt.Printf("Expected XOR[0]: %x, Got: %x\n", xor, packet[12])
}
