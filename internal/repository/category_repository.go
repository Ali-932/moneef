package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

// GetCategoriesByIDs returns categories matching the given IDs.
func GetCategoriesByIDs(ids []uint) ([]*models.Category, error) {
	var categories []*models.Category
	if len(ids) == 0 {
		return categories, nil
	}
	result := db.DB.Where("id IN ?", ids).Find(&categories)
	if result.Error != nil {
		return nil, result.Error
	}
	return categories, nil
}
