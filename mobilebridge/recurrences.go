//go:build android || smoke

package mobilebridge

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"strings"
	"time"

	txnsvc "moneef/internal/transactions/service"

	"gorm.io/gorm"
)

// UpdateRecurrence saves the editable schedule details from the mobile form.
// It does not modify the amount, categories, or already recorded transactions.
func UpdateRecurrence(id int64, payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.UpdateRecurrence: id must be > 0")
	}
	var req struct {
		Name         string     `json:"name"`
		Frequency    string     `json:"frequency"`
		NextDate     time.Time  `json:"next_date"`
		EndDate      *time.Time `json:"end_date"`
		HasEndDate   *bool      `json:"has_end_date"`
		IsActive     *bool      `json:"is_active"`
		Notes        string     `json:"notes"`
		MerchantName string     `json:"merchant_name"`
	}
	decoder := json.NewDecoder(bytes.NewReader(payload))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return fmt.Errorf("%w: expected one JSON object", ErrInvalidPayload)
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return fmt.Errorf("enter a recurring payment name")
	}
	switch req.Frequency {
	case "daily", "weekly", "bi-weekly", "monthly", "yearly":
	default:
		return fmt.Errorf("select a valid recurrence frequency")
	}
	if req.NextDate.IsZero() {
		return fmt.Errorf("select the next payment date")
	}
	if req.HasEndDate == nil || req.IsActive == nil {
		return fmt.Errorf("has_end_date and is_active are required")
	}
	if *req.HasEndDate {
		if req.EndDate == nil || req.EndDate.IsZero() {
			return fmt.Errorf("select an end date")
		}
		if req.EndDate.Before(req.NextDate) {
			return fmt.Errorf("end date must be on or after the next payment")
		}
	}
	// A nil interface explicitly clears the stored date when the limit is off.
	var endDate any
	if *req.HasEndDate {
		endDate = *req.EndDate
	}
	err = txnsvc.UpdateRecurrence(pid, uint(id), map[string]interface{}{
		"name": req.Name, "frequency": req.Frequency, "next_date": req.NextDate,
		"has_end_date": *req.HasEndDate, "end_date": endDate, "is_active": *req.IsActive,
		"notes": strings.TrimSpace(req.Notes), "merchant_name": strings.TrimSpace(req.MerchantName),
	})
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return fmt.Errorf("recurring payment not found")
	}
	if err == nil {
		bookDueRecurrences() // a next date in the past has payments due now
	}
	return err
}

func bookDueRecurrences() {
	pid, err := getProfileID()
	if err != nil {
		return
	}
	if _, err := txnsvc.CreateDueRecurrences(pid, time.Now()); err != nil {
		log.Printf("mobile: booking due recurrences: %v", err)
	}
}
