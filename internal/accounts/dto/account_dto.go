package dto

import (
	"time"

	"github.com/shopspring/decimal"

	"moneef/internal/models"
	"moneef/pkg/types"
)

type AccountRequest struct {
	Name string `json:"name" validate:"required"`
}

// TransferRequest: ToCurrency and ToAmount default to the "from" side, so a
// same-currency transfer only needs one amount.
type TransferRequest struct {
	FromAccountID uint            `json:"from_account_id"`
	ToAccountID   uint            `json:"to_account_id"`
	FromCurrency  string          `json:"from_currency"`
	FromAmount    decimal.Decimal `json:"from_amount"`
	ToCurrency    string          `json:"to_currency"`
	ToAmount      decimal.Decimal `json:"to_amount"`
	Date          time.Time       `json:"date"`
}

type SetBalanceRequest struct {
	AccountID uint            `json:"account_id"`
	Currency  string          `json:"currency"`
	Amount    decimal.Decimal `json:"amount"`
}

// Balance is one account's balance in one currency.
type Balance struct {
	AccountID uint        `json:"-"`
	Currency  string      `json:"currency"`
	Amount    types.Money `json:"amount"`
}

// AccountSummary is an account with its balances. ApproxTotal is their sum in
// the default currency at today's rates, omitted when a currency has no rate.
type AccountSummary struct {
	models.Account
	Balances    []Balance    `json:"balances"`
	ApproxTotal *types.Money `json:"approx_total,omitempty"`
}
