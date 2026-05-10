package tests

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/internal/patterns/engine"
	"moneef/internal/patterns/pattern_engine"
)

func TestPatternEngineWeekendSpike(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC)
	weekendDates := []int{5, 6}
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	for i := 0; i < 30; i++ {
		dayOffset := weekendDates[i%2]
		date := baseDate.AddDate(0, 0, (i/2)*7+dayOffset)
		createTestTransaction(suite, date, "expense", 100.0, &foodCat)
	}

	weekdayOffsets := []int{0, 1, 2, 3, 4, 7, 8, 9, 10, 11}
	for _, offset := range weekdayOffsets {
		date := baseDate.AddDate(0, 0, offset)
		createTestTransaction(suite, date, "expense", 50.0, &foodCat)
	}

	patterns, err := pattern_engine.GetUserPatterns(testProfileID, nil, nil)
	require.NoError(t, err)

	foundWeekendSpike := false
	for _, p := range patterns {
		if p.Name == "Weekend Spending Spike" {
			foundWeekendSpike = true
			assert.Equal(t, "weekend_spike", p.Type)
			assert.Greater(t, p.FinalScore, 0.0)
			break
		}
	}
	assert.True(t, foundWeekendSpike, "Expected Weekend Spending Spike pattern to be detected")

	for _, p := range patterns {
		assert.NotEmpty(t, p.Type, "Pattern Type should not be empty: %s", p.Name)
	}

	foundTopCategory := false
	for _, p := range patterns {
		if p.Name == "Top Spending Category" {
			foundTopCategory = true
			assert.Equal(t, "top_category", p.Type)
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

	patterns, err := pattern_engine.GetUserPatterns(testProfileID, nil, nil)
	require.NoError(t, err)
	require.GreaterOrEqual(t, len(patterns), 2, "Expected at least 2 patterns")

	for i := 1; i < len(patterns); i++ {
		assert.GreaterOrEqual(t, patterns[i-1].FinalScore, patterns[i].FinalScore,
			"Patterns should be sorted by FinalScore descending")
	}
}

func TestPatternEngineNoTransactions(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	patterns, err := pattern_engine.GetUserPatterns(testProfileID, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, patterns, "Should return empty patterns when no transactions exist")
}

func TestPatternEngineInsufficientTransactions(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC)
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	for i := 0; i < 5; i++ {
		createTestTransaction(suite, baseDate.AddDate(0, 0, i), "expense", 50.0, &foodCat)
	}

	patterns, err := pattern_engine.GetUserPatterns(testProfileID, nil, nil)
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

func TestPatternIconEngineKeywordMatch(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	profileID := uint(1)

	iconLookup := models.IconLookup{Keyword: "spending", Icon: "💸", Color: "#EF4444"}
	require.NoError(t, suite.DB.Create(&iconLookup).Error)

	pattern := models.Pattern{
		Name:        "High Spending",
		Type:        "high_concentration",
		Description: "You spend a lot on food.",
		FinalScore:  7.5,
		ProfileID:   &profileID,
	}
	require.NoError(t, suite.DB.Create(&pattern).Error)

	engine.ResolvePatternIcon(pattern.ID)

	var updated models.Pattern
	require.NoError(t, suite.DB.First(&updated, pattern.ID).Error)

	assert.NotEmpty(t, updated.Icon, "Icon should be resolved (from keyword match or type default)")
	assert.NotEmpty(t, updated.Color, "Color should be resolved (from keyword match or type default)")
}

func TestPatternIconEngineDefaultFallback(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	profileID := uint(1)

	pattern := models.Pattern{
		Name:        "Weekend Spending Spike",
		Type:        "weekend_spike",
		Description: "You spend more on weekends.",
		FinalScore:  5.0,
		ProfileID:   &profileID,
		Icon:        "-",
		Color:       "-",
	}
	require.NoError(t, suite.DB.Create(&pattern).Error)

	engine.ResolvePatternIcon(pattern.ID)

	var updated models.Pattern
	require.NoError(t, suite.DB.First(&updated, pattern.ID).Error)

	assert.Equal(t, "📅", updated.Icon, "Icon should fall back to type default")
	assert.Equal(t, "#F59E0B", updated.Color, "Color should fall back to type default")
}

func TestPatternIconEngineCategoryMatch(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	profileID := uint(1)

	cat := models.Category{Name: "Food", Icon: "🍔", Color: "#FF6B6B"}
	require.NoError(t, suite.DB.Create(&cat).Error)

	metadataJSON, err := json.Marshal(map[string]interface{}{"category": "Food"})
	require.NoError(t, err)

	pattern := models.Pattern{
		Name:        "Top Spending Category",
		Type:        "top_category",
		Description: "Your top spending category is Food.",
		FinalScore:  6.0,
		ProfileID:   &profileID,
		Metadata:    metadataJSON,
	}
	require.NoError(t, suite.DB.Create(&pattern).Error)

	engine.ResolvePatternIcon(pattern.ID)

	var updated models.Pattern
	require.NoError(t, suite.DB.First(&updated, pattern.ID).Error)

	assert.NotEmpty(t, updated.Icon, "Icon should be resolved (from category or type default)")
	assert.NotEmpty(t, updated.Color, "Color should be resolved (from category or type default)")
}

func TestPatternEngineWithDateRange(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, time.UTC)
	foodCat := models.Category{Model: gorm.Model{ID: 1}}

	// Create transactions inside the range (Jan 10-20)
	for i := 0; i < 20; i++ {
		date := baseDate.AddDate(0, 0, 10+i)
		createTestTransaction(suite, date, "expense", 100.0, &foodCat)
	}

	// Create transactions outside the range (Feb 1-10)
	for i := 0; i < 20; i++ {
		date := baseDate.AddDate(0, 0, 26+i)
		createTestTransaction(suite, date, "expense", 50.0, &foodCat)
	}

	start := baseDate.AddDate(0, 0, 9)
	end := baseDate.AddDate(0, 0, 21)

	patterns, err := pattern_engine.GetUserPatterns(testProfileID, &start, &end)
	require.NoError(t, err)
	require.NotEmpty(t, patterns, "Expected patterns within date range")

	// Verify that the top category description references the correct period context
	foundTopCategory := false
	for _, p := range patterns {
		if p.Name == "Top Spending Category" {
			foundTopCategory = true
			assert.Contains(t, p.Description, "Jan 16, 2025", "Description should contain period start")
			assert.Contains(t, p.Description, "Jan 27, 2025", "Description should contain period end")
			break
		}
	}
	assert.True(t, foundTopCategory, "Expected Top Spending Category pattern")

	// All-time should include all transactions and produce different results
	allTimePatterns, err := pattern_engine.GetUserPatterns(testProfileID, nil, nil)
	require.NoError(t, err)
	require.NotEmpty(t, allTimePatterns, "Expected patterns for all time")

	// All-time should have more transactions considered
	var allTimeTop *models.Pattern
	for _, p := range allTimePatterns {
		if p.Name == "Top Spending Category" {
			allTimeTop = &p
			break
		}
	}
	require.NotNil(t, allTimeTop, "Expected Top Spending Category for all time")
	assert.Contains(t, allTimeTop.Description, "Jan 16, 2025", "All-time should start from earliest transaction")
	assert.Contains(t, allTimeTop.Description, "Feb 20, 2025", "All-time should end at latest transaction")
}
