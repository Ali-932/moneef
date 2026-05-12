package cmd

import (
	"encoding/json"
	"fmt"
	"log"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/models"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

func SeedMerchants(cmd *cobra.Command, args []string) error {
	log.Printf("Seeding merchant icon lookups...")
	database := db.DB

	configPath := filepath.Join("internal", "config", "merchants.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", configPath, err)
	}

	var entries []struct {
		Keyword string `json:"keyword"`
		Icon    string `json:"icon"`
		Color   string `json:"color"`
	}
	if err := json.Unmarshal(data, &entries); err != nil {
		return fmt.Errorf("failed to parse merchants.json: %w", err)
	}

	created, skipped := 0, 0
	for _, entry := range entries {
		var count int64
		if err := database.Model(&models.IconLookup{}).Where("keyword = ?", entry.Keyword).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			skipped++
			continue
		}
		if err := database.Create(&models.IconLookup{
			Keyword: entry.Keyword,
			Icon:    entry.Icon,
			Color:   entry.Color,
		}).Error; err != nil {
			return fmt.Errorf("failed to create icon lookup for '%s': %w", entry.Keyword, err)
		}
		created++
	}

	// Rebuild the FTS index to include all rows (not just new ones)
	if err := database.Exec("INSERT INTO icon_lookups_fts(icon_lookups_fts) VALUES('rebuild')").Error; err != nil {
		log.Printf("⚠️ FTS rebuild failed (non-fatal): %v", err)
	}

	// Reload the in-memory cache
	if err := iconlookup.LoadCache(database); err != nil {
		log.Printf("⚠️ Failed to reload in-memory cache: %v", err)
	}

	log.Printf("Merchant icons seeded: %d created, %d skipped (already exist), %d in cache", created, skipped, iconlookup.GetCacheSize())
	return nil
}

var seedMerchantsCmd = &cobra.Command{
	Use:   "seed-merchants",
	Short: "Seeds the database with merchant icon lookup data from merchants.json",
	RunE:  SeedMerchants,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		database, err := db.Connect()
		if err != nil {
			return err
		}
		return db.MigrateModels(database)
	},
}

func init() {
	rootCmd.AddCommand(seedMerchantsCmd)
}
