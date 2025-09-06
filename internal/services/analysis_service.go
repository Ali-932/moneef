package services

import (
	"github.com/shopspring/decimal"
	"log"
	"moneef/internal"
	"moneef/internal/db"
	"moneef/internal/repository"
	"time"
)

type SpendByCategoryChart struct {
	Categories []repository.CategorySummary `json:"categories"`
	Total      decimal.Decimal              `json:"total"`
	StartDate  time.Time
	EndDate    time.Time
}

func GetSpendByCategoryChart(profileId uint, startDate, endDate time.Time) (*SpendByCategoryChart, error) {
	allCategories, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, "USD")
	if err != nil {
		return nil, err
	}
	total, err := repository.GetTransactionTotalExpense(db.DB, profileId, startDate, endDate, "USD")
	if err != nil {
		return nil, err
	}

	if total.IsZero() {
		return &SpendByCategoryChart{
			Categories: []repository.CategorySummary{},
			Total:      decimal.Zero,
			StartDate:  startDate,
			EndDate:    endDate,
		}, nil
	}
	var finalCategories []repository.CategorySummary
	topCategories := allCategories
	if len(allCategories) > internal.CategoriesOthersThreshold {
		topCategories = allCategories[:internal.CategoriesOthersThreshold]
	}
	for _, category := range topCategories {
		category.Percentage = decimal.NewFromInt(100).Mul(category.TotalAmount.Div(total)).Round(internal.AmountRounding)
		log.Printf("%v", category.Percentage)

		finalCategories = append(finalCategories, category)
	}
	if len(allCategories) > internal.CategoriesOthersThreshold {
		othersTotal := decimal.Zero
		for _, category := range allCategories[internal.CategoriesOthersThreshold:] {
			othersTotal = othersTotal.Add(category.TotalAmount)
		}
		if othersTotal.GreaterThan(decimal.Zero) {
			othersCategory := repository.CategorySummary{
				CategoryID:   0,
				CategoryName: "Others",
				TotalAmount:  othersTotal,
				Percentage:   decimal.NewFromInt(100).Mul(othersTotal.Div(total)).Round(internal.AmountRounding),
			}
			finalCategories = append(finalCategories, othersCategory)
		}
	}

	for _, category := range finalCategories {
		category.TotalAmount = category.TotalAmount.Round(internal.AmountRounding)
		category.Percentage = decimal.NewFromInt(100).Mul(category.TotalAmount.Div(total)).Round(internal.AmountRounding)
	}
	log.Printf("len of categories: %d", len(finalCategories))

	res := SpendByCategoryChart{
		Categories: finalCategories,
		Total:      total,
		StartDate:  startDate,
		EndDate:    endDate,
	}
	return &res, nil
}
