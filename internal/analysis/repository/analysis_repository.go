package repository

import (
	"fmt"
	"gorm.io/gorm"
	"moneef/internal/analysis/dto"
	"moneef/internal/config"
	"moneef/internal/models"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"time"
)

func GetTransactionsGroupedByCategory(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]dto.CategorySummary, error) {
	var results []dto.CategorySummary
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("c.id as category_id, c.name as category_name, c.icon as icon, c.color as color, SUM(%s) as total_amount", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense'", profileId, startDate, endDate).
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
		Select(fmt.Sprintf("COALESCE(SUM(%s),0) as total_expense", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense'", profileId, startDate, endDate).
		Scan(&totalExpense).Error
	if err != nil {
		return types.MoneyZero(), err
	}
	return totalExpense, nil
}

func GetTransactionsAmountPerDay(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) ([]dto.AmountPerDay, error) {
	var results []dto.AmountPerDay
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("transactions.date as date, SUM(%s) as amount", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense'", profileId, startDate, endDate).
		Group("transactions.date").
		Order("transactions.date ASC").
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetNextRecurringTransactions(tx *gorm.DB, profileId uint, currentDate time.Time, baseCurrency string) ([]dto.NextRecurringTransactions, error) {
	endDate := currentDate.AddDate(0, 1, 0)
	result := make([]dto.NextRecurringTransactions, 0)
	err := tx.Model(&models.RecurrenceTemplate{}).
		Select(fmt.Sprintf("next_date as date, %s as amount, name as name", utils.ConvertedAmount("next_payment_amount"))).
		Scopes(utils.WithCurrencyConversion("recurrence_templates", baseCurrency)).
		Where("is_active = true AND type='expense' AND profile_id = ? AND ((next_date >= ? AND next_date <= ?) OR (has_end_date=false))", profileId, currentDate, endDate).
		Order("next_date").
		Limit(config.AnalysisMaxRecurringTransactionsCHart).
		Scan(&result).Error
	if err != nil {
		return nil, err
	}
	return result, nil
}

func GetTotalIncome(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (types.Money, error) {
	var totalIncome types.Money
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("COALESCE(SUM(%s),0) as total_income", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'income'", profileId, startDate, endDate).
		Scan(&totalIncome).Error
	if err != nil {
		return types.MoneyZero(), err
	}
	return totalIncome, nil
}

func GetTransactionCount(tx *gorm.DB, profileId uint, startDate, endDate time.Time) (int, error) {
	var count int64
	err := tx.Model(&models.Transaction{}).
		Where("profile_id = ? AND date >= ? AND date <= ? AND type = 'expense'", profileId, startDate, endDate).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int(count), nil
}

func GetBiggestTransaction(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (dto.BiggestTransaction, error) {
	var result dto.BiggestTransaction
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("transactions.name as name, %s as amount, c.icon as icon, c.color as color", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense'", profileId, startDate, endDate).
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.BiggestTransaction{}, err
	}
	return result, nil
}

func GetTopMerchant(tx *gorm.DB, profileId uint, startDate, endDate time.Time, baseCurrency string) (dto.TopMerchant, error) {
	var result dto.TopMerchant
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("transactions.merchant_name as name, COALESCE(SUM(%s),0) as amount", utils.ConvertedAmount("tc.amount"))).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ? AND transactions.type = 'expense' AND transactions.merchant_name != ''", profileId, startDate, endDate).
		Group("transactions.merchant_name").
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.TopMerchant{}, err
	}
	return result, nil
}
