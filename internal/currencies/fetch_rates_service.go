package currencies

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"moneef/internal/config"
	"moneef/pkg/utils"
	"net/http"
	"time"
)

type exchangeRateAPIResponse struct {
	Result          string             `json:"result"`
	BaseCode        string             `json:"base_code"`
	ConversionRates map[string]float64 `json:"conversion_rates"`
}

func FetchRatesFromAPI(apiKey string) error {
	if apiKey == "" {
		return fmt.Errorf("no exchange rate API key configured")
	}
	client := &http.Client{Timeout: 30 * time.Second}
	for _, currencyObject := range config.Currencies {
		log.Printf("🌐 [RATES] Fetching %s", currencyObject.Code)
		endpoint := fmt.Sprintf("https://v6.exchangerate-api.com/v6/%s/latest/%s", apiKey, currencyObject.Code)
		resp, err := utils.MakeRequestWithRetry(client, "GET", endpoint, nil)
		if err != nil {
			return fmt.Errorf("fetch %s: %w", currencyObject.Code, err)
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var apiResp exchangeRateAPIResponse
		if err := json.Unmarshal(body, &apiResp); err != nil {
			return fmt.Errorf("unmarshal %s: %w", currencyObject.Code, err)
		}
		if apiResp.Result != "success" {
			return fmt.Errorf("API error for %s: %s", currencyObject.Code, apiResp.Result)
		}
		if err := CreateUpdateCurrencyRates(apiResp.BaseCode, apiResp.ConversionRates); err != nil {
			return err
		}
	}
	return nil
}
