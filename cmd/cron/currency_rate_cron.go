package cron

import (
	"log"
	"moneef/internal/config"
	"moneef/internal/currencies"
	"moneef/internal/db"
	"moneef/internal/models"
)

func getExchangeRateApiKey() string {
	var settings models.UserSettings
	if err := db.DB.Where("exchange_rate_api_key != ''").First(&settings).Error; err == nil && settings.ExchangeRateApiKey != "" {
		return settings.ExchangeRateApiKey
	}
	return config.GetConfig().ExchangeRateApiKey
}

func main() error {
	apiKey := getExchangeRateApiKey()
	if apiKey == "" {
		log.Printf("⚠️ [CRON] No exchange rate API key — skipping rate fetch")
		return nil
	}
	return currencies.FetchRatesFromAPI(apiKey)
}
