// Package nodus - FUSE filesystem for Nodus with P2P support
package nodus

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"syscall"
	"time"

	"bazil.org/fuse"
	"bazil.org/fuse/fs"
)

// NodusFS represents the FUSE filesystem
type NodusFS struct {
	mountPoint string
	conn       *fuse.Conn
	node       *Node
}

// MountFUSE mounts the Nodus filesystem at the given path
func MountFUSE(mountPoint string, node *Node) (*NodusFS, error) {
	// Create mount point if it doesn't exist
	if err := os.MkdirAll(mountPoint, 0755); err != nil {
		return nil, fmt.Errorf("failed to create mount point: %w", err)
	}

	// Mount FUSE
	c, err := fuse.Mount(
		mountPoint,
		fuse.FSName("nodus"),
		fuse.Subtype("spiritfs"),
		fuse.LocalVolume(),
		fuse.VolumeName("Nodus P2P"),
		fuse.AllowOther(),
	)
	if err != nil {
		return nil, fmt.Errorf("fuse mount failed: %w", err)
	}

	nfs := &NodusFS{
		mountPoint: mountPoint,
		conn:       c,
		node:       node,
	}

	// Serve filesystem in background
	go func() {
		if err := fs.Serve(c, nfs); err != nil {
			fmt.Printf("❌ FUSE serve error: %v\n", err)
		}
	}()

	// Wait for mount to be ready
	<-c.Ready
	if c.MountError != nil {
		return nil, c.MountError
	}

	return nfs, nil
}

// Unmount unmounts the filesystem
func (nfs *NodusFS) Unmount() error {
	return fuse.Unmount(nfs.mountPoint)
}

// Root returns the root directory node
func (nfs *NodusFS) Root() (fs.Node, error) {
	return &Dir{fs: nfs, path: "/", inode: 1}, nil
}

// Dir represents a directory in the filesystem
type Dir struct {
	fs    *NodusFS
	path  string
	inode uint64
}

// Attr sets the directory attributes
func (d *Dir) Attr(ctx context.Context, a *fuse.Attr) error {
	a.Inode = d.inode
	a.Mode = os.ModeDir | 0755
	a.Atime = time.Now()
	a.Mtime = time.Now()
	return nil
}

// Lookup looks up a child node
func (d *Dir) Lookup(ctx context.Context, name string) (fs.Node, error) {
	// Check cache first
	cache := d.fs.node.GetCache()
	if data := cache.Get(name); data != nil {
		return &File{fs: d.fs, name: name, data: data, inode: hashString(name)}, nil
	}

	// Request from P2P network
	data, err := d.fs.node.RequestFile(ctx, name)
	if err == nil && data != nil {
		// Cache the fetched data
		cache.Put(name, data)
		return &File{fs: d.fs, name: name, data: data, inode: hashString(name)}, nil
	}

	return nil, syscall.ENOENT
}

// ReadDirAll returns directory contents
func (d *Dir) ReadDirAll(ctx context.Context) ([]fuse.Dirent, error) {
	var entries []fuse.Dirent
	cache := d.fs.node.GetCache()
	for _, key := range cache.Keys() {
		entries = append(entries, fuse.Dirent{
			Inode: hashString(key),
			Name:  key,
			Type:  fuse.DT_File,
		})
	}
	return entries, nil
}

// Create creates a new file
func (d *Dir) Create(ctx context.Context, req *fuse.CreateRequest, resp *fuse.CreateResponse) (fs.Node, fs.Handle, error) {
	file := &File{
		fs:    d.fs,
		name:  req.Name,
		data:  []byte{},
		inode: hashString(req.Name),
	}

	d.fs.node.GetCache().Put(req.Name, file.data)
	resp.Flags = fuse.OpenDirectIO
	return file, file, nil
}

// Remove deletes a file
func (d *Dir) Remove(ctx context.Context, req *fuse.RemoveRequest) error {
	cache := d.fs.node.GetCache()
	if cache.Get(req.Name) == nil {
		return syscall.ENOENT
	}
	cache.Delete(req.Name)
	return nil
}

// File represents a file in the filesystem
type File struct {
	fs    *NodusFS
	name  string
	data  []byte
	inode uint64
}

// Attr sets file attributes
func (f *File) Attr(ctx context.Context, a *fuse.Attr) error {
	a.Inode = f.inode
	a.Mode = 0644
	a.Size = uint64(len(f.data))
	a.Atime = time.Now()
	a.Mtime = time.Now()
	return nil
}

// ReadAll reads the entire file
func (f *File) ReadAll(ctx context.Context) ([]byte, error) {
	if data := f.fs.node.GetCache().Get(f.name); data != nil {
		f.data = data
	}
	return f.data, nil
}

// Write writes data to the file
func (f *File) Write(ctx context.Context, req *fuse.WriteRequest, resp *fuse.WriteResponse) error {
	newLen := int(req.Offset) + len(req.Data)
	if newLen > len(f.data) {
		newData := make([]byte, newLen)
		copy(newData, f.data)
		f.data = newData
	}

	copy(f.data[req.Offset:], req.Data)
	resp.Size = len(req.Data)

	// Update cache and broadcast to peers
	f.fs.node.GetCache().Put(f.name, f.data)
	go f.fs.node.BroadcastFile(f.name, f.data)

	return nil
}

// Flush is called when file handle is closed
func (f *File) Flush(ctx context.Context, req *fuse.FlushRequest) error {
	f.fs.node.GetCache().Put(f.name, f.data)
	return nil
}

// Setattr handles attribute changes
func (f *File) Setattr(ctx context.Context, req *fuse.SetattrRequest, resp *fuse.SetattrResponse) error {
	if req.Valid.Size() {
		if req.Size < uint64(len(f.data)) {
			f.data = f.data[:req.Size]
		} else if req.Size > uint64(len(f.data)) {
			newData := make([]byte, req.Size)
			copy(newData, f.data)
			f.data = newData
		}
		f.fs.node.GetCache().Put(f.name, f.data)
	}
	return f.Attr(ctx, &resp.Attr)
}

// hashString creates a deterministic inode from filename
func hashString(s string) uint64 {
	h := sha256.Sum256([]byte(s))
	hex := hex.EncodeToString(h[:8])
	var result uint64
	fmt.Sscanf(hex, "%x", &result)
	return result
}
