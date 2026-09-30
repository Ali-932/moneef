package repository

import (
	"fmt"
	"moneef/internal/dashboard/dto"
	"moneef/internal/models"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"time"

	"gorm.io/gorm"
)

func GetPeriodTotals(tx *gorm.DB, profileID uint, startDate, endDate time.Time, baseCurrency string) (*dto.PeriodTotals, error) {
	var result dto.PeriodTotals
	ca := utils.TransactionConvertedAmount("tc.amount", "transactions")
	err := tx.Model(&models.Transaction{}).
		Select(fmt.Sprintf("COALESCE(SUM(CASE WHEN transactions.type = 'income' THEN %s ELSE 0 END), 0) as income, COALESCE(SUM(CASE WHEN transactions.type = 'expense' THEN %s ELSE 0 END), 0) as expense", ca, ca)).
		Joins("JOIN transaction_categories tc ON transactions.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("transactions", baseCurrency)).
		Where("transactions.profile_id = ? AND transactions.date >= ? AND transactions.date <= ?", profileID, startDate, endDate).
		Scan(&result).Error

	if err != nil {
		return nil, err
	}
	return &result, nil
}

func GetRecentTransactions(tx *gorm.DB, profileID uint, limit int) ([]models.Transaction, error) {
	var transactions []models.Transaction
	err := tx.Preload("TransactionCategory.Category", models.WithDeleted).
		Where("profile_id = ?", profileID).
		Order("date desc, created_at desc").
		Limit(limit).
		Find(&transactions).Error
	if err != nil {
		return nil, err
	}
	return transactions, nil
}

func GetTopCategory(tx *gorm.DB, profileID uint, startDate, endDate time.Time, baseCurrency string) (*dto.TopCategory, error) {
	var result dto.TopCategory
	err := tx.Table("transactions t").
		Select(fmt.Sprintf("c.id as category_id, c.name as category_name, SUM(%s) as total_amount", utils.TransactionConvertedAmount("tc.amount", "t"))).
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Scopes(utils.WithCurrencyConversion("t", baseCurrency)).
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ?", profileID, startDate, endDate).
		Group("c.id, c.name").
		Order("total_amount DESC").
		Limit(1).
		Scan(&result).Error

	if err != nil {
		return nil, err
	}
	if result.CategoryID == 0 { // no expenses in the period
		return nil, nil
	}
	return &result, nil
}

func GetAvgDailySpend(tx *gorm.DB, profileID uint, startDate, endDate time.Time, baseCurrency string) (types.Money, error) {
	var total types.Money
	err := tx.Table("transactions t").
		Select(fmt.Sprintf("COALESCE(SUM(%s), 0) as total", utils.TransactionConvertedAmount("tc.amount", "t"))).
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("t", baseCurrency)).
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ?", profileID, startDate, endDate).
		Scan(&total).Error
	if err != nil {
		return types.MoneyZero(), err
	}

	days := int(endDate.Sub(startDate).Hours()/24) + 1
	if days <= 0 {
		return types.MoneyZero(), nil
	}

	avg := total.Div(types.MoneyFromInt(int64(days)))
	return avg, nil
}

func GetTransactionCount(tx *gorm.DB, profileID uint, startDate, endDate time.Time) (int, error) {
	var count int64
	err := tx.Model(&models.Transaction{}).
		Where("profile_id = ? AND date >= ? AND date <= ?", profileID, startDate, endDate).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int(count), nil
}

func GetUpcomingRecurring(tx *gorm.DB, profileID uint, currentDate time.Time, limit int, baseCurrency string) ([]dto.RecurringPayment, error) {
	endDate := currentDate.AddDate(0, 1, 0)
	var results []dto.RecurringPayment
	err := tx.Table("recurrence_templates rt").
		Select(fmt.Sprintf("rt.name as name, rt.type as type, %s as amount, rt.next_date as date", utils.ConvertedAmount("rt.next_payment_amount"))).
		Scopes(utils.WithCurrencyConversion("rt", baseCurrency)).
		Where("rt.is_active = true AND rt.profile_id = ? AND rt.next_date >= ? AND rt.next_date <= ?", profileID, currentDate, endDate).
		Order("rt.next_date ASC").
		Limit(limit).
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}

func GetBiggestTransaction(tx *gorm.DB, profileID uint, startDate, endDate time.Time, baseCurrency string) (dto.BiggestTransaction, error) {
	var result dto.BiggestTransaction
	err := tx.Table("transactions t").
		Select(fmt.Sprintf("t.name as name, %s as amount, c.icon as icon, c.color as color", utils.TransactionConvertedAmount("tc.amount", "t"))).
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Scopes(utils.WithCurrencyConversion("t", baseCurrency)).
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ?", profileID, startDate, endDate).
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.BiggestTransaction{}, err
	}
	return result, nil
}

func GetTopMerchant(tx *gorm.DB, profileID uint, startDate, endDate time.Time, baseCurrency string) (dto.TopMerchant, error) {
	var result dto.TopMerchant
	err := tx.Table("transactions t").
		Select(fmt.Sprintf("t.merchant_name as name, COALESCE(SUM(%s), 0) as amount", utils.TransactionConvertedAmount("tc.amount", "t"))).
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Scopes(utils.WithCurrencyConversion("t", baseCurrency)).
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ? AND t.merchant_name != ''", profileID, startDate, endDate).
		Group("t.merchant_name").
		Order("amount DESC").
		Limit(1).
		Scan(&result).Error
	if err != nil {
		return dto.TopMerchant{}, err
	}
	return result, nil
}
