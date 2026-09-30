//go:build smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"moneef/internal/models"
)

func TestAccounts(t *testing.T) {
	if os.Getenv("MONEEF_ACCOUNTS_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestAccounts$")
		cmd.Env = append(os.Environ(), "MONEEF_ACCOUNTS_TEST_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("accounts subprocess: %v\n%s", err, output)
		}
		return
	}
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(filepath.Join(t.TempDir(), "accounts.sqlite"), 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Acc","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	raw, err := CreateCategory([]byte(`{"name":"Acc food","type":"expense","icon":"mdi:food","color":"#6250D5"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(raw, &cat))
	must(UpsertExchangeRate([]byte(`{"from":"USD","to":"IQD","rate":"1500"}`)))
	create := func(extra string) {
		t.Helper()
		_, err := CreateTransaction([]byte(fmt.Sprintf(`{"transaction_name":"Acc","transaction_type":"expense",
			"date":"2026-09-10T10:00:00Z","transaction_categories":[{"category_id":%d,"amount":"10"}],%s}`, cat.ID, extra)))
		must(err)
	}
	// balances returns "account name → currency → amount" plus each ≈ total.
	balances := func() (map[string]map[string]string, map[string]string, map[string]uint) {
		raw, err := ListAccounts()
		must(err)
		var list []struct {
			ID          uint   `json:"id"`
			Name        string `json:"name"`
			ApproxTotal string `json:"approx_total"`
			Balances    []struct{ Currency, Amount string }
		}
		must(json.Unmarshal(raw, &list))
		got, totals, ids := map[string]map[string]string{}, map[string]string{}, map[string]uint{}
		for _, a := range list {
			got[a.Name], totals[a.Name], ids[a.Name] = map[string]string{}, a.ApproxTotal, a.ID
			for _, b := range a.Balances {
				got[a.Name][b.Currency] = b.Amount
			}
		}
		return got, totals, ids
	}
	expect := func(got, want string) {
		t.Helper()
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	}

	// No account given: "Main" is created on first use and takes the expense.
	create(`"currency_code":"USD"`)
	got, _, ids := balances()
	expect(got["Main"]["USD"], "-10")

	raw, err = CreateAccount([]byte(`{"name":"Cash"}`))
	must(err)
	var cash models.Account
	must(json.Unmarshal(raw, &cash))
	create(fmt.Sprintf(`"currency_code":"IQD","account_id":%d`, cash.ID))

	// 20 USD out of Main, 30,000 IQD into Cash; then Cash really holds 5,000.
	_, err = CreateTransfer([]byte(fmt.Sprintf(`{"from_account_id":%d,"to_account_id":%d,
		"from_currency":"USD","from_amount":"20","to_currency":"IQD","to_amount":"30000"}`, ids["Main"], cash.ID)))
	must(err)
	must(SetBalance([]byte(fmt.Sprintf(`{"account_id":%d,"currency":"IQD","amount":"15000"}`, cash.ID))))
	got, totals, _ := balances()
	expect(got["Main"]["USD"], "-30")
	expect(got["Cash"]["IQD"], "15000")
	expect(totals["Cash"], "10") // ≈ 15,000 IQD at 1,500

	raw, err = ListTransactions([]byte(fmt.Sprintf(`{"account_id":%d}`, cash.ID)))
	must(err)
	var page struct {
		Count int64 `json:"count"`
	}
	must(json.Unmarshal(raw, &page))
	expect(fmt.Sprint(page.Count), "1")
	raw, err = ListTransfers(int64(cash.ID))
	must(err)
	var transfers []models.Transfer
	must(json.Unmarshal(raw, &transfers))
	expect(fmt.Sprint(len(transfers)), "2") // the transfer and the balance correction

	// A recurring payment remembers its account for every booking.
	_, err = CreateTransaction([]byte(fmt.Sprintf(`{"transaction_name":"Rent","transaction_type":"expense",
		"currency_code":"IQD","account_id":%d,"date":"2026-07-01T10:00:00Z","is_recurrent":true,
		"recurrent_freq":"monthly","transaction_categories":[{"category_id":%d,"amount":"1000"}]}`, cash.ID, cat.ID)))
	must(err)
	bookDueRecurrences()
	var stray int64
	must(dbHandle.Model(&models.Transaction{}).Where("name = ? AND account_id <> ?", "Rent", cash.ID).Count(&stray).Error)
	var rents int64
	must(dbHandle.Model(&models.Transaction{}).Where("name = ?", "Rent").Count(&rents).Error)
	if rents < 2 || stray != 0 {
		t.Fatalf("rent bookings: %d, outside Cash: %d", rents, stray)
	}

	if err := DeleteAccount(int64(cash.ID)); err == nil {
		t.Fatal("deleted an account that has activity")
	}
	raw, err = CreateAccount([]byte(`{"name":"Savings"}`))
	must(err)
	var savings models.Account
	must(json.Unmarshal(raw, &savings))
	must(DeleteAccount(int64(savings.ID)))
}
