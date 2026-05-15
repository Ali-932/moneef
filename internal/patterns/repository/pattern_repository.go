package repository

import (
	"encoding/json"
	"fmt"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
		patterns[i].ProfileID = profileID
		if err := marshalMetadata(&patterns[i]); err != nil {
			return nil, err
		}
	}
	if len(patterns) == 0 {
		return patterns, nil
	}
	err := tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "profile_id"}, {Name: "name"}, {Name: "type"}},
		DoUpdates: clause.AssignmentColumns([]string{"description", "metadata", "icon", "color", "final_score", "updated_at"}),
	}).Create(&patterns).Error
	return patterns, err
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
