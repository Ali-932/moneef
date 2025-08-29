package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/models"
)

func CreateTransaction(tx *gorm.DB, transaction *models.Transaction) error {
	log.Printf("💾 [REPOSITORY] Creating transaction '%s' within database transaction", transaction.Name)

	if err := tx.Create(transaction).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create transaction in database: %v", err)
		return err
	}

	return nil
}
