package services

import (
	"moneef/internal/db"
	"moneef/internal/repository"
	"time"
)

type SpendByCategoryChart struct {
	Categories []repository.CategorySummary `json:"categories"`
	Total      float64                      `json:"total"`
	StartDate  time.Time
	EndDate    time.Time
}

func GetSpendByCategoryChart(profileId uint, startDate, endDate time.Time) (*SpendByCategoryChart, error) {
	chartResult, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, "USDWW")
	if err != nil {
		return nil, err
	}
	total, err := repository.GetTransactionTotalExpense(db.DB, profileId, startDate, endDate)
	if err != nil {
		return nil, err
	}
	res := SpendByCategoryChart{
		Categories: chartResult,
		Total:      total,
		StartDate:  startDate,
		EndDate:    endDate,
	}
	return &res, nil
}
