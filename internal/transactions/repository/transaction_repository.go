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
	err := db.Preload("TransactionCategory.Category", models.WithDeleted).
		Where("id = ? AND profile_id = ?", id, profileID).
		First(&transaction).Error
	if err != nil {
		return nil, err
	}
	return &transaction, nil
}

func ListTransactionsQuery(db *gorm.DB, profileID uint, txType string, categoryID uint, dateFrom, dateTo, search, categoryName, sort string) *gorm.DB {
	query := db.Model(&models.Transaction{}).
		Preload("TransactionCategory.Category", models.WithDeleted).
		Where("transactions.profile_id = ?", profileID)

	if txType != "" {
		query = query.Where("transactions.type = ?", txType)
	}
	if categoryID != 0 {
		query = query.Joins("JOIN transaction_categories ON transaction_categories.transaction_id = transactions.id").
			Where("transaction_categories.category_id = ?", categoryID)
	}
	if categoryName != "" {
		query = query.Joins("JOIN transaction_categories tc2 ON tc2.transaction_id = transactions.id").
			Joins("JOIN categories c2 ON tc2.category_id = c2.id").
			Where("c2.name = ?", categoryName)
	}
	if dateFrom != "" {
		query = query.Where("transactions.date >= ?", dateFrom)
	}
	if dateTo != "" {
		query = query.Where("transactions.date <= ?", dateTo)
	}
	if search != "" {
		like := "%" + search + "%"
		query = query.Where("transactions.name LIKE ? OR transactions.merchant_name LIKE ?", like, like)
	}

	switch sort {
	case "date":
		query = query.Order("transactions.date asc")
	case "amount":
		query = query.
			Joins("LEFT JOIN transaction_categories tc_sort ON tc_sort.transaction_id = transactions.id").
			Group("transactions.id").
			Order("SUM(tc_sort.amount) ASC")
	case "-amount":
		query = query.
			Joins("LEFT JOIN transaction_categories tc_sort ON tc_sort.transaction_id = transactions.id").
			Group("transactions.id").
			Order("SUM(tc_sort.amount) DESC")
	default:
		query = query.Order("transactions.date desc")
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
