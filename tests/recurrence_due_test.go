package tests

import (
	"moneef/internal/models"
	txnsvc "moneef/internal/transactions/service"
	"moneef/pkg/types"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// Opening the app books every payment that fell due while it was closed.
func TestCreateDueRecurrences(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	now := time.Date(2026, 9, 28, 9, 0, 0, 0, time.UTC)
	money := func(v int64) *types.Money { m := types.MoneyFromInt(v); return &m }
	endDate := time.Date(2027, 12, 31, 0, 0, 0, 0, time.UTC)

	rent := models.RecurrenceTemplate{
		ProfileID: testProfileID, Name: "Rent", Type: "expense", CurrencyCode: "USD",
		Frequency: "monthly", NextDate: time.Date(2026, 7, 15, 10, 0, 0, 0, time.UTC),
		NextPaymentAmount: money(500), IsActive: true,
		TransactionCategory: []models.RecurrenceTemplateCategory{{CategoryID: 3, Amount: money(500)}},
	}
	// 300 per month with 400 left: one full payment, then a final 100.
	loan := models.RecurrenceTemplate{
		ProfileID: testProfileID, Name: "Loan", Type: "expense", CurrencyCode: "USD",
		Frequency: "monthly", NextDate: time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		NextPaymentAmount: money(300), AmountLeftToPay: money(400), TotalAmountToPay: money(1000),
		HasEndDate: true, EndDate: &endDate, IsActive: true,
		TransactionCategory: []models.RecurrenceTemplateCategory{
			{CategoryID: 1, Amount: money(200)}, {CategoryID: 2, Amount: money(100)},
		},
	}
	later := models.RecurrenceTemplate{
		ProfileID: testProfileID, Name: "Gym", Type: "expense", CurrencyCode: "USD",
		Frequency: "weekly", NextDate: now.Add(time.Hour), NextPaymentAmount: money(20), IsActive: true,
		TransactionCategory: []models.RecurrenceTemplateCategory{{CategoryID: 4, Amount: money(20)}},
	}
	for _, tpl := range []*models.RecurrenceTemplate{&rent, &loan, &later} {
		require.NoError(t, suite.DB.Create(tpl).Error)
	}

	created, err := txnsvc.CreateDueRecurrences(testProfileID, now)
	require.NoError(t, err)
	require.Equal(t, 5, created)

	booked := func(id uint) []models.Transaction {
		var txns []models.Transaction
		require.NoError(t, suite.DB.Preload("TransactionCategory").
			Where("recurrence_template_id = ?", id).Order("date").Find(&txns).Error)
		return txns
	}
	total := func(txn models.Transaction) string {
		sum, err := txn.GetTotal(suite.DB)
		require.NoError(t, err)
		return sum.String()
	}

	rentTxns := booked(rent.ID)
	require.Len(t, rentTxns, 3)
	for i, day := range []string{"2026-07-15", "2026-08-15", "2026-09-15"} {
		require.Equal(t, day, rentTxns[i].Date.Format(time.DateOnly))
		require.Equal(t, 10, rentTxns[i].Date.Hour(), "time of day is kept")
		require.Equal(t, "500", total(rentTxns[i]))
	}
	require.NoError(t, suite.DB.First(&rent, rent.ID).Error)
	require.True(t, rent.NextDate.Equal(time.Date(2026, 10, 15, 10, 0, 0, 0, time.UTC)), rent.NextDate)
	require.True(t, rent.IsActive)

	loanTxns := booked(loan.ID)
	require.Len(t, loanTxns, 2)
	require.Equal(t, "300", total(loanTxns[0]))
	require.Equal(t, "100", total(loanTxns[1]), "last payment is what was left")
	require.NoError(t, suite.DB.First(&loan, loan.ID).Error)
	require.Equal(t, "0", loan.AmountLeftToPay.String())
	require.False(t, loan.IsActive, "paid-off plan stops")

	require.Empty(t, booked(later.ID))

	again, err := txnsvc.CreateDueRecurrences(testProfileID, now)
	require.NoError(t, err)
	require.Zero(t, again, "a second open books nothing")
}
