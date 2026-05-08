package tests

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/internal/patterns/pattern_engine"
)

func TestPatternEngineWeekendSpike(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	// Seed 40 transactions: 30 weekend at $100 each, 10 weekday at $50 each
	// Weekend avg = $100, weekday avg = $50 → 100% diff > 30% threshold
	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC) // Monday Jan 6
	weekendDates := []int{5, 6}                             // Saturday=5, Sunday=6 offset from Monday
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	// Weekend transactions: 15 Sat + 15 Sun = 30
	for i := 0; i < 30; i++ {
		dayOffset := weekendDates[i%2]
		date := baseDate.AddDate(0, 0, (i/2)*7+dayOffset)
		createTestTransaction(suite, date, "expense", 100.0, &foodCat)
	}

	// Weekday transactions: 10 Mon-Fri at $50
	weekdayOffsets := []int{0, 1, 2, 3, 4, 7, 8, 9, 10, 11}
	for _, offset := range weekdayOffsets {
		date := baseDate.AddDate(0, 0, offset)
		createTestTransaction(suite, date, "expense", 50.0, &foodCat)
	}

	patterns, err := pattern_engine.GetUserPatterns(testProfileID)
	require.NoError(t, err)

	// Should detect weekend spike
	foundWeekendSpike := false
	for _, p := range patterns {
		if p.Name == "Weekend Spending Spike" {
			foundWeekendSpike = true
			assert.Greater(t, p.FinalScore, 0.0)
			break
		}
	}
	assert.True(t, foundWeekendSpike, "Expected Weekend Spending Spike pattern to be detected")

	// Should detect category patterns
	foundTopCategory := false
	for _, p := range patterns {
		if p.Name == "Top Spending Category" {
			foundTopCategory = true
			break
		}
	}
	assert.True(t, foundTopCategory, "Expected Top Spending Category pattern to be detected")
}

func TestPatternEngineSortedByScore(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC)
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	for i := 0; i < 35; i++ {
		dayOffset := []int{5, 6}[i%2]
		date := baseDate.AddDate(0, 0, (i/2)*7+dayOffset)
		createTestTransaction(suite, date, "expense", 100.0, &foodCat)
	}
	for i := 0; i < 10; i++ {
		date := baseDate.AddDate(0, 0, i*3)
		createTestTransaction(suite, date, "expense", 50.0, &foodCat)
	}

	patterns, err := pattern_engine.GetUserPatterns(testProfileID)
	require.NoError(t, err)
	require.GreaterOrEqual(t, len(patterns), 2, "Expected at least 2 patterns")

	// Verify descending sort by FinalScore
	for i := 1; i < len(patterns); i++ {
		assert.GreaterOrEqual(t, patterns[i-1].FinalScore, patterns[i].FinalScore,
			"Patterns should be sorted by FinalScore descending")
	}
}

func TestPatternEngineNoTransactions(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	patterns, err := pattern_engine.GetUserPatterns(testProfileID)
	require.NoError(t, err)
	assert.Empty(t, patterns, "Should return empty patterns when no transactions exist")
}

func TestPatternEngineInsufficientTransactions(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC)
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	// Only 5 transactions — below all detector minimums
	for i := 0; i < 5; i++ {
		createTestTransaction(suite, baseDate.AddDate(0, 0, i), "expense", 50.0, &foodCat)
	}

	patterns, err := pattern_engine.GetUserPatterns(testProfileID)
	require.NoError(t, err)
	assert.Empty(t, patterns, "Should return empty patterns when transaction count is below all detector minimums")
}

func createTestTransaction(suite *TestSuite, date time.Time, txType string, amount float64, category *models.Category) {
	tx := &models.Transaction{
		ProfileID:    testProfileID,
		Name:         "Test Transaction",
		Type:         txType,
		Date:         date,
		CurrencyCode: "USD",
	}
	err := suite.DB.Create(tx).Error
	require.NoError(suite.T, err)

	if category != nil {
		amt := MoneyFromFloat(amount)
		txCat := &models.TransactionCategory{
			TransactionID: tx.ID,
			CategoryID:    category.ID,
			Amount:        &amt,
		}
		err = suite.DB.Create(txCat).Error
		require.NoError(suite.T, err)
	}
}
