//go:build android || smoke

package mobilebridge

import (
	"encoding/json"

	"moneef/internal/currencies"
	"moneef/internal/models"
)

// ListCurrencies returns all supported currencies ordered by code.
// Mirrors the public HTTP endpoint GET /api/v1/currencies.
func ListCurrencies() ([]byte, error) {
	list, err := currencies.ListCurrencies()
	if err != nil {
		return nil, err
	}
	if list == nil {
		list = []models.Currency{}
	}
	return json.Marshal(list)
}
