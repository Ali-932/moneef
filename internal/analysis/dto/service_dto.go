package dto

import (
	"moneef/pkg/types"
	"time"
)

type AnalysisCharts struct {
	Categories                []CategorySummary           `json:"categories"`
	CategoriesLastPeriod      []CategorySummary           `json:"categories_last_period"`
	SpentPerDay               []AmountPerDay              `json:"spent_per_day"`
	SpentPerDayLastPeriod     []AmountPerDay              `json:"spent_per_day_last_period"`
	NextRecurringTransactions []NextRecurringTransactions `json:"next_recurring_transactions"`
	Total                     types.Money                 `json:"total"`
}

type CategorySummary struct {
	CategoryID   uint            `json:"category_id"`
	CategoryName string          `json:"category_name"`
	TotalAmount  types.Money     `json:"total_amount"`
	Percentage   types.Money     `json:"percentage"`
}

type AmountPerDay struct {
	Date   time.Time       `json:"date"`
	Amount types.Money     `json:"amount"`
}

type NextRecurringTransactions struct {
	Amount types.Money     `json:"amount"`
	Date   time.Time       `json:"date"`
	Name   string          `json:"name"`
}
