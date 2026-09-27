package utils

import (
	"moneef/internal/analysis/dto"
	"moneef/pkg/types"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestFillMissingDatesCombinesPaymentsOnTheSameDay(t *testing.T) {
	start := time.Date(2026, 9, 25, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 0, 3).Add(-time.Millisecond)
	amounts := []dto.AmountPerDay{
		{Date: start.Add(42 * time.Hour), Amount: types.MoneyFromInt(30)},
		{Date: start.Add(32 * time.Hour), Amount: types.MoneyFromInt(10)},
		{Date: start.Add(36 * time.Hour), Amount: types.MoneyFromInt(20)},
	}
	days := FillMissingDates(amounts, start, end)
	require.Len(t, days, 3, "one entry per calendar day, including zero-spend days")
	for i, day := range days {
		require.Equal(t, start.AddDate(0, 0, i), day.Date)
	}
	require.Equal(t, "0", days[0].Amount.String())
	require.Equal(t, "60", days[1].Amount.String(), "keep all three payments")
	require.Equal(t, "0", days[2].Amount.String())
}

func TestFillMissingDatesUsesCalendarBoundsAndRangeTimezone(t *testing.T) {
	zone := time.FixedZone("UTC+3", 3*60*60)
	start := time.Date(2026, 9, 30, 12, 0, 0, 0, zone)
	end := time.Date(2026, 10, 1, 10, 0, 0, 0, zone)
	days := FillMissingDates([]dto.AmountPerDay{
		{Date: time.Date(2026, 9, 30, 22, 0, 0, 0, time.UTC), Amount: types.MoneyFromInt(8)},
	}, start, end)
	require.Len(t, days, 2)
	require.Equal(t, "2026-09-30", days[0].Date.Format(time.DateOnly))
	require.Equal(t, "0", days[0].Amount.String())
	require.Equal(t, "2026-10-01", days[1].Date.Format(time.DateOnly))
	require.Equal(t, "8", days[1].Amount.String())
}
