package tests

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/transactions/service"
	"moneef/pkg/types"
)

func TestRecurrenceTimelineNext30Days(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	now := time.Now().UTC()
	windowStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	windowEnd := windowStart.AddDate(0, 0, 31)

	amt := MoneyFromFloat(50.0)
	tplSoon := &models.RecurrenceTemplate{
		ProfileID:         testProfileID,
		Name:              "Soon",
		Type:              "expense",
		Frequency:         "monthly",
		NextDate:          now.AddDate(0, 0, 5),
		NextPaymentAmount: &amt,
		CurrencyCode:      "USD",
		IsActive:          true,
	}
	require.NoError(t, db.DB.Create(tplSoon).Error)

	occurrences, err := service.GetRecurrenceTimeline(testProfileID)
	require.NoError(t, err)

	assert.True(t, len(occurrences) > 0, "Expected at least one occurrence from the 'Soon' template")

	for _, occ := range occurrences {
		assert.False(t, occ.Date.Before(windowStart), "occurrence %s on %s should not be before window start", occ.Name, occ.Date.Format("2006-01-02"))
		assert.False(t, occ.Date.After(windowEnd), "occurrence %s on %s should not be after window end (+31 days)", occ.Name, occ.Date.Format("2006-01-02"))
	}

	_ = types.Money{}
}

func TestRecurrenceTimelineNoCalendarMonth(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	now := time.Now().UTC()
	windowStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)

	amt := MoneyFromFloat(100.0)
	tpl := &models.RecurrenceTemplate{
		ProfileID:         testProfileID,
		Name:              "NextMonthTemplate",
		Type:              "expense",
		Frequency:         "monthly",
		NextDate:          now.AddDate(0, 0, 25),
		NextPaymentAmount: &amt,
		CurrencyCode:      "USD",
		IsActive:          true,
	}
	require.NoError(t, db.DB.Create(tpl).Error)

	occurrences, err := service.GetRecurrenceTimeline(testProfileID)
	require.NoError(t, err)

	for _, occ := range occurrences {
		diffDays := int(occ.Date.Sub(windowStart).Hours() / 24)
		assert.True(t, diffDays >= 0 && diffDays <= 30,
			"occurrence %s on %s is %d days from today, should be within 0-30 days",
			occ.Name, occ.Date.Format("2006-01-02"), diffDays)
	}

	_ = types.Money{}
}
