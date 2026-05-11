package utils

import (
	"fmt"
	"moneef/internal/models"
	"moneef/pkg/types"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

// ConvertAmount converts a float64 amount from one currency to another
// using the exchange rate from the DB. Returns the original amount if
// currencies match or no rate is found.
func ConvertAmount(db *gorm.DB, amount float64, fromCurrency string, toCurrency string) float64 {
	if fromCurrency == toCurrency {
		return amount
	}
	var rate models.CurrencyExchangeRate
	err := db.Where("currency_code1 = ? AND currency_code2 = ?", fromCurrency, toCurrency).First(&rate).Error
	if err != nil {
		return amount
	}
	return amount * rate.Rate
}

// ConvertMoney converts a types.Money amount between currencies.
func ConvertMoney(db *gorm.DB, amount types.Money, fromCurrency string, toCurrency string) types.Money {
	converted := ConvertAmount(db, amount.Float64(), fromCurrency, toCurrency)
	return types.Money(decimal.NewFromFloat(converted))
}

// WithCurrencyConversion returns a GORM scope that LEFT JOINs the
// currency_exchange_rates table so that the ConvertedAmount helper
// produces correct results inside the query.
//
//	tx.Scopes(utils.WithCurrencyConversion("t", "IQD"))
func WithCurrencyConversion(txTableAlias string, baseCurrency string) func(*gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Joins(
			fmt.Sprintf(
				"LEFT JOIN currency_exchange_rates cer ON %s.currency_code = cer.currency_code1 AND cer.currency_code2 = ?",
				txTableAlias,
			),
			baseCurrency,
		)
	}
}

// ConvertedAmount returns a SQL expression that multiplies a raw amount
// column by the exchange rate (defaulting to 1.0 when no rate row exists).
// Use inside Select() clauses.
//
//	Select(utils.ConvertedAmount("tc.amount") + " as amount")
func ConvertedAmount(amountColumn string) string {
	return fmt.Sprintf("(%s * COALESCE(cer.rate, 1))", amountColumn)
}
