//go:build smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"moneef/internal/models"
	txnsvc "moneef/internal/transactions/service"
)

func TestRecurringDatesFollowThePhoneCalendar(t *testing.T) {
	if os.Getenv("MONEEF_RECURRING_DATES_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestRecurringDatesFollowThePhoneCalendar$")
		cmd.Env = append(os.Environ(), "MONEEF_RECURRING_DATES_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("recurring dates subprocess: %v\n%s", err, output)
		}
		return
	}
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	// UTC+3: a local midnight is the previous day in UTC.
	must(SetTimeZone("Asia/Baghdad"))
	must(Init(filepath.Join(t.TempDir(), "dates.sqlite"), 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Dates","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	raw, err := CreateCategory([]byte(`{"name":"Bills","type":"expense","icon":"mdi:home","color":"#6250D5"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(raw, &cat))

	// Dates as the date picker sends them: local midnight, in UTC.
	monthly := func(name, localDate, amount, plan string) error {
		d, _ := time.ParseInLocation("2006-01-02", localDate, time.Local)
		_, err := CreateTransaction([]byte(fmt.Sprintf(`{"transaction_name":%q,"currency_code":"USD",
			"transaction_type":"expense","date":%q,"is_recurrent":true,"recurrent_freq":"monthly",%s
			"transaction_categories":[{"category_id":%d,"amount":%q}]}`,
			name, d.UTC().Format(time.RFC3339), plan, cat.ID, amount)))
		return err
	}
	must(monthly("Rent", "2026-10-01", "500", ""))
	must(monthly("Bill", "2027-01-31", "30", ""))
	// Only 10 is left on this loan, so a 20 payment is refused.
	if err := monthly("Loan", "2026-10-05", "20", `"recurrent_has_end_date":true,
		"recurrent_end_date":"2027-06-01T00:00:00Z","recurrent_total_amount":"100",
		"recurrent_paid_previously":"90",`); err == nil {
		t.Fatal("saved a payment bigger than what was left to pay")
	}

	pid, err := getProfileID()
	must(err)
	_, err = txnsvc.CreateDueRecurrences(pid, time.Date(2027, 5, 15, 0, 0, 0, 0, time.UTC))
	must(err)
	booked := func(name string) string {
		var txs []models.Transaction
		must(dbHandle.Where("name = ?", name).Order("date").Find(&txs).Error)
		var days []string
		for _, tx := range txs {
			days = append(days, tx.Date.Local().Format("Jan 2"))
		}
		return strings.Join(days, ", ")
	}
	if got, want := booked("Rent"), "Oct 1, Nov 1, Dec 1, Jan 1, Feb 1, Mar 1, Apr 1, May 1"; got != want {
		t.Fatalf("rent booked on %s, want %s", got, want)
	}
	// February is capped, not skipped. Later months step from the stored 28th.
	if got, want := booked("Bill"), "Jan 31, Feb 28, Mar 28, Apr 28"; got != want {
		t.Fatalf("bill booked on %s, want %s", got, want)
	}
}
