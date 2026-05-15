package currencies

import (
	"github.com/shopspring/decimal"

	"moneef/pkg/utils"
)

func CreateUpdateCurrencyRates(base string, currencyList map[string]float64) error {
	for code, rateF := range currencyList {
		if !utils.IsSupportedCurrency(code) {
			continue
		}
		rate := decimal.NewFromFloat(rateF)
		if err := CreateUpdateCurrencyRate(base, code, rate); err != nil {
			return err
		}
		inverse := decimal.NewFromInt(1).Div(rate)
		if err := CreateUpdateCurrencyRate(code, base, inverse); err != nil {
			return err
		}
	}
	return nil
}
