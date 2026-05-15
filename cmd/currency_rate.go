package cmd

import (
	"moneef/internal/config"
	"moneef/internal/currencies"
	"moneef/internal/db"
	"moneef/internal/models"

	"github.com/spf13/cobra"
)

func getExchangeRateApiKey() string {
	var settings models.UserSettings
	if err := db.DB.Where("exchange_rate_api_key != ''").First(&settings).Error; err == nil && settings.ExchangeRateApiKey != "" {
		return settings.ExchangeRateApiKey
	}
	return config.GetConfig().ExchangeRateApiKey
}

func fetchCurrencyRates(cmd *cobra.Command, args []string) error {
	return currencies.FetchRatesFromAPI(getExchangeRateApiKey())
}

var fetchRatesCmd = &cobra.Command{
	Use:   "fetch-rates",
	Short: "Fetch exchange rates",
	Long:  "Fetch latest exchange rates for all supported currencies",
	RunE:  fetchCurrencyRates,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		_, err := db.Connect()
		return err
	},
}

func init() {
	rootCmd.AddCommand(fetchRatesCmd)

}
