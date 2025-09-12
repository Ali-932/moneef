package repository

import (
	"gorm.io/gorm"
	"log"
	"moneef/internal/models"
)

func CreateTransaction(tx *gorm.DB, transaction *models.Transaction) (*uint, error) {
	log.Printf("💾 [REPOSITORY] Creating transaction '%s' within database transaction", transaction.Name)

	if err := tx.Create(transaction).Error; err != nil {
		log.Printf("❌ [REPOSITORY] Failed to create transaction in database: %v", err)
		return nil, err
	}

	return &transaction.ID, nil
}

func CreateTransactionCategoryBulk(tx *gorm.DB, transactionCategories []*models.TransactionCategory) error {
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
