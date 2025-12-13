// Package nodus - LRU Cache for hot data
package nodus

import (
	"container/list"
	"sync"
)

// Cache is a thread-safe LRU cache
type Cache struct {
	mu       sync.RWMutex
	capacity int64 // max bytes
	used     int64 // current bytes used
	items    map[string]*list.Element
	order    *list.List
}

type cacheEntry struct {
	key  string
	data []byte
}

// NewCache creates a new LRU cache with the given capacity in bytes
func NewCache(capacity int64) *Cache {
	return &Cache{
		capacity: capacity,
		items:    make(map[string]*list.Element),
		order:    list.New(),
	}
}

// Get retrieves an item from cache (nil if not found)
func (c *Cache) Get(key string) []byte {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, ok := c.items[key]; ok {
		// Move to front (most recently used)
		c.order.MoveToFront(elem)
		return elem.Value.(*cacheEntry).data
	}
	return nil
}

// Put adds an item to cache, evicting old entries if necessary
func (c *Cache) Put(key string, data []byte) {
	c.mu.Lock()
	defer c.mu.Unlock()

	dataSize := int64(len(data))

	// If item already exists, update it
	if elem, ok := c.items[key]; ok {
		oldEntry := elem.Value.(*cacheEntry)
		c.used -= int64(len(oldEntry.data))
		oldEntry.data = data
		c.used += dataSize
		c.order.MoveToFront(elem)
		return
	}

	// Evict until we have space
	for c.used+dataSize > c.capacity && c.order.Len() > 0 {
		c.evictOldest()
	}

	// Add new entry
	entry := &cacheEntry{key: key, data: data}
	elem := c.order.PushFront(entry)
	c.items[key] = elem
	c.used += dataSize
}

// evictOldest removes the least recently used item
func (c *Cache) evictOldest() {
	oldest := c.order.Back()
	if oldest == nil {
		return
	}

	entry := oldest.Value.(*cacheEntry)
	c.order.Remove(oldest)
	delete(c.items, entry.key)
	c.used -= int64(len(entry.data))
}

// Delete removes a specific key from cache
func (c *Cache) Delete(key string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	elem, ok := c.items[key]
	if !ok {
		return false
	}

	entry := elem.Value.(*cacheEntry)
	c.order.Remove(elem)
	delete(c.items, key)
	c.used -= int64(len(entry.data))
	return true
}

// Keys returns all cached keys
func (c *Cache) Keys() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	keys := make([]string, 0, len(c.items))
	for k := range c.items {
		keys = append(keys, k)
	}
	return keys
}

// Size returns current cache usage in bytes
func (c *Cache) Size() int64 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.used
}

// Count returns number of items in cache
func (c *Cache) Count() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.items)
}

// Capacity returns max cache capacity
func (c *Cache) Capacity() int64 {
	return c.capacity
}

// Clear empties the cache
func (c *Cache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.items = make(map[string]*list.Element)
	c.order = list.New()
	c.used = 0
}
