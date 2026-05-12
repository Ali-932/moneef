package service

import (
	"github.com/shopspring/decimal"
	"moneef/internal/dashboard/dto"
	"moneef/internal/dashboard/repository"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/types"
	"time"
)

func GetDashboard(profileID uint, dateFrom, dateTo *time.Time) (*dto.DashboardResponse, error) {
	now := time.Now().UTC()
	startDate := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	endDate := startDate.AddDate(0, 1, 0).Add(-time.Second)

	if dateFrom != nil {
		startDate = *dateFrom
	}
	if dateTo != nil {
		endDate = *dateTo
	}

	// Fetch user's currency from settings
	var profile models.Profile
	var settings models.UserSettings
	currencyCode := "USD"
	if err := db.DB.First(&profile, profileID).Error; err == nil {
		if err := db.DB.Where("user_id = ?", profile.UserID).First(&settings).Error; err == nil {
			currencyCode = settings.CurrencyCode
		}
	}

	totals, err := repository.GetPeriodTotals(db.DB, profileID, startDate, endDate, currencyCode)
	if err != nil {
		return nil, err
	}

	recentTx, err := repository.GetRecentTransactions(db.DB, profileID, 10)
	if err != nil {
		return nil, err
	}

	topCat, err := repository.GetTopCategory(db.DB, profileID, startDate, endDate, currencyCode)
	if err != nil {
		return nil, err
	}

	avgDaily, err := repository.GetAvgDailySpend(db.DB, profileID, startDate, endDate, currencyCode)
	if err != nil {
		return nil, err
	}

	txCount, err := repository.GetTransactionCount(db.DB, profileID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	upcoming, err := repository.GetUpcomingRecurring(db.DB, profileID, now, 5, currencyCode)
	if err != nil {
		return nil, err
	}

	biggestTx, err := repository.GetBiggestTransaction(db.DB, profileID, startDate, endDate, currencyCode)
	if err != nil {
		return nil, err
	}

	topMerchant, err := repository.GetTopMerchant(db.DB, profileID, startDate, endDate, currencyCode)
	if err != nil {
		return nil, err
	}

	balance := totals.Income.Sub(totals.Expense)

	var topCategoryStat *dto.CategoryStat
	if topCat != nil {
		topCategoryStat = &dto.CategoryStat{
			CategoryID:   topCat.CategoryID,
			CategoryName: topCat.CategoryName,
			TotalAmount:  topCat.TotalAmount,
		}
	}

	var savingsRate types.Money
	if !decimal.Decimal(totals.Income).IsZero() {
		savingsRate = totals.Income.Sub(totals.Expense).Div(totals.Income).Mul(types.MoneyFromInt(100))
	}

	var avgTransaction types.Money
	if txCount > 0 {
		avgTransaction = totals.Expense.Div(types.MoneyFromInt(int64(txCount)))
	}

	// Ensure recent transactions slice is never nil
	if recentTx == nil {
		recentTx = []models.Transaction{}
	}

	return &dto.DashboardResponse{
		Period: dto.DashboardPeriod{
			StartDate: startDate,
			EndDate:   endDate,
		},
		CurrencyCode:       currencyCode,
		Balance:            balance,
		TotalIncome:        totals.Income,
		TotalExpense:       totals.Expense,
		RecentTransactions: recentTx,
		QuickStats: dto.QuickStats{
			TopCategory:        topCategoryStat,
			AvgDailySpend:      avgDaily,
			TransactionCount:   txCount,
			SavingsRate:        savingsRate,
			BiggestTransaction: biggestTx,
			TopMerchant:        topMerchant,
			AvgTransaction:     avgTransaction,
		},
		UpcomingRecurring: upcoming,
	}, nil
}
