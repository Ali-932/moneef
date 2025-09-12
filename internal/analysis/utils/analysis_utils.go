package utils

import (
	"github.com/shopspring/decimal"
	"log"
	"moneef/internal/analysis/dto"
	"moneef/internal/config"
	"sort"
	"time"
)

func GetCategoriesSlicedAndSorted(allCategories []dto.CategorySummary, total decimal.Decimal) []dto.CategorySummary {
	var finalCategories []dto.CategorySummary
	topCategories := allCategories
	if len(allCategories) > config.CategoriesOthersThreshold {
		topCategories = allCategories[:config.CategoriesOthersThreshold]
	}
	for _, category := range topCategories {
		category.Percentage = decimal.NewFromInt(100).Mul(category.TotalAmount.Div(total)).Round(config.AmountRounding)
		log.Printf("%v", category.Percentage)

		finalCategories = append(finalCategories, category)
	}
	if len(allCategories) > config.CategoriesOthersThreshold {
		othersTotal := decimal.Zero
		for _, category := range allCategories[config.CategoriesOthersThreshold:] {
			othersTotal = othersTotal.Add(category.TotalAmount)
		}
		if othersTotal.GreaterThan(decimal.Zero) {
			othersCategory := dto.CategorySummary{
				CategoryID:   0,
				CategoryName: "Others",
				TotalAmount:  othersTotal,
				Percentage:   decimal.NewFromInt(100).Mul(othersTotal.Div(total)).Round(config.AmountRounding),
			}
			finalCategories = append(finalCategories, othersCategory)
		}
	}

	for _, category := range finalCategories {
		category.TotalAmount = category.TotalAmount.Round(config.AmountRounding)
		category.Percentage = decimal.NewFromInt(100).Mul(category.TotalAmount.Div(total)).Round(config.AmountRounding)
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
			Amount: decimal.Zero,
		})
		datesAvailable[key] = true

	}
	sort.Slice(amountsPerDay, func(i, j int) bool {
		return amountsPerDay[i].Date.Before(amountsPerDay[j].Date)
	})
	return amountsPerDay
}
