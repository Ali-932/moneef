//go:build smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
