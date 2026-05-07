package repository

import (
	"gorm.io/gorm"
	"moneef/internal/db"
	"moneef/internal/models"
)

func ListCategories(profileID uint) ([]models.Category, error) {
	var categories []models.Category
	err := db.DB.Where("profile_id IS NULL OR profile_id = ?", profileID).
		Order("profile_id ASC, name ASC").
		Find(&categories).Error
	return categories, err
}

func CreateCategory(category *models.Category) error {
	return db.DB.Create(category).Error
}

func GetCategoryByID(id uint, profileID uint) (*models.Category, error) {
	var category models.Category
	err := db.DB.Where("id = ? AND (profile_id = ? OR profile_id IS NULL)", id, profileID).
		First(&category).Error
	return &category, err
}

func UpdateCategory(tx *gorm.DB, id uint, profileID uint, updates map[string]interface{}) error {
	result := tx.Model(&models.Category{}).
		Where("id = ? AND profile_id = ?", id, profileID).
		Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
