package users

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/shopspring/decimal"

	"moneef/internal/currencies"
	userService "moneef/internal/users/service"
	"moneef/pkg/middleware"
	"moneef/pkg/utils"
)

func ListExchangeRatesHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextKeyUserID).(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	settings, err := userService.GetSettings(userID)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to get settings")
		return
	}

	base := r.URL.Query().Get("base")
	if base == "" {
		base = settings.CurrencyCode
	}

	rates, err := currencies.GetExchangeRates(base)
	if err != nil {
		log.Printf("❌ [HANDLER] Failed to list rates: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list rates")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(rates)
}

type upsertRateRequest struct {
	From string `json:"from"`
	To   string `json:"to"`
	Rate string `json:"rate"`
}

func UpsertExchangeRateHandler(w http.ResponseWriter, r *http.Request) {
	_, ok := r.Context().Value(middleware.ContextKeyUserID).(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req upsertRateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid input")
		return
	}
	if req.From == "" || req.To == "" || req.Rate == "" {
		utils.WriteJsonError(w, http.StatusBadRequest, "from, to, and rate are required")
		return
	}

	rate, err := decimal.NewFromString(req.Rate)
	if err != nil || rate.LessThanOrEqual(decimal.Zero) {
		utils.WriteJsonError(w, http.StatusBadRequest, "rate must be a positive number")
		return
	}

	if err := currencies.CreateUpdateCurrencyRate(req.From, req.To, rate); err != nil {
		log.Printf("❌ [HANDLER] Failed to upsert rate: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to save rate")
		return
	}
	inverse := decimal.NewFromInt(1).Div(rate)
	if err := currencies.CreateUpdateCurrencyRate(req.To, req.From, inverse); err != nil {
		log.Printf("❌ [HANDLER] Failed to upsert inverse rate: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to save inverse rate")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "rate updated"})
}

func FetchExchangeRatesHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextKeyUserID).(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	settings, err := userService.GetSettings(userID)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to get settings")
		return
	}

	if settings.ExchangeRateApiKey == "" {
		utils.WriteJsonError(w, http.StatusBadRequest, "No API key configured — add one in Profile > Exchange Rate API")
		return
	}

	if err := currencies.FetchRatesFromAPI(settings.ExchangeRateApiKey); err != nil {
		log.Printf("❌ [HANDLER] Rate fetch failed: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "rates updated"})
}
