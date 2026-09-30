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

// SetUsdRate saves 1 USD = usdRate code, then the direct rate between code and
// every other currency with a USD rate, so any pair converts.
func SetUsdRate(code string, usdRate decimal.Decimal) error {
	others, err := GetUsdRates()
	if err != nil {
		return err
	}
	if err := savePair("USD", code, usdRate); err != nil {
		return err
	}
	for _, o := range others {
		if o.CurrencyCode2 == code {
			continue
		}
		// 1 code = 1/usdRate USD = o.Rate/usdRate of the other currency.
		if err := savePair(code, o.CurrencyCode2, o.Rate.Div(usdRate)); err != nil {
			return err
		}
	}
	return nil
}

// savePair saves 1 from = rate to, and the inverse.
func savePair(from, to string, rate decimal.Decimal) error {
	if err := CreateUpdateCurrencyRate(from, to, rate); err != nil {
		return err
	}
	return CreateUpdateCurrencyRate(to, from, decimal.NewFromInt(1).Div(rate))
}
