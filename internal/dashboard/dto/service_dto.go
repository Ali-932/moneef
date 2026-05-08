package dto

import (
	"moneef/pkg/types"
	"time"
)

type PeriodTotals struct {
	Income  types.Money
	Expense types.Money
}

type TopCategory struct {
	CategoryID   uint
	CategoryName string
	TotalAmount  types.Money
}

type DailySpend struct {
	Date   time.Time
	Amount types.Money
}
