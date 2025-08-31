/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"moneef/internal"
	"moneef/internal/db"
	"moneef/internal/services"
	"moneef/pkg/utils"
	"net/http"
	"time"

	"github.com/spf13/cobra"
)

type ExchangeRateResponse struct {
	Result          string             `json:"result"`
	BaseCode        string             `json:"base_code"`
	ConversionRates map[string]float64 `json:"conversion_rates"`
}

func fetchCurrencyRates(cmd *cobra.Command, args []string) error {
	client := &http.Client{
		Timeout: 30 * time.Second,
	}
	for _, currencyObject := range internal.Currencies {
		log.Printf("🌐 [CRON] Supported currency: %s", currencyObject.Code)
		endpoint := fmt.Sprintf("https://v6.exchangerate-api.com/v6/f5b4aaa9448c0f9a060ca1ef/latest/%s", currencyObject.Code)
		resp, err := utils.MakeRequestWithRetry(client, "GET", endpoint, nil)

		if err != nil {
			log.Println("Error fetching rates:", err)
			return err
		}
		log.Printf("Response status: %s", resp.Status)

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		var apiResponse ExchangeRateResponse

		if err := json.Unmarshal(body, &apiResponse); err != nil {
			log.Printf("Error unmarshalling response: %v", err)
			return err
		}
		if apiResponse.Result != "success" {
			return fmt.Errorf("API request failed: %s", apiResponse.Result)
		}
		err = services.CreateUpdateCurrencyRates(apiResponse.BaseCode, apiResponse.ConversionRates)

		if err != nil {
			log.Printf("Error reading response: %v", err)
			return err
		}

	}

	return nil
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
