//go:build smoke

package mobilebridge

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"moneef/internal/models"
)

func TestUpdateRecurrenceOffline(t *testing.T) {
	// Mobile config pins one database path per process. Isolate this test from
	// the backup suite so each can use its own temporary database in any order.
	if os.Getenv("MONEEF_RECURRENCE_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestUpdateRecurrenceOffline$")
		cmd.Env = append(os.Environ(), "MONEEF_RECURRENCE_TEST_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("recurrence subprocess: %v\n%s", err, output)
		}
		return
	}
	path := filepath.Join(t.TempDir(), "recurrences.sqlite")
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(path, 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Recurring","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	profileID := ActiveProfileID()
	category, err := CreateCategory([]byte(`{"name":"Rent test","type":"expense","icon":"mdi:home","color":"#6250D5"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(category, &cat))
	// Yesterday, so the next monthly occurrence is always in the future and
	// nothing extra gets booked on creation.
	start := time.Now().UTC().AddDate(0, 0, -1).Truncate(24 * time.Hour).Add(12 * time.Hour)
	body, _ := json.Marshal(map[string]any{
		"transaction_name": "Rent", "currency_code": "USD", "transaction_type": "expense",
		"date": start.Format(time.RFC3339), "is_recurrent": true, "recurrent_freq": "monthly",
		"transaction_categories": []map[string]any{{"category_id": cat.ID, "amount": "500.00"}},
	})
	_, err = CreateTransaction(body)
	must(err)
	read := func() models.RecurrenceTemplate {
		t.Helper()
		raw, e := ListRecurrences()
		must(e)
		var items []models.RecurrenceTemplate
		must(json.Unmarshal(raw, &items))
		if len(items) != 1 {
			t.Fatalf("expected one recurrence: %s", raw)
		}
		return items[0]
	}
	original := read()
	id := int64(original.ID)
	valid := map[string]any{
		"name": "Office rent", "frequency": "weekly", "next_date": "2099-10-10T12:00:00Z",
		"has_end_date": true, "end_date": "2099-12-31T23:59:59Z", "is_active": false,
		"merchant_name": "Landlord", "notes": "New weekly schedule",
	}
	encode := func(v any) []byte { b, e := json.Marshal(v); must(e); return b }
	must(UpdateRecurrence(id, encode(valid)))
	got := read()
	if got.Name != "Office rent" || got.Frequency != "weekly" || got.IsActive || !got.HasEndDate || got.EndDate == nil || got.NextDate.Day() != 10 || *got.Notes != "New weekly schedule" || *got.MerchantName != "Landlord" {
		t.Fatalf("details not saved: %+v", got)
	}
	if got.Type != original.Type || got.CurrencyCode != original.CurrencyCode || got.NextPaymentAmount.String() != original.NextPaymentAmount.String() || len(got.TransactionCategory) != len(original.TransactionCategory) || got.TransactionCategory[0].CategoryID != original.TransactionCategory[0].CategoryID || got.TransactionCategory[0].Amount.String() != original.TransactionCategory[0].Amount.String() {
		t.Fatal("editing the schedule changed financial fields")
	}
	var booked []models.Transaction
	must(dbHandle.Where("profile_id = ?", profileID).Find(&booked).Error)
	if len(booked) != 1 || booked[0].Name != "Rent" || booked[0].Date.Day() != start.Day() {
		t.Fatal("editing the template modified recorded transactions")
	}
	for _, bad := range []map[string]any{
		{"name": "  "}, {"frequency": "quarterly"}, {"next_date": "invalid"},
		{"end_date": "2026-01-01T00:00:00Z"}, {"end_date": nil},
		{"is_active": nil}, {"next_payment_amount": "1.00"}, {"profile_id": 999},
	} {
		payload := map[string]any{}
		for k, v := range valid {
			payload[k] = v
		}
		for k, v := range bad {
			payload[k] = v
		}
		if e := UpdateRecurrence(id, encode(payload)); e == nil {
			t.Fatalf("accepted invalid update: %v", bad)
		}
		if string(encode(read())) != string(encode(got)) {
			t.Fatalf("invalid update changed the template: %v", bad)
		}
	}
	if UpdateRecurrence(0, encode(valid)) == nil || UpdateRecurrence(999999, encode(valid)) == nil {
		t.Fatal("accepted missing recurrence")
	}
	must(SetProfileID(profileID + 1000))
	if UpdateRecurrence(id, encode(valid)) == nil {
		t.Fatal("updated another profile's recurrence")
	}
	must(SetProfileID(profileID))
	valid["has_end_date"], valid["end_date"], valid["is_active"] = false, nil, true
	valid["notes"], valid["merchant_name"] = "", ""
	must(UpdateRecurrence(id, encode(valid)))
	must(Shutdown())
	must(Init(path, profileID))
	got = read()
	if got.HasEndDate || got.EndDate != nil || !got.IsActive || *got.Notes != "" || *got.MerchantName != "" {
		t.Fatal("cleared details or status did not survive reopening the database")
	}
	expected, _ := time.Parse(time.RFC3339, "2099-10-10T12:00:00Z")
	if !got.NextDate.Equal(expected) {
		t.Fatal("next payment date changed after reopening")
	}
	// Reopening the app books the payments that fell due while it was closed:
	// weekly from 8 days ago is due twice.
	valid["next_date"] = time.Now().AddDate(0, 0, -8).UTC().Format(time.RFC3339)
	must(UpdateRecurrence(id, encode(valid)))
	must(Shutdown())
	must(Init(path, profileID))
	var afterReopen []models.Transaction
	must(dbHandle.Where("profile_id = ?", profileID).Find(&afterReopen).Error)
	if len(afterReopen) != 3 || !read().NextDate.After(time.Now()) {
		t.Fatalf("reopening booked %d transactions, want 2 more", len(afterReopen)-1)
	}
}
