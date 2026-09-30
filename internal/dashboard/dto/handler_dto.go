package dto

import (
	"moneef/internal/models"
	"moneef/pkg/types"
	"time"
)

type DashboardResponse struct {
	Period             DashboardPeriod      `json:"period"`
	CurrencyCode       string               `json:"currency_code"`
	Balance            types.Money          `json:"balance"`
	TotalIncome        types.Money          `json:"total_income"`
	TotalExpense       types.Money          `json:"total_expense"`
	RecentTransactions []models.Transaction `json:"recent_transactions"`
	QuickStats         QuickStats           `json:"quick_stats"`
	UpcomingRecurring  []RecurringPayment   `json:"upcoming_recurring"`
}

type DashboardPeriod struct {
	StartDate time.Time `json:"start_date"`
	EndDate   time.Time `json:"end_date"`
}

type QuickStats struct {
	TopCategory        *CategoryStat      `json:"top_category,omitempty"`
	AvgDailySpend      types.Money        `json:"avg_daily_spend"`
	TransactionCount   int                `json:"transaction_count"`
	SavingsRate        types.Money        `json:"savings_rate"`
	BiggestTransaction BiggestTransaction `json:"biggest_transaction"`
	TopMerchant        TopMerchant        `json:"top_merchant"`
	AvgTransaction     types.Money        `json:"avg_transaction"`
}

type CategoryStat struct {
	CategoryID   uint        `json:"category_id"`
	CategoryName string      `json:"category_name"`
	TotalAmount  types.Money `json:"total_amount"`
}

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

type RecurringPayment struct {
	Name   string      `json:"name"`
	Type   string      `json:"type"`
	Amount types.Money `json:"amount"`
	Date   time.Time   `json:"date"`
}
