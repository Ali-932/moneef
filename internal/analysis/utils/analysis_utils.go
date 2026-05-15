package utils

import (
	"moneef/internal/analysis/dto"
	"moneef/internal/config"
	"moneef/pkg/types"
	"sort"
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
	datesAvailable := make(map[string]bool)
	for _, apd := range amountsPerDay {
		datesAvailable[apd.Date.Format("2006-01-02")] = true
	}
	for d := startDate; !d.After(endDate); d = d.AddDate(0, 0, 1) {
		key := d.Format("2006-01-02")
		if datesAvailable[key] {
			continue
		}
		amountsPerDay = append(amountsPerDay, dto.AmountPerDay{
			Date:   d,
			Amount: types.MoneyZero(),
		})
		datesAvailable[key] = true

	}
	sort.Slice(amountsPerDay, func(i, j int) bool {
		return amountsPerDay[i].Date.Before(amountsPerDay[j].Date)
	})
	return amountsPerDay
}
