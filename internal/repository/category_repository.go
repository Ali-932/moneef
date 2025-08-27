package repository

import (
	"fmt"
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
)

func GetCategoriesByIDs(ids []uint) ([]*models.Category, error) {
	log.Printf("🏷️ [REPOSITORY] Fetching categories by IDs: %v", ids)

	var categories []*models.Category
	if len(ids) == 0 {
		log.Println("🏷️ [REPOSITORY] No category IDs provided, returning empty list")
		return categories, nil
	}

	result := db.DB.Where("id IN ?", ids).Find(&categories)
	if result.Error != nil {
		log.Printf("❌ [REPOSITORY] Failed to fetch categories: %v", result.Error)
		return nil, result.Error
	}

	if len(categories) != len(ids) {
		log.Printf("⚠️ [REPOSITORY] invalid id for the categories")
		return nil, fmt.Errorf("invalid id for the categories")
	}

	return categories, nil
}
