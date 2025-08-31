package services

import (
	"moneef/internal/repository"
	"moneef/pkg/utils"
)

func CreateUpdateCurrencyRates(base string, currencyList map[string]float64) error {
	var err error
	for code, rate := range currencyList {
		if utils.IsSupportedCurrency(code) == false {
			continue
		}
		err = repository.CreateUpdateCurrencyRate(base, code, rate)
		if err != nil {
			return err
		}
		err = repository.CreateUpdateCurrencyRate(code, base, 1/rate)
		if err != nil {
			return err
		}
	}
	return nil
}
