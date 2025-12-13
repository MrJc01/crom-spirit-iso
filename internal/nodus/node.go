// Package nodus implements the Spirit distributed storage layer
package nodus

import (
	"context"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/multiformats/go-multiaddr"
)

const (
	// Protocol IDs for Nodus P2P
	ProtocolFileRequest   = protocol.ID("/spirit/nodus/file/1.0.0")
	ProtocolFileBroadcast = protocol.ID("/spirit/nodus/broadcast/1.0.0")
)

// Node represents a Nodus P2P node
type Node struct {
	host  host.Host
	dht   *dht.IpfsDHT
	cache *Cache
	mu    sync.RWMutex

	peers map[peer.ID]peer.AddrInfo
}

// NewNode creates a new libp2p node
func NewNode(ctx context.Context) (*Node, error) {
	// Create libp2p host with default options
	h, err := libp2p.New(
		libp2p.ListenAddrStrings(
			"/ip4/0.0.0.0/tcp/4001",
			"/ip4/0.0.0.0/udp/4001/quic-v1",
		),
		libp2p.EnableNATService(),
		libp2p.EnableRelay(),
		libp2p.EnableHolePunching(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create host: %w", err)
	}

	// Create DHT for peer discovery
	kadDHT, err := dht.New(ctx, h, dht.Mode(dht.ModeAutoServer))
	if err != nil {
		h.Close()
		return nil, fmt.Errorf("failed to create DHT: %w", err)
	}

	// Bootstrap the DHT
	if err := kadDHT.Bootstrap(ctx); err != nil {
		h.Close()
		return nil, fmt.Errorf("failed to bootstrap DHT: %w", err)
	}

	node := &Node{
		host:  h,
		dht:   kadDHT,
		cache: NewCache(256 * 1024 * 1024), // 256MB RAM cache
		peers: make(map[peer.ID]peer.AddrInfo),
	}

	// Set up protocol handlers
	h.SetStreamHandler(ProtocolFileRequest, node.handleFileRequest)
	h.SetStreamHandler(ProtocolFileBroadcast, node.handleFileBroadcast)

	return node, nil
}

// ID returns the node's peer ID
func (n *Node) ID() string {
	return n.host.ID().String()
}

// Addrs returns the node's listening addresses
func (n *Node) Addrs() []multiaddr.Multiaddr {
	return n.host.Addrs()
}

// Close shuts down the node
func (n *Node) Close() error {
	n.dht.Close()
	return n.host.Close()
}

// ConnectedPeers returns the list of connected peer IDs
func (n *Node) ConnectedPeers() []peer.ID {
	return n.host.Network().Peers()
}

// GetCache returns the node's cache
func (n *Node) GetCache() *Cache {
	return n.cache
}

// RequestFile requests a file from connected peers
func (n *Node) RequestFile(ctx context.Context, filename string) ([]byte, error) {
	peers := n.ConnectedPeers()
	if len(peers) == 0 {
		return nil, fmt.Errorf("no peers connected")
	}

	// Try each peer until we get the file
	for _, peerID := range peers {
		data, err := n.requestFileFromPeer(ctx, peerID, filename)
		if err == nil && len(data) > 0 {
			fmt.Printf("📥 File '%s' received from peer %s\n", filename, peerID.ShortString())
			return data, nil
		}
	}

	return nil, fmt.Errorf("file not found on any peer")
}

// requestFileFromPeer requests a specific file from a peer
func (n *Node) requestFileFromPeer(ctx context.Context, peerID peer.ID, filename string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	stream, err := n.host.NewStream(ctx, peerID, ProtocolFileRequest)
	if err != nil {
		return nil, err
	}
	defer stream.Close()

	// Send filename request
	_, err = stream.Write([]byte(filename + "\n"))
	if err != nil {
		return nil, err
	}

	// Read response
	data, err := io.ReadAll(stream)
	if err != nil {
		return nil, err
	}

	return data, nil
}

// handleFileRequest handles incoming file requests from peers
func (n *Node) handleFileRequest(stream network.Stream) {
	defer stream.Close()

	// Read filename
	buf := make([]byte, 1024)
	nBytes, err := stream.Read(buf)
	if err != nil {
		return
	}

	filename := string(buf[:nBytes-1]) // Remove newline

	// Check cache
	data := n.cache.Get(filename)
	if data == nil {
		// File not found
		return
	}

	// Send file data
	stream.Write(data)
	fmt.Printf("📤 File '%s' sent to peer %s\n", filename, stream.Conn().RemotePeer().ShortString())
}

// BroadcastFile broadcasts a file to all connected peers
func (n *Node) BroadcastFile(filename string, data []byte) {
	peers := n.ConnectedPeers()
	for _, peerID := range peers {
		go n.sendFileToPeer(peerID, filename, data)
	}
}

// sendFileToPeer sends a file to a specific peer
func (n *Node) sendFileToPeer(peerID peer.ID, filename string, data []byte) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	stream, err := n.host.NewStream(ctx, peerID, ProtocolFileBroadcast)
	if err != nil {
		return
	}
	defer stream.Close()

	// Send filename + data
	header := fmt.Sprintf("%s\n%d\n", filename, len(data))
	stream.Write([]byte(header))
	stream.Write(data)
}

// handleFileBroadcast handles incoming file broadcasts from peers
func (n *Node) handleFileBroadcast(stream network.Stream) {
	defer stream.Close()

	// Read header (filename + size)
	buf := make([]byte, 1024)
	nBytes, err := stream.Read(buf)
	if err != nil {
		return
	}

	// Parse header
	var filename string
	var size int
	fmt.Sscanf(string(buf[:nBytes]), "%s\n%d\n", &filename, &size)

	// Read file data
	data := make([]byte, size)
	io.ReadFull(stream, data)

	// Store in cache
	n.cache.Put(filename, data)
	fmt.Printf("📥 Received broadcast: '%s' (%d bytes) from %s\n", filename, size, stream.Conn().RemotePeer().ShortString())
}
