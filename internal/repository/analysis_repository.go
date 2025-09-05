package repository

import (
	"gorm.io/gorm"
	"time"
)

type CategorySummary struct {
	CategoryID   uint    `json:"category_id"`
	CategoryName string  `json:"category_name"`
	TotalAmount  float64 `json:"total_amount"`
}

func GetTransactionsGroupedByCategory(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]CategorySummary, error) {
	var results []CategorySummary
	err := tx.Table("transactions t").
		Select("c.id as category_id,c.name as category_name, c.name as category_name, SUM(tc.amount * COALESCE(cer.rate, 1)) as total_amount").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Joins("LEFT JOIN currency_exchange_rates cer ON t.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("t.profile_id = ? AND t.date >= ? AND t.date <= ? AND t.type = 'expense'", profileId, startDate, endDate).
		Group("c.id, c.name").
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetTransactionTotalExpense(tx *gorm.DB, profileId uint, startDate, endDate time.Time) (float64, error) {
	var totalExpense float64
	err := tx.Table("transactions t").
		Where("profile_id = ? AND date >= ? AND date <= ? AND type='expense'", profileId, startDate, endDate).
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Select("SUM(tc.amount)").Scan(&totalExpense).Error
	if err != nil {
		return 0, err
	}
	return totalExpense, nil
}
