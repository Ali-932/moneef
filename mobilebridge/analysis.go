//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"time"

	anasvc "moneef/internal/analysis/service"
	usersvc "moneef/internal/users/service"
)

// AnalysisRequest is the in-process equivalent of
// dto.SpendByCategoryChartRequest plus an explicit currency override. When
// currency is empty the shim resolves it from the user's settings.
type AnalysisRequest struct {
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
	Currency  string `json:"currency"`
	// TZOffsetMinutes is the device's UTC offset; daily totals are grouped
	// by calendar days in that zone. 0 keeps UTC days.
	TZOffsetMinutes int `json:"tz_offset_minutes"`
}

func Analysis(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req AnalysisRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	if req.StartDate == "" || req.EndDate == "" {
		return nil, fmt.Errorf("start_date and end_date are required")
	}
	start, err := time.Parse(time.RFC3339, req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start_date: %w", err)
	}
	end, err := time.Parse(time.RFC3339, req.EndDate)
	if err != nil {
		return nil, fmt.Errorf("invalid end_date: %w", err)
	}
	currency := req.Currency
	if currency == "" {
		profile, perr := usersvc.GetProfile(pid)
		if perr != nil {
			return nil, fmt.Errorf("resolve profile for currency: %w", perr)
		}
		settings, serr := usersvc.GetSettings(profile.UserID)
		if serr != nil {
			return nil, fmt.Errorf("resolve settings for currency: %w", serr)
		}
		currency = settings.CurrencyCode
	}
	loc := time.FixedZone("", req.TZOffsetMinutes*60)
	charts, err := anasvc.GetAllAnalysisChartsService(pid, start.In(loc), end.In(loc), currency)
	if err != nil {
		return nil, err
	}
	return json.Marshal(charts)
}
