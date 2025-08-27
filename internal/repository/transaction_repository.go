package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
)

func CreateTransaction(transaction *models.Transaction) error {
	log.Printf("💾 [REPOSITORY] Creating transaction '%s' in database", transaction.Name)
	if err := db.DB.Create(transaction).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create transaction: %v", err)
		return err
	}
	log.Printf("✅ [REPOSITORY] Transaction '%s' created with ID: %d", transaction.Name, transaction.ID)
	return nil
}

func CreateTransactionWithTx(tx *gorm.DB, transaction *models.Transaction) error {
	log.Printf("💾 [REPOSITORY] Creating transaction '%s' within database transaction", transaction.Name)

	if err := tx.Create(transaction).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create transaction in database: %v", err)
		return err
	}

	return nil
}
