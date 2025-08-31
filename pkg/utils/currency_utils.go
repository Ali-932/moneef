package utils

import (
	"moneef/internal"
	"strings"
)

func IsSupportedCurrency(code string) bool {
	code = strings.ToUpper(code)
	for _, currency := range internal.Currencies {
		if currency.Code == code {
			return true
		}
	}
	return false
}
