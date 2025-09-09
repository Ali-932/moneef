package utils

import (
	"moneef/internal/config"
	"strings"
)

func IsSupportedCurrency(code string) bool {
	code = strings.ToUpper(code)
	for _, currency := range config.Currencies {
		if currency.Code == code {
			return true
		}
	}
	return false
}
