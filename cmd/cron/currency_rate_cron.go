package cron

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"moneef/internal"
	"moneef/internal/services"
	"net/http"
	"time"
)

type ExchangeRateResponse struct {
	Result          string             `json:"result"`
	BaseCode        string             `json:"base_code"`
	ConversionRates map[string]float64 `json:"conversion_rates"`
}

func main() error {
	client := &http.Client{
		Timeout: 30 * time.Second,
	}
	for _, currencyObject := range internal.Currencies {
		log.Printf("🌐 [CRON] Supported currency: %s", currencyObject.Code)
		endpoint := fmt.Sprintf("https://v6.exchangerate-api.com/v6/f5b4aaa9448c0f9a060ca1ef/latest/%s", currencyObject.Code)
		resp, err := client.Get(endpoint)

		if err != nil {
			return err
		}
		resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
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
