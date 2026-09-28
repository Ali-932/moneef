package tests

import (
	"testing"
	"time"

	"github.com/shopspring/decimal"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/transactions/service"
	"moneef/pkg/types"
)

func TestRecurrenceTimelineCurrencyMatchesAmount(t *testing.T) {
	for _, converted := range []bool{false, true} {
		name := "missing rate keeps original currency"
		if converted {
			name = "converted amount uses base currency"
		}
		t.Run(name, func(t *testing.T) {
			suite := NewTestSuite(t)
			defer suite.Cleanup()
			require.NoError(t, suite.DB.Create(&models.Currency{Code: "IQD", Name: "Iraqi dinar"}).Error)
			if converted {
				require.NoError(t, suite.DB.Create(&models.CurrencyExchangeRate{
					CurrencyCode1: "IQD", CurrencyCode2: "USD", Rate: decimal.RequireFromString("0.001"),
				}).Error)
			}
			amount := types.MoneyFromInt(500000)
			require.NoError(t, suite.DB.Create(&models.RecurrenceTemplate{
				ProfileID: testProfileID, Name: "Rent", Type: "expense", Frequency: "monthly",
				NextDate: time.Now().UTC().AddDate(0, 0, 5), NextPaymentAmount: &amount, CurrencyCode: "IQD", IsActive: true,
			}).Error)
			occurrences, err := service.GetRecurrenceTimeline(testProfileID)
			require.NoError(t, err)
			require.NotEmpty(t, occurrences)
			for _, occurrence := range occurrences {
				if converted {
					require.Equal(t, "USD", occurrence.Currency)
					require.Equal(t, "500", occurrence.Amount.String())
				} else {
					require.Equal(t, "IQD", occurrence.Currency)
					require.Equal(t, "500000", occurrence.Amount.String())
				}
			}
		})
	}
}

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
