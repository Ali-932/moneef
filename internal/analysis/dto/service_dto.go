package dto

import (
	"moneef/pkg/types"
	"time"
)

type BiggestTransaction struct {
	Name   string      `json:"name"`
	Amount types.Money `json:"amount"`
	Icon   string      `json:"icon"`
	Color  string      `json:"color"`
}

type TopMerchant struct {
	Name   string      `json:"name"`
	Amount types.Money `json:"amount"`
}

type QuickStats struct {
	SavingsRate        types.Money        `json:"savings_rate"`
	BiggestTransaction BiggestTransaction `json:"biggest_transaction"`
	TransactionCount   int                `json:"transaction_count"`
	TopMerchant        TopMerchant        `json:"top_merchant"`
	AvgTransaction     types.Money        `json:"avg_transaction"`
}

type AnalysisCharts struct {
	Categories                []CategorySummary           `json:"categories"`
	CategoriesLastPeriod      []CategorySummary           `json:"categories_last_period"`
	SpentPerDay               []AmountPerDay              `json:"spent_per_day"`
	SpentPerDayLastPeriod     []AmountPerDay              `json:"spent_per_day_last_period"`
	NextRecurringTransactions []NextRecurringTransactions `json:"next_recurring_transactions"`
	Total                     types.Money                 `json:"total"`
	QuickStats                QuickStats                  `json:"quick_stats"`
}

type CategorySummary struct {
	CategoryID   uint        `json:"category_id"`
	CategoryName string      `json:"category_name"`
	TotalAmount  types.Money `json:"total_amount"`
	Percentage   types.Money `json:"percentage"`
	Icon         string      `json:"icon"`
	Color        string      `json:"color"`
}

type AmountPerDay struct {
	Date   time.Time   `json:"date"`
	Amount types.Money `json:"amount"`
}

type NextRecurringTransactions struct {
	Amount types.Money `json:"amount"`
	Date   time.Time   `json:"date"`
	Name   string      `json:"name"`
}
