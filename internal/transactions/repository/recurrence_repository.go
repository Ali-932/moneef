package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
	"time"
)

func CreateTransactionRecurrent(tx *gorm.DB, tpl *models.RecurrenceTemplate) (uint, error) {
	log.Printf("🔄 [REPOSITORY] ENTRY: Creating recurrence template '%s' within database transaction", tpl.Name)

	if err := tx.Create(tpl).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create recurrence template in database: %v", err)
		return 0, err
	}

	return tpl.ID, nil
}

func CreateTransactionCategoryRecurrentBulk(tx *gorm.DB, transactionCategories []*models.RecurrenceTemplateCategory) error {
	log.Printf("💾 [REPOSITORY] Creating %d transaction-category associations in bulk", len(transactionCategories))

	if len(transactionCategories) == 0 {
		log.Println("💾 [REPOSITORY] No transaction-category associations to create, skipping")
		return nil
	}

	if err := tx.Create(&transactionCategories).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create transaction-category associations in database: %v", err)
		return err
	}

	return nil
}

func ListRecurrenceTemplates(profileID uint) ([]models.RecurrenceTemplate, error) {
	var list []models.RecurrenceTemplate
	err := db.DB.
		Preload("TransactionCategory.Category", models.WithDeleted).
		Where("profile_id = ?", profileID).
		Order("next_date ASC").
		Find(&list).Error
	return list, err
}

func UpdateRecurrenceTemplate(profileID uint, id uint, updates map[string]interface{}) error {
	result := db.DB.Model(&models.RecurrenceTemplate{}).
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

func DeleteRecurrenceTemplate(profileID uint, id uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).
		Delete(&models.RecurrenceTemplate{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func GetActiveRecurrenceTemplatesForProfile(profileID uint, monthStart time.Time) ([]models.RecurrenceTemplate, error) {
	var list []models.RecurrenceTemplate
	err := db.DB.
		Where("profile_id = ? AND is_active = true", profileID).
		Where("has_end_date = false OR (has_end_date = true AND end_date >= ?)", monthStart).
		Find(&list).Error
	return list, err
}
