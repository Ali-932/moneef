package analysis

import (
	"github.com/shopspring/decimal"
	"log"
	"moneef/internal/config"
)

func GetCategoriesSlicedAndSorted(allCategories []CategorySummary, total decimal.Decimal) []CategorySummary {
	var finalCategories []CategorySummary
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
			othersCategory := CategorySummary{
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
