package service

import (
	"github.com/shopspring/decimal"

	"moneef/internal/transactions/repository"
	"moneef/pkg/utils"
)

func CreateUpdateCurrencyRates(base string, currencyList map[string]float64) error {
	for code, rateF := range currencyList {
		if !utils.IsSupportedCurrency(code) {
			continue
		}
		rate := decimal.NewFromFloat(rateF)
		if err := repository.CreateUpdateCurrencyRate(base, code, rate); err != nil {
			return err
		}
		inverse := decimal.NewFromInt(1).Div(rate)
		if err := repository.CreateUpdateCurrencyRate(code, base, inverse); err != nil {
			return err
		}
	}
	return nil
}
