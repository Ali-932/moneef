package service

import (
	"moneef/internal/dashboard/dto"
	"moneef/internal/dashboard/repository"
	"moneef/internal/db"
	"moneef/internal/models"
	"time"
)

func GetDashboard(profileID uint, dateFrom, dateTo *time.Time) (*dto.DashboardResponse, error) {
	now := time.Now()
	startDate := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	endDate := startDate.AddDate(0, 1, 0).Add(-time.Second)

	if dateFrom != nil {
		startDate = *dateFrom
	}
	if dateTo != nil {
		endDate = *dateTo
	}

	totals, err := repository.GetPeriodTotals(db.DB, profileID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	recentTx, err := repository.GetRecentTransactions(db.DB, profileID, 10)
	if err != nil {
		return nil, err
	}

	topCat, err := repository.GetTopCategory(db.DB, profileID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	avgDaily, err := repository.GetAvgDailySpend(db.DB, profileID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	txCount, err := repository.GetTransactionCount(db.DB, profileID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	upcoming, err := repository.GetUpcomingRecurring(db.DB, profileID, now, 5)
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

	// Ensure recent transactions slice is never nil
	if recentTx == nil {
		recentTx = []models.Transaction{}
	}

	return &dto.DashboardResponse{
		Period: dto.DashboardPeriod{
			StartDate: startDate,
			EndDate:   endDate,
		},
		Balance:            balance,
		TotalIncome:        totals.Income,
		TotalExpense:       totals.Expense,
		RecentTransactions: recentTx,
		QuickStats: dto.QuickStats{
			TopCategory:      topCategoryStat,
			AvgDailySpend:    avgDaily,
			TransactionCount: txCount,
		},
		UpcomingRecurring: upcoming,
	}, nil
}
