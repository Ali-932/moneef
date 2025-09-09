package transactions

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
