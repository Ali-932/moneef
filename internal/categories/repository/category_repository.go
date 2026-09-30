package repository

import (
	"moneef/internal/db"
	"moneef/internal/models"

	"gorm.io/gorm"
)

func ListCategories(profileID uint, catType string, custom bool, used bool) ([]models.Category, error) {
	var categories []models.Category
	query := db.DB.Where("profile_id IS NULL OR profile_id = ?", profileID)

	if catType != "" {
		query = query.Where("type = ?", catType)
	}
	if custom {
		query = query.Where("profile_id IS NOT NULL")
	}
	if used {
		query = query.Where("id IN (SELECT DISTINCT tc.category_id FROM transaction_categories tc JOIN transactions t ON t.id = tc.transaction_id WHERE t.profile_id = ?)", profileID)
	}

	err := query.Order("profile_id ASC, name ASC").Find(&categories).Error
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

func DeleteCategory(id uint, profileID uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).Delete(&models.Category{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// ExistsByName reports whether another category of the same type already uses name.
func ExistsByName(profileID uint, name string, catType *string, excludeID uint) (bool, error) {
	var count int64
	err := db.DB.Model(&models.Category{}).
		Where("(profile_id = ? OR profile_id IS NULL) AND name = ? AND type IS ? AND id <> ?", profileID, name, catType, excludeID).
		Count(&count).Error
	return count > 0, err
}
