package utils

import (
	"moneef/internal/analysis/dto"
	"moneef/internal/config"
	"moneef/pkg/types"
	"time"

	"github.com/shopspring/decimal"
)

func GetCategoriesSlicedAndSorted(allCategories []dto.CategorySummary, total types.Money) []dto.CategorySummary {
	var finalCategories []dto.CategorySummary
	if decimal.Decimal(total).IsZero() {
		for i := range allCategories {
			allCategories[i].Percentage = types.MoneyFromInt(0)
		}
		return allCategories
	}
	topCategories := allCategories
	if len(allCategories) > config.CategoriesOthersThreshold {
		topCategories = allCategories[:config.CategoriesOthersThreshold]
	}
	for _, category := range topCategories {
		category.Percentage = types.MoneyFromInt(100).Mul(category.TotalAmount.Div(total))

		finalCategories = append(finalCategories, category)
	}
	if len(allCategories) > config.CategoriesOthersThreshold {
		othersTotal := types.MoneyZero()
		for _, category := range allCategories[config.CategoriesOthersThreshold:] {
			othersTotal = othersTotal.Add(category.TotalAmount)
		}
		if othersTotal.GreaterThan(types.MoneyZero()) {
			othersCategory := dto.CategorySummary{
				CategoryID:   0,
				CategoryName: "Others",
				TotalAmount:  othersTotal,
				Percentage:   types.MoneyFromInt(100).Mul(othersTotal.Div(total)),
				Icon:         "",
				Color:        "",
			}
			finalCategories = append(finalCategories, othersCategory)
		}
	}
	return finalCategories
}

func FillMissingDates(amountsPerDay []dto.AmountPerDay, startDate, endDate time.Time) []dto.AmountPerDay {
	// The repository returns sums per timestamp. Collapse them into calendar
	// days in the range's zone before filling gaps, so several payments never
	// become repeated dates.
	loc := startDate.Location()
	totals := make(map[string]types.Money)
	for _, apd := range amountsPerDay {
		key := apd.Date.In(loc).Format(time.DateOnly)
		totals[key] = totals[key].Add(apd.Amount)
	}
	// Days go out as UTC midnight of the calendar date: the app reads them as
	// plain dates, not instants.
	end := endDate.In(loc)
	lastDay := time.Date(end.Year(), end.Month(), end.Day(), 0, 0, 0, 0, time.UTC)
	startDay := time.Date(startDate.Year(), startDate.Month(), startDate.Day(), 0, 0, 0, 0, time.UTC)
	days := make([]dto.AmountPerDay, 0)
	for d := startDay; !d.After(lastDay); d = d.AddDate(0, 0, 1) {
		amount, ok := totals[d.Format(time.DateOnly)]
		if !ok {
			amount = types.MoneyZero()
		}
		days = append(days, dto.AmountPerDay{
			Date:   d,
			Amount: amount,
		})
	}
	return days
}
