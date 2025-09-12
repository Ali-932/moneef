package dto

import (
	"github.com/shopspring/decimal"
	"time"
)

type AnalysisCharts struct {
	Categories                []CategorySummary           `json:"categories"`
	CategoriesLastPeriod      []CategorySummary           `json:"categories_last_period"`
	SpentPerDay               []AmountPerDay              `json:"spent_per_day"`
	SpentPerDayLastPeriod     []AmountPerDay              `json:"spent_per_day_last_period"`
	NextRecurringTransactions []NextRecurringTransactions `json:"next_recurring_transactions"`
	Total                     decimal.Decimal             `json:"total"`
}

type CategorySummary struct {
	CategoryID   uint            `json:"category_id"`
	CategoryName string          `json:"category_name"`
	TotalAmount  decimal.Decimal `json:"total_amount"`
	Percentage   decimal.Decimal `json:"percentage"`
}

type AmountPerDay struct {
	Date   time.Time       `json:"date"`
	Amount decimal.Decimal `json:"amount"`
}

type NextRecurringTransactions struct {
	Amount decimal.Decimal `json:"amount"`
	Date   time.Time       `json:"date"`
	Name   string          `json:"name"`
}
