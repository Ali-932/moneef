package tests

import (
	analysis "moneef/internal/analysis/service"
	"moneef/internal/models"
	"moneef/pkg/types"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// A UTC+3 user's range and payments must land on their local calendar days,
// matching the Activity list.
func TestAnalysisBucketsDaysInCallerZone(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	zone := time.FixedZone("", 3*60*60)
	start := time.Date(2026, 9, 1, 0, 0, 0, 0, zone)
	end := time.Date(2026, 9, 3, 23, 59, 59, 0, zone)
	for _, p := range []struct {
		at     time.Time
		amount int64
	}{
		{time.Date(2026, 9, 1, 0, 30, 0, 0, zone), 5},  // Aug 31 21:30Z
		{time.Date(2026, 9, 2, 0, 0, 0, 0, zone), 100}, // date-picked: Sep 1 21:00Z
		{time.Date(2026, 9, 2, 13, 0, 0, 0, zone), 20},
	} {
		amount := types.MoneyFromInt(p.amount)
		txn := models.Transaction{
			ProfileID: testProfileID, Name: "Local day", Type: "expense", CurrencyCode: "USD",
			Date:                p.at.UTC(), // stored as the app sends it
			TransactionCategory: []models.TransactionCategory{{CategoryID: 1, Amount: &amount}},
		}
		require.NoError(t, suite.DB.Create(&txn).Error)
	}
	charts, err := analysis.GetAllAnalysisChartsService(testProfileID, start, end, "USD")
	require.NoError(t, err)
	require.Len(t, charts.SpentPerDay, 3)
	for i, want := range []struct{ day, amount string }{{"2026-09-01", "5"}, {"2026-09-02", "120"}, {"2026-09-03", "0"}} {
		require.Equal(t, want.day, charts.SpentPerDay[i].Date.Format(time.DateOnly))
		require.Equal(t, time.UTC, charts.SpentPerDay[i].Date.Location())
		require.Equal(t, want.amount, charts.SpentPerDay[i].Amount.String())
	}
	require.Equal(t, "125", charts.Total.String())
}
