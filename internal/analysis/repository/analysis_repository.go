package repository

import (
	"gorm.io/gorm"
	"moneef/internal/analysis/dto"
	"moneef/internal/config"
	"moneef/internal/models"
	"moneef/pkg/types"
	"time"
)

func GetTransactionsGroupedByCategory(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]dto.CategorySummary, error) {
	var results []dto.CategorySummary
	err := tx.Model(&models.Transaction{}).
		Select("c.id as category_id, c.name as category_name, c.icon as icon, c.color as color, SUM(tc.amount * COALESCE(cer.rate, 1)) as total_amount").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND tc.deleted_at IS NULL", profileId, startDate, endDate).
		Group("c.id, c.name, c.icon, c.color").
		Order("total_amount DESC").
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetTransactionTotalExpense(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (types.Money, error) {
	var totalExpense types.Money
	err := tx.Model(&models.Transaction{}).
		Select("COALESCE(SUM(tc.amount * COALESCE(cer.rate, 1)),0) as total_expense").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND tc.deleted_at IS NULL", profileId, startDate, endDate).
		Scan(&totalExpense).Error
	if err != nil {
		return types.MoneyZero(), err
	}
	return totalExpense, nil
}

func GetTransactionsAmountPerDay(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]dto.AmountPerDay, error) {
	var results []dto.AmountPerDay
	err := tx.Model(&models.Transaction{}).
		Select("transactions.date as date, SUM(tc.amount * COALESCE(cer.rate, 1)) as amount").
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("LEFT JOIN currency_exchange_rates cer ON transactions.currency_code = cer.currency_code1 AND cer.currency_code2 = (Select code FROM currencies WHERE code = ?)", baseCurrency).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND tc.deleted_at IS NULL", profileId, startDate, endDate).
		Group("transactions.date").
		Order("transactions.date ASC").
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetNextRecurringTransactions(tx *gorm.DB, profileId uint, currentDate time.Time) ([]dto.NextRecurringTransactions, error) {
	endDate := currentDate.AddDate(0, 1, 0)
	result := make([]dto.NextRecurringTransactions, 0)
	err := tx.Model(&models.RecurrenceTemplate{}).
		Select("next_date as date, next_payment_amount as amount, name as name").
		Where("is_active = true AND type='expense' AND profile_id = ? AND ((next_date >= ? AND next_date <= ?) OR (has_end_date=false))", profileId, currentDate, endDate).
		Order("next_date").
		Limit(config.AnalysisMaxRecurringTransactionsCHart).
		Scan(&result).Error
	if err != nil {
		return nil, err
	}
	return result, nil
}
