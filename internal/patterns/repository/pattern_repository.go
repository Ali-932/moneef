package repository

import (
	"fmt"
	"gorm.io/gorm"
	"moneef/internal/models"
)

func DeleteUserPatterns(tx *gorm.DB, profileID uint) error {
	return tx.Where("profile_id = ?", profileID).Delete(&models.Pattern{}).Error
}

func CreatePatterns(tx *gorm.DB, patterns []models.Pattern) error {
	if len(patterns) == 0 {
		return nil
	}
	return tx.Create(&patterns).Error
}

func GetPatternsByProfileID(tx *gorm.DB, profileID uint) ([]models.Pattern, error) {
	var patterns []models.Pattern
	err := tx.Where("profile_id = ?", profileID).Order("final_score DESC").Find(&patterns).Error
	if err != nil {
		return nil, err
	}
	return patterns, nil
}

// UpsertPatterns updates existing patterns, creates new ones, and soft-deletes ones that disappeared.
func UpsertPatterns(tx *gorm.DB, profileID uint, patterns []models.Pattern) error {
	for i := range patterns {
		patterns[i].ProfileID = &profileID
	}

	// 1. Gather keys of the new patterns
	newKeys := make([]string, 0, len(patterns))
	for _, p := range patterns {
		newKeys = append(newKeys, fmt.Sprintf("%s|%s", p.Name, p.Type))
	}

	// 2. Soft-delete patterns that are no longer present
	if len(newKeys) > 0 {
		// Build a raw condition because GORM doesn't support NOT IN with string concatenation easily
		if err := tx.Where("profile_id = ?", profileID).
			Where("name || '|' || type NOT IN ?", newKeys).
			Delete(&models.Pattern{}).Error; err != nil {
			return fmt.Errorf("failed to prune old patterns: %w", err)
		}
	}

	// 3. Upsert: update existing, create new
	for _, p := range patterns {
		var existing models.Pattern
		err := tx.Where("profile_id = ? AND name = ? AND type = ? AND deleted_at IS NULL", profileID, p.Name, p.Type).
			First(&existing).Error
		if err == nil {
			existing.Description = p.Description
			existing.Metadata = p.Metadata
			existing.Icon = p.Icon
			existing.Color = p.Color
			existing.FinalScore = p.FinalScore
			if err := tx.Save(&existing).Error; err != nil {
				return fmt.Errorf("failed to update pattern %s: %w", p.Name, err)
			}
		} else {
			if err := tx.Create(&p).Error; err != nil {
				return fmt.Errorf("failed to create pattern %s: %w", p.Name, err)
			}
		}
	}
	return nil
}
