//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"time"

	dashsvc "moneef/internal/dashboard/service"
)

// DashboardRequest carries the (optional) period bounds. Both dates are
// RFC3339 strings; missing/empty means use the current calendar month.
type DashboardRequest struct {
	DateFrom string `json:"date_from"`
	DateTo   string `json:"date_to"`
}

func Dashboard(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req DashboardRequest
	if len(payload) > 0 {
		if err := json.Unmarshal(payload, &req); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
		}
	}
	var from, to *time.Time
	if req.DateFrom != "" {
		t, err := time.Parse(time.RFC3339, req.DateFrom)
		if err != nil {
			return nil, fmt.Errorf("invalid date_from: %w", err)
		}
		from = &t
	}
	if req.DateTo != "" {
		t, err := time.Parse(time.RFC3339, req.DateTo)
		if err != nil {
			return nil, fmt.Errorf("invalid date_to: %w", err)
		}
		to = &t
	}
	resp, err := dashsvc.GetDashboard(pid, from, to)
	if err != nil {
		return nil, err
	}
	return json.Marshal(resp)
}
