package dto

import (
	"github.com/shopspring/decimal"
	"moneef/pkg/types"
	"time"
)

type TransactionCreationParams struct {
	ProfileID             uint
	Name                  string
	Type                  string
	Date                  time.Time
	CurrencyCode          string
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	RecurrenceTemplateID  *uint
	IsRecurrent           *bool
	Frequency             *string
	AmountPaidPreviously  *decimal.Decimal
	TotalAmountToPay      *decimal.Decimal
	EndDate               *time.Time
	HasEndDate            *bool
	IsActive              *bool
	AccountID             *uint
}

type CreateTransactionParams struct {
	ProfileID             uint
	Name                  string
	CurrencyCode          string
	Type                  string
	Date                  time.Time
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	RecurrenceTemplateID  *uint
	AccountID             *uint
}

type CreateTransactionRecurrentParams struct {
	ProfileID             uint
	Name                  string
	CurrencyCode          string
	Type                  string
	StartDate             time.Time
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	Frequency             string
	HasEndDate            bool
	EndDate               *time.Time
	IsActive              bool
	NextPaymentAmount     *decimal.Decimal
	AmountPaidPreviously  *decimal.Decimal
	AmountLeftToPay       *decimal.Decimal
	TotalAmountToPay      *decimal.Decimal
	AccountID             *uint
}

type RecurrenceOccurrence struct {
	ID       uint        `json:"id"`
	Name     string      `json:"name"`
	Type     string      `json:"type"`
	Amount   types.Money `json:"amount"`
	Currency string      `json:"currency"`
	Icon     string      `json:"icon"`
	Color    string      `json:"color"`
	Date     time.Time   `json:"date"`
}
