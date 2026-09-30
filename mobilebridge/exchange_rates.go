//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"errors"
	"fmt"

	"github.com/shopspring/decimal"

	"moneef/internal/currencies"
	"moneef/internal/models"
	usersvc "moneef/internal/users/service"
)

type listExchangeRatesRequest struct {
	Base string `json:"base"`
}

func ListExchangeRates(payload []byte) ([]byte, error) {
	if _, err := getProfileID(); err != nil {
		return nil, err
	}

	var req listExchangeRatesRequest
	if len(payload) > 0 {
		if err := json.Unmarshal(payload, &req); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
		}
	}

	base := req.Base
	if base == "" {
		base = "USD" // rates are anchored to USD, whatever the default currency
	}

	rates, err := currencies.GetExchangeRates(base)
	if err != nil {
		return nil, err
	}
	if rates == nil {
		rates = []models.CurrencyExchangeRate{}
	}
	return json.Marshal(rates)
}

type upsertExchangeRateRequest struct {
	From string `json:"from"`
	To   string `json:"to"`
	Rate string `json:"rate"`
}

func UpsertExchangeRate(payload []byte) error {
	if _, err := getProfileID(); err != nil {
		return err
	}

	var req upsertExchangeRateRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	if req.From == "" || req.To == "" || req.Rate == "" {
		return errors.New("from, to, and rate are required")
	}

	rate, err := decimal.NewFromString(req.Rate)
	if err != nil || rate.LessThanOrEqual(decimal.Zero) {
		return errors.New("rate must be a positive number")
	}

	// Rates are anchored to USD, so one side must be USD.
	switch {
	case req.From == "USD" && req.To != "USD":
		return currencies.SetUsdRate(req.To, rate)
	case req.To == "USD" && req.From != "USD":
		return currencies.SetUsdRate(req.From, decimal.NewFromInt(1).Div(rate))
	}
	return errors.New("rates are set against USD: from or to must be USD")
}

func FetchExchangeRates() error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	uid, err := resolveUserID(pid)
	if err != nil {
		return err
	}
	settings, err := usersvc.GetSettings(uid)
	if err != nil {
		return err
	}
	if settings.ExchangeRateApiKey == "" {
		return errors.New("no exchange rate API key configured")
	}
	return currencies.FetchRatesFromAPI(settings.ExchangeRateApiKey)
}
