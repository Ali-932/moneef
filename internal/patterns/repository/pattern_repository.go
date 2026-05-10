package repository

import (
	"encoding/json"
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
	for i := range patterns {
		if err := marshalMetadata(&patterns[i]); err != nil {
			return err
		}
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

func UpsertPatterns(tx *gorm.DB, profileID uint, patterns []models.Pattern) ([]models.Pattern, error) {
	for i := range patterns {
		patterns[i].ProfileID = &profileID
		if err := marshalMetadata(&patterns[i]); err != nil {
			return nil, err
		}
	}

	newKeys := make([]string, 0, len(patterns))
	for _, p := range patterns {
		newKeys = append(newKeys, fmt.Sprintf("%s|%s", p.Name, p.Type))
	}

	if len(newKeys) > 0 {
		if err := tx.Where("profile_id = ?", profileID).
			Where("name || '|' || type NOT IN ?", newKeys).
			Delete(&models.Pattern{}).Error; err != nil {
			return nil, fmt.Errorf("failed to prune old patterns: %w", err)
		}
	}

	var result []models.Pattern
	for _, p := range patterns {
		var existing models.Pattern
		err := tx.Where("profile_id = ? AND name = ? AND type = ? AND deleted_at IS NULL", profileID, p.Name, p.Type).
			First(&existing).Error
		if err == nil {
			existing.Description = p.Description
			existing.Metadata = p.Metadata
			existing.Icon = p.Icon
			existing.Color = p.Color
			existing.Type = p.Type
			existing.FinalScore = p.FinalScore
			if err := tx.Save(&existing).Error; err != nil {
				return nil, fmt.Errorf("failed to update pattern %s: %w", p.Name, err)
			}
			result = append(result, existing)
		} else {
			if err := tx.Create(&p).Error; err != nil {
				return nil, fmt.Errorf("failed to create pattern %s: %w", p.Name, err)
			}
			result = append(result, p)
		}
	}
	return result, nil
}

func marshalMetadata(p *models.Pattern) error {
	if p.Metadata == nil {
		return nil
	}
	if _, ok := p.Metadata.(json.RawMessage); ok {
		return nil
	}
	b, err := json.Marshal(p.Metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata for pattern %s: %w", p.Name, err)
	}
	p.Metadata = json.RawMessage(b)
	return nil
}
