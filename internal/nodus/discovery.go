// Package nodus - Peer discovery via mDNS (LAN) and DHT
package nodus

import (
	"context"
	"fmt"
	"time"

	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns"
)

const (
	// DiscoveryServiceTag is used for mDNS discovery
	DiscoveryServiceTag = "spirit-nodus"
)

// discoveryNotifee handles discovered peers
type discoveryNotifee struct {
	node *Node
}

func (n *discoveryNotifee) HandlePeerFound(pi peer.AddrInfo) {
	fmt.Printf("📡 Discovered peer: %s\n", pi.ID.ShortString())

	// Try to connect
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := n.node.host.Connect(ctx, pi); err != nil {
		fmt.Printf("⚠️  Failed to connect to %s: %v\n", pi.ID.ShortString(), err)
	} else {
		fmt.Printf("✅ Connected to %s\n", pi.ID.ShortString())
		n.node.mu.Lock()
		n.node.peers[pi.ID] = pi
		n.node.mu.Unlock()
	}
}

// StartDiscovery starts both mDNS (LAN) and DHT discovery
func (n *Node) StartDiscovery(ctx context.Context) {
	// mDNS for local network discovery
	mdnsService := mdns.NewMdnsService(n.host, DiscoveryServiceTag, &discoveryNotifee{node: n})
	if err := mdnsService.Start(); err != nil {
		fmt.Printf("⚠️  mDNS service failed: %v\n", err)
	} else {
		fmt.Println("📡 mDNS discovery started (LAN)")
	}

	// Periodic peer count report
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			peers := n.ConnectedPeers()
			fmt.Printf("📊 Connected peers: %d\n", len(peers))
		}
	}
}

// ConnectToPeer manually connects to a peer by multiaddr
func (n *Node) ConnectToPeer(ctx context.Context, addr string) error {
	maddr, err := peer.AddrInfoFromString(addr)
	if err != nil {
		return fmt.Errorf("invalid address: %w", err)
	}

	if err := n.host.Connect(ctx, *maddr); err != nil {
		return fmt.Errorf("connection failed: %w", err)
	}

	n.mu.Lock()
	n.peers[maddr.ID] = *maddr
	n.mu.Unlock()

	return nil
}
