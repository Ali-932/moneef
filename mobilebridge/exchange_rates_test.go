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
)

func TestTransactionKeepsItsUsdRate(t *testing.T) {
	if os.Getenv("MONEEF_RATES_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestTransactionKeepsItsUsdRate$")
		cmd.Env = append(os.Environ(), "MONEEF_RATES_TEST_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("rates subprocess: %v\n%s", err, output)
		}
		return
	}
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(filepath.Join(t.TempDir(), "rates.sqlite"), 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Rates","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	raw, err := CreateCategory([]byte(`{"name":"Rates food","type":"expense","icon":"mdi:food","color":"#6250D5"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(raw, &cat))
	setRate := func(rate string) {
		must(UpsertExchangeRate([]byte(`{"from":"USD","to":"IQD","rate":"` + rate + `"}`)))
	}
	expectSpent := func(want string) {
		t.Helper()
		raw, err := Dashboard([]byte(`{"date_from":"2026-09-01T00:00:00Z","date_to":"2026-09-30T23:59:59Z"}`))
		must(err)
		var d struct {
			TotalExpense string `json:"total_expense"`
		}
		must(json.Unmarshal(raw, &d))
		if d.TotalExpense != want {
			t.Fatalf("spent %s, want %s", d.TotalExpense, want)
		}
	}

	// IQD picked while the default is USD: 150,000 at 1,500 is $100.
	setRate("1500")
	_, err = CreateTransaction([]byte(fmt.Sprintf(`{"transaction_name":"Rates","currency_code":"IQD",
		"transaction_type":"expense","date":"2026-09-10T10:00:00Z",
		"transaction_categories":[{"category_id":%d,"amount":"150000"}]}`, cat.ID)))
	must(err)
	expectSpent("100")

	setRate("1300") // a new rate must not re-value the saved expense
	expectSpent("100")

	var id int64
	must(dbHandle.Raw("SELECT id FROM transactions").Scan(&id).Error)
	_, err = UpdateTransaction(id, []byte(fmt.Sprintf(
		`{"currency_code":"IQD","transaction_categories":[{"category_id":%d,"amount":"300000"}]}`, cat.ID)))
	must(err)
	expectSpent("200") // same currency: the frozen 1,500 stays
}

func TestRatesAreAnchoredToUsd(t *testing.T) {
	if os.Getenv("MONEEF_ANCHOR_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestRatesAreAnchoredToUsd$")
		cmd.Env = append(os.Environ(), "MONEEF_ANCHOR_TEST_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("anchor subprocess: %v\n%s", err, output)
		}
		return
	}
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(filepath.Join(t.TempDir(), "anchor.sqlite"), 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Anchor","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	listed := func() string {
		raw, err := ListExchangeRates(nil)
		must(err)
		var rows []struct {
			From string `json:"currency_code_1"`
		}
		must(json.Unmarshal(raw, &rows))
		var codes []string
		for _, r := range rows {
			codes = append(codes, r.From)
		}
		return strings.Join(codes, ",")
	}
	rate := func(from, to string) string {
		var r string
		must(dbHandle.Raw("SELECT rate FROM currency_exchange_rates WHERE currency_code1 = ? AND currency_code2 = ?", from, to).Scan(&r).Error)
		return r
	}

	must(UpsertExchangeRate([]byte(`{"from":"USD","to":"EUR","rate":"0.9"}`)))
	must(UpsertExchangeRate([]byte(`{"from":"USD","to":"IQD","rate":"1500"}`)))
	must(UpdateSettings([]byte(`{"currency_code":"IQD"}`)))
	// A new default doesn't change the list: every rate stays against USD.
	if got := listed(); got != "EUR,IQD" {
		t.Fatalf("listed %q after switching to IQD, want EUR,IQD", got)
	}
	// Other currencies convert straight to the new default.
	if got := rate("EUR", "IQD"); !strings.HasPrefix(got, "1666.66") {
		t.Fatalf("1 EUR = %s IQD, want 1500 / 0.9", got)
	}
	// A currency added under IQD still gets a USD rate to freeze on its transactions.
	must(UpsertExchangeRate([]byte(`{"from":"GBP","to":"USD","rate":"1.25"}`)))
	if got := rate("USD", "GBP"); got != "0.8" {
		t.Fatalf("1 USD = %s GBP, want 0.8", got)
	}
	if err := UpsertExchangeRate([]byte(`{"from":"IQD","to":"EUR","rate":"0.0006"}`)); err == nil {
		t.Fatal("saved a rate with no USD side")
	}
}
