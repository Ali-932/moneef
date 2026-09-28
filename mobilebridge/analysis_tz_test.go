//go:build smoke

package mobilebridge

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestAnalysisGroupsDaysInDeviceZone(t *testing.T) {
	if os.Getenv("MONEEF_ANALYSIS_TZ_TEST_PROCESS") != "1" {
		cmd := exec.Command(os.Args[0], "-test.run=^TestAnalysisGroupsDaysInDeviceZone$")
		cmd.Env = append(os.Environ(), "MONEEF_ANALYSIS_TZ_TEST_PROCESS=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("analysis subprocess: %v\n%s", err, output)
		}
		return
	}
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(filepath.Join(t.TempDir(), "analysis.sqlite"), 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Tz","last_name":"Test","currency_code":"USD","language":"en"}`))
	must(err)
	raw, err := CreateCategory([]byte(`{"name":"Tz food","type":"expense","icon":"mdi:food","color":"#6250D5"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(raw, &cat))
	// Dates as the app sends them: UTC. Local (UTC+3) days in comments.
	for _, p := range []struct{ date, amount string }{
		{"2026-08-31T21:30:00Z", "5.00"},   // Sep 1 00:30
		{"2026-09-01T21:00:00Z", "100.00"}, // Sep 2 00:00, date-picked
		{"2026-09-02T10:00:00Z", "20.00"},  // Sep 2 13:00
	} {
		body, _ := json.Marshal(map[string]any{
			"transaction_name": "Tz", "currency_code": "USD", "transaction_type": "expense", "date": p.date,
			"transaction_categories": []map[string]any{{"category_id": cat.ID, "amount": p.amount}},
		})
		_, err = CreateTransaction(body)
		must(err)
	}
	// Local Sep 1 00:00 .. Sep 3 23:59:59 at UTC+3, sent as UTC plus the offset.
	raw, err = Analysis([]byte(`{"start_date":"2026-08-31T21:00:00Z","end_date":"2026-09-03T20:59:59Z","currency":"USD","tz_offset_minutes":180}`))
	must(err)
	var charts struct {
		Total       string `json:"total"`
		SpentPerDay []struct {
			Date   string `json:"date"`
			Amount string `json:"amount"`
		} `json:"spent_per_day"`
	}
	must(json.Unmarshal(raw, &charts))
	want := [][2]string{{"2026-09-01T00:00:00Z", "5"}, {"2026-09-02T00:00:00Z", "120"}, {"2026-09-03T00:00:00Z", "0"}}
	if len(charts.SpentPerDay) != len(want) || charts.Total != "125" {
		t.Fatalf("got total %s, days %+v", charts.Total, charts.SpentPerDay)
	}
	for i, w := range want {
		if charts.SpentPerDay[i].Date != w[0] || charts.SpentPerDay[i].Amount != w[1] {
			t.Fatalf("day %d: got %+v, want %v", i, charts.SpentPerDay[i], w)
		}
	}
}
