package iconlookup

import (
	"log"
	"moneef/internal/models"
	"sort"
	"strings"
	"sync"

	"gorm.io/gorm"
)

type Entry struct {
	Keyword string
	Icon    string
	Color   string
}

var (
	cache   []Entry
	cacheMu sync.RWMutex
)

// LoadCache loads all IconLookup rows into memory.
// Call this on startup and after seeding.
func LoadCache(database *gorm.DB) error {
	var lookups []models.IconLookup
	if err := database.Find(&lookups).Error; err != nil {
		return err
	}

	entries := make([]Entry, 0, len(lookups))
	for _, lk := range lookups {
		entries = append(entries, Entry{
			Keyword: strings.ToLower(lk.Keyword),
			Icon:    lk.Icon,
			Color:   lk.Color,
		})
	}

	// Sort by keyword length descending so longer/more specific matches win
	sort.SliceStable(entries, func(i, j int) bool {
		return len(entries[i].Keyword) > len(entries[j].Keyword)
	})

	cacheMu.Lock()
	cache = entries
	cacheMu.Unlock()

	log.Printf("🏁 [IconLookup] Loaded %d keyword entries into memory", len(entries))
	return nil
}

// Lookup finds the first keyword that is a substring of the given text.
// Text is lowercased before matching. Returns (icon, color, found).
// Priority: longest matching keyword wins (since cache is sorted by
// keyword length descending).
func Lookup(text string) (icon string, color string, found bool) {
	lower := strings.ToLower(text)

	cacheMu.RLock()
	defer cacheMu.RUnlock()

	for _, entry := range cache {
		if strings.Contains(lower, entry.Keyword) {
			return entry.Icon, entry.Color, true
		}
	}

	return "", "", false
}

// GetCacheSize returns the number of entries currently loaded.
func GetCacheSize() int {
	cacheMu.RLock()
	defer cacheMu.RUnlock()
	return len(cache)
}
