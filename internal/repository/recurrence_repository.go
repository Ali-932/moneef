package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateTransactionRecurrent(tpl *models.RecurrenceTemplate) (uint, error) {
	log.Printf("🔄 [REPOSITORY] Creating recurrence template '%s' in database", tpl.Name)

	if err := db.DB.Create(tpl).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create recurrence template: %v", err)
		return 0, err
	}

	return tpl.ID, nil
}

func CreateTransactionRecurrentWithTx(tx *gorm.DB, tpl *models.RecurrenceTemplate) (uint, error) {
	log.Printf("🔄 [REPOSITORY] ENTRY: Creating recurrence template '%s' within database transaction", tpl.Name)

	if err := tx.Create(tpl).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create recurrence template in database: %v", err)
		return 0, err
	}

	return tpl.ID, nil
}
