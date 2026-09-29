package utils

import (
	"fmt"
	"moneef/internal/models"
	"moneef/pkg/types"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

var ErrExchangeRateUnavailable = fmt.Errorf("exchange rate unavailable")

func ConvertMoney(db *gorm.DB, amount types.Money, fromCurrency string, toCurrency string) (types.Money, error) {
	if fromCurrency == toCurrency {
		return amount, nil
	}
	var rate models.CurrencyExchangeRate
	err := db.Where("currency_code1 = ? AND currency_code2 = ?", fromCurrency, toCurrency).First(&rate).Error
	if err != nil {
		return types.Money{}, fmt.Errorf("%w: %s→%s: %v", ErrExchangeRateUnavailable, fromCurrency, toCurrency, err)
	}
	result := decimal.Decimal(amount).Mul(rate.Rate)
	return types.Money(result), nil
}

func ConvertAmount(db *gorm.DB, amount decimal.Decimal, fromCurrency string, toCurrency string) (decimal.Decimal, error) {
	result, err := ConvertMoney(db, types.Money(amount), fromCurrency, toCurrency)
	if err != nil {
		return decimal.Decimal{}, err
	}
	return decimal.Decimal(result), nil
}

// WithCurrencyConversion returns a GORM scope that LEFT JOINs the
// currency_exchange_rates table so that ConvertedAmount produces correct
// results inside the query.
func WithCurrencyConversion(txTableAlias string, baseCurrency string) func(*gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Joins(
			fmt.Sprintf(
				"LEFT JOIN currency_exchange_rates cer ON %s.currency_code = cer.currency_code1 AND cer.currency_code2 = ?",
				txTableAlias,
			),
			baseCurrency,
		).
			Joins("CROSS JOIN (SELECT ? AS code) base_currency", baseCurrency).
			Joins("LEFT JOIN currency_exchange_rates usd_base ON usd_base.currency_code1 = 'USD' AND usd_base.currency_code2 = base_currency.code")
	}
}

// TransactionConvertedAmount converts a transactions row with its frozen
// UsdRate: amount ÷ usd_rate is the USD value, × today's USD→base rate.
// Rows without one fall back to ConvertedAmount's current rate.
func TransactionConvertedAmount(amountColumn, txTableAlias string) string {
	return fmt.Sprintf(
		"(%[1]s * CASE WHEN %[2]s.currency_code = base_currency.code THEN 1 "+
			"ELSE COALESCE(CASE WHEN base_currency.code = 'USD' THEN 1.0 ELSE usd_base.rate END / %[2]s.usd_rate, cer.rate, 1) END)",
		amountColumn, txTableAlias,
	)
}

// ConvertedAmount returns a SQL expression that multiplies a raw amount
// column by the exchange rate (defaulting to 1.0 when no rate row exists).
func ConvertedAmount(amountColumn string) string {
	return fmt.Sprintf("(%s * COALESCE(cer.rate, 1))", amountColumn)
}
