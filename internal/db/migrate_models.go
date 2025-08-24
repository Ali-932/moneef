package db

import (
	"fmt"
	"goMangaObserver/internal/models"
	"gorm.io/gorm"
)

func MigrateModels(database *gorm.DB) error {
	if err := database.AutoMigrate(&models.User{}); err != nil {
		return fmt.Errorf("failed to migrate User model: %w", err)
	}

	if err := database.AutoMigrate(&models.UserSettings{}); err != nil {
		return fmt.Errorf("failed to migrate UserSettings model: %w", err)
	}

	if err := database.AutoMigrate(&models.Transaction{}); err != nil {
		return fmt.Errorf("failed to migrate Transaction model: %w", err)
	}

	if err := database.AutoMigrate(&models.Profile{}); err != nil {
		return fmt.Errorf("Faild to migrate Profile model: %w", err)
	}

	if err := database.AutoMigrate(&models.Category{}); err != nil {
		return fmt.Errorf("Faild to migrate Category model: %w", err)
	}

	if err := DB.AutoMigrate(&models.Pattern{}); err != nil {
		return fmt.Errorf("Faild to migrate Pattern model: %w", err)
	}

	return nil
}
