package analysis

import (
	"github.com/shopspring/decimal"
	"moneef/internal/db"
	"time"
)

func GetSpendByCategoryChart(profileId uint, startDate, endDate time.Time) (*AnalysisCharts, error) {
	period := endDate.Sub(startDate)
	lastPeriodEnd := startDate
	lastPeriodStart := startDate.Add(-period)
	allCategories, err := GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, "USD")
	allCategoriesLastPeriod, err := GetTransactionsGroupedByCategory(db.DB, profileId, lastPeriodStart, lastPeriodEnd, "USD")
	if err != nil {
		return nil, err
	}
	total, err := GetTransactionTotalExpense(db.DB, profileId, startDate, endDate, "USD")
	if err != nil {
		return nil, err
	}
	if total.IsZero() {
		return &AnalysisCharts{
			Categories: []CategorySummary{},
			Total:      decimal.Zero,
			StartDate:  startDate,
			EndDate:    endDate,
		}, nil
	}
	finalCategories := GetCategoriesSlicedAndSorted(allCategories, total)
	finalCategoriesLastPeriod := GetCategoriesSlicedAndSorted(allCategoriesLastPeriod, total)
	res := AnalysisCharts{
		Categories:           finalCategories,
		CategoriesLastPeriod: finalCategoriesLastPeriod,
		Total:                total,
		StartDate:            startDate,
		EndDate:              endDate,
	}
	return &res, nil
}
