package db

import (
	"fmt"
	"gorm.io/gorm"
	"log"
	"moneef/internal/models"
	"reflect"
)

func MigrateModels(database *gorm.DB) error {
	modelsToMigrate := []interface{}{
		&models.User{},
		&models.UserSettings{},
		&models.Profile{},
		&models.Category{},
		&models.Transaction{},
		&models.TransactionCategory{},
		&models.Pattern{},
		&models.Currency{},
		&models.RecurrenceTemplate{},
		&models.RecurrenceTemplateCategory{},
		&models.Currency{},
		&models.CurrencyExchangeRate{},
		&models.IconLookup{},
	}

	for _, model := range modelsToMigrate {
		if err := database.AutoMigrate(model); err != nil {
			modelName := reflect.TypeOf(model).Elem().Name()
			return fmt.Errorf("failed to migrate %s model: %w", modelName, err)
		}
	}

	// Create FTS5 virtual table for fast keyword search (optional — not all SQLite builds include FTS5)
	ftsErr := database.Exec(`
		CREATE VIRTUAL TABLE IF NOT EXISTS icon_lookups_fts
		USING fts5(keyword, icon, color, content=icon_lookups, content_rowid=id)
	`).Error
	if ftsErr != nil {
		// FTS5 not available — icon lookup will still work via in-memory cache
		log.Printf("⚠️ FTS5 not available, icon_lookup FTS table skipped (non-fatal): %v", ftsErr)
	} else {
		// Create triggers to keep FTS in sync with icon_lookups
		triggers := []string{
			`CREATE TRIGGER IF NOT EXISTS icon_lookups_ai AFTER INSERT ON icon_lookups BEGIN
				INSERT INTO icon_lookups_fts(rowid, keyword, icon, color) VALUES (new.id, new.keyword, new.icon, new.color);
			END`,
			`CREATE TRIGGER IF NOT EXISTS icon_lookups_ad AFTER DELETE ON icon_lookups BEGIN
				INSERT INTO icon_lookups_fts(icon_lookups_fts, rowid, keyword, icon, color) VALUES('delete', old.id, old.keyword, old.icon, old.color);
			END`,
			`CREATE TRIGGER IF NOT EXISTS icon_lookups_au AFTER UPDATE ON icon_lookups BEGIN
				INSERT INTO icon_lookups_fts(icon_lookups_fts, rowid, keyword, icon, color) VALUES('delete', old.id, old.keyword, old.icon, old.color);
				INSERT INTO icon_lookups_fts(rowid, keyword, icon, color) VALUES (new.id, new.keyword, new.icon, new.color);
			END`,
		}
		for _, trigger := range triggers {
			if err := database.Exec(trigger).Error; err != nil {
				return fmt.Errorf("failed to create FTS trigger: %w", err)
			}
		}
	}

	return nil
}
