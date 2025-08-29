package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/models"
)

func CreateTransactionRecurrent(tx *gorm.DB, tpl *models.RecurrenceTemplate) (uint, error) {
	log.Printf("🔄 [REPOSITORY] ENTRY: Creating recurrence template '%s' within database transaction", tpl.Name)

	if err := tx.Create(tpl).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create recurrence template in database: %v", err)
		return 0, err
	}

	return tpl.ID, nil
}
