package tests

import (
	analysis "moneef/internal/analysis/service"
	"moneef/internal/models"
	"moneef/pkg/types"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestAnalysisCombinesSameDayTransactions(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	start := time.Date(2026, 9, 25, 0, 0, 0, 0, time.UTC)
	end := time.Date(2026, 9, 27, 23, 59, 59, 0, time.UTC)
	for i, hour := range []int{8, 12, 18} {
		amount := types.MoneyFromInt(int64((i + 1) * 10))
		txn := models.Transaction{
			ProfileID: testProfileID, Name: "Same day payment", Type: "expense", CurrencyCode: "USD",
			Date:                start.AddDate(0, 0, 1).Add(time.Duration(hour) * time.Hour),
			TransactionCategory: []models.TransactionCategory{{CategoryID: 1, Amount: &amount}},
		}
		require.NoError(t, suite.DB.Create(&txn).Error)
	}
	charts, err := analysis.GetAllAnalysisChartsService(testProfileID, start, end, "USD")
	require.NoError(t, err)
	require.Len(t, charts.SpentPerDay, 3)
	require.Equal(t, "2026-09-26", charts.SpentPerDay[1].Date.Format(time.DateOnly))
	require.Equal(t, "60", charts.SpentPerDay[1].Amount.String())
	require.Len(t, charts.SpentPerDayLastPeriod, 3)
	for _, day := range charts.SpentPerDayLastPeriod {
		require.True(t, day.Date.Before(start), "previous period must not include the current period's first day")
	}
	total := types.MoneyZero()
	for _, day := range charts.SpentPerDay {
		total = total.Add(day.Amount)
	}
	require.True(t, MoneyEqual(charts.Total, total), "chart totals must match overall spending")
}
