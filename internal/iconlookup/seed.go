package iconlookup

import (
	"encoding/json"
	"fmt"
	"strings"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"moneef/internal/config"
	"moneef/internal/models"
)

// SeedDefaults adds missing keywords and preserves existing mappings. Running
// it on every launch also fills a partial database or installs new defaults
// after an app upgrade. No files or network requests are needed at runtime.
func SeedDefaults(database *gorm.DB) (int64, error) {
	var defaults []Entry
	if err := json.Unmarshal(config.MerchantIconsJSON, &defaults); err != nil {
		return 0, fmt.Errorf("decode bundled merchant icons: %w", err)
	}
	var keywords []string
	if err := database.Model(&models.IconLookup{}).Pluck("keyword", &keywords).Error; err != nil {
		return 0, err
	}
	existing := make(map[string]bool, len(keywords))
	for _, keyword := range keywords {
		existing[strings.ToLower(strings.TrimSpace(keyword))] = true
	}
	var missing []models.IconLookup
	for _, entry := range defaults {
		keyword := strings.ToLower(strings.TrimSpace(entry.Keyword))
		if keyword == "" || entry.Icon == "" || entry.Color == "" {
			return 0, fmt.Errorf("invalid bundled icon mapping for %q", entry.Keyword)
		}
		if !existing[keyword] {
			missing = append(missing, models.IconLookup{Keyword: keyword, Icon: entry.Icon, Color: entry.Color})
			existing[keyword] = true
		}
	}
	if len(missing) == 0 {
		return 0, nil
	}
	result := database.Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "keyword"}}, DoNothing: true,
	}).CreateInBatches(&missing, 100)
	return result.RowsAffected, result.Error
}
