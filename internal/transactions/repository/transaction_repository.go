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

func GetTransactionByID(db *gorm.DB, id uint, profileID uint) (*models.Transaction, error) {
	var transaction models.Transaction
	err := db.Preload("TransactionCategory.Category").
		Where("id = ? AND profile_id = ?", id, profileID).
		First(&transaction).Error
	if err != nil {
		return nil, err
	}
	return &transaction, nil
}

func ListTransactionsQuery(db *gorm.DB, profileID uint, txType string, categoryID uint, dateFrom, dateTo string, sort string) *gorm.DB {
	query := db.Model(&models.Transaction{}).
		Preload("TransactionCategory.Category").
		Where("profile_id = ?", profileID)

	if txType != "" {
		query = query.Where("type = ?", txType)
	}
	if categoryID != 0 {
		query = query.Joins("JOIN transaction_categories ON transaction_categories.transaction_id = transactions.id").
			Where("transaction_categories.category_id = ?", categoryID)
	}
	if dateFrom != "" {
		query = query.Where("date >= ?", dateFrom)
	}
	if dateTo != "" {
		query = query.Where("date <= ?", dateTo)
	}

	switch sort {
	case "date_asc":
		query = query.Order("date asc")
	case "amount_asc":
		query = query.Order("date asc")
	case "amount_desc":
		query = query.Order("date desc")
	default:
		query = query.Order("date desc")
	}

	return query
}

func UpdateTransaction(tx *gorm.DB, id uint, profileID uint, updates map[string]interface{}) error {
	result := tx.Model(&models.Transaction{}).
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

func ReplaceTransactionCategories(tx *gorm.DB, transactionID uint, categories []*models.TransactionCategory) error {
	if err := tx.Where("transaction_id = ?", transactionID).Delete(&models.TransactionCategory{}).Error; err != nil {
		return err
	}
	if len(categories) == 0 {
		return nil
	}
	return tx.Create(&categories).Error
}

func DeleteTransaction(tx *gorm.DB, id uint, profileID uint) error {
	result := tx.Where("id = ? AND profile_id = ?", id, profileID).Delete(&models.Transaction{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
