//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"time"

	"moneef/internal/db"
	"moneef/internal/patterns/engine"
	"moneef/internal/patterns/pattern_engine"
	patternsrepo "moneef/internal/patterns/repository"
)

// RefreshPatternsRequest accepts an optional time window. Empty strings mean
// all-time analysis (matching the HTTP handler behavior).
type RefreshPatternsRequest struct {
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

func Patterns() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	list, err := patternsrepo.GetPatternsByProfileID(db.DB, pid)
	if err != nil {
		return nil, err
	}
	if list == nil {
		return []byte("[]"), nil
	}
	return json.Marshal(list)
}

func RefreshPatterns(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req RefreshPatternsRequest
	if len(payload) > 0 {
		if err := json.Unmarshal(payload, &req); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
		}
	}
	var start, end *time.Time
	if req.StartDate != "" {
		t, err := time.Parse(time.RFC3339, req.StartDate)
		if err != nil {
			return nil, fmt.Errorf("invalid start_date: %w", err)
		}
		start = &t
	}
	if req.EndDate != "" {
		t, err := time.Parse(time.RFC3339, req.EndDate)
		if err != nil {
			return nil, fmt.Errorf("invalid end_date: %w", err)
		}
		end = &t
	}
	list, err := pattern_engine.GetUserPatterns(pid, start, end)
	if err != nil {
		return nil, err
	}
	for i := range list {
		engine.ResolvePatternIconInMemory(&list[i])
	}
	if list == nil {
		return []byte("[]"), nil
	}
	return json.Marshal(list)
}
