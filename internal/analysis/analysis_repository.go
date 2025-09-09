package analysis

import (
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"time"
)

func GetTransactionsGroupedByCategory(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]CategorySummary, error) {
	var results []CategorySummary
	err := tx.Table("transactions t").
		Select("c.id as category_id,c.name as category_name, c.name as category_name, SUM(tc.amount * COALESCE(cer.rate, 1)) as total_amount").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Joins("LEFT JOIN currency_exchange_rates cer ON t.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("t.profile_id = ? AND t.date >= ? AND t.date <= ? AND t.type = 'expense'", profileId, startDate, endDate).
		Group("c.id, c.name").
		Order("total_amount DESC").
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetTransactionTotalExpense(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (decimal.Decimal, error) {
	var totalExpense decimal.Decimal
	err := tx.Table("transactions t").
		Select("SUM(tc.amount * COALESCE(cer.rate, 1)) as total_expense").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("LEFT JOIN currency_exchange_rates cer ON t.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("t.profile_id = ? AND t.date >= ? AND t.date <= ? AND t.type = 'expense'", profileId, startDate, endDate).
		Scan(&totalExpense).Error
	if err != nil {
		return decimal.Zero, err
	}
	return totalExpense, nil
}
