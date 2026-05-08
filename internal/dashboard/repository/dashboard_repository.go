package repository

import (
	"gorm.io/gorm"
	"moneef/internal/dashboard/dto"
	"moneef/internal/models"
	"moneef/pkg/types"
	"time"
)

func GetPeriodTotals(tx *gorm.DB, profileID uint, startDate, endDate time.Time) (*dto.PeriodTotals, error) {
	var result dto.PeriodTotals

	err := tx.Table("transactions t").
		Select("COALESCE(SUM(CASE WHEN t.type = 'income' THEN tc.amount ELSE 0 END), 0) as income, COALESCE(SUM(CASE WHEN t.type = 'expense' THEN tc.amount ELSE 0 END), 0) as expense").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Where("t.profile_id = ? AND t.date >= ? AND t.date <= ? AND t.deleted_at IS NULL", profileID, startDate, endDate).
		Scan(&result).Error

	if err != nil {
		return nil, err
	}
	return &result, nil
}

func GetRecentTransactions(tx *gorm.DB, profileID uint, limit int) ([]models.Transaction, error) {
	var transactions []models.Transaction
	err := tx.Preload("TransactionCategory.Category").
		Where("profile_id = ? AND deleted_at IS NULL", profileID).
		Order("date desc, created_at desc").
		Limit(limit).
		Find(&transactions).Error
	if err != nil {
		return nil, err
	}
	return transactions, nil
}

func GetTopCategory(tx *gorm.DB, profileID uint, startDate, endDate time.Time) (*dto.TopCategory, error) {
	var result dto.TopCategory
	err := tx.Table("transactions t").
		Select("c.id as category_id, c.name as category_name, SUM(tc.amount) as total_amount").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Joins("JOIN categories c ON tc.category_id = c.id").
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ? AND t.deleted_at IS NULL", profileID, startDate, endDate).
		Group("c.id, c.name").
		Order("total_amount DESC").
		Limit(1).
		Scan(&result).Error

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &result, nil
}

func GetAvgDailySpend(tx *gorm.DB, profileID uint, startDate, endDate time.Time) (types.Money, error) {
	var total types.Money
	err := tx.Table("transactions t").
		Select("COALESCE(SUM(tc.amount), 0) as total").
		Joins("JOIN transaction_categories tc ON t.id = tc.transaction_id").
		Where("t.profile_id = ? AND t.type = 'expense' AND t.date >= ? AND t.date <= ? AND t.deleted_at IS NULL", profileID, startDate, endDate).
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
		Where("profile_id = ? AND date >= ? AND date <= ? AND deleted_at IS NULL", profileID, startDate, endDate).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int(count), nil
}

func GetUpcomingRecurring(tx *gorm.DB, profileID uint, currentDate time.Time, limit int) ([]dto.RecurringPayment, error) {
	endDate := currentDate.AddDate(0, 1, 0)
	var results []dto.RecurringPayment
	err := tx.Table("recurrence_templates rt").
		Select("rt.name as name, rt.next_payment_amount as amount, rt.next_date as date").
		Where("rt.is_active = true AND rt.profile_id = ? AND rt.next_date >= ? AND rt.next_date <= ? AND rt.deleted_at IS NULL", profileID, currentDate, endDate).
		Order("rt.next_date ASC").
		Limit(limit).
		Scan(&results).Error
	if err != nil {
		return nil, err
	}
	return results, nil
}
