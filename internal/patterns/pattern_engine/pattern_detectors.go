package pattern_engine

import (
	"fmt"
	"math"
	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/types"
	"sort"
)

type WeekendSpikeDetector struct{}

func (d *WeekendSpikeDetector) Detect(transactions []models.Transaction, countryCode string, transactionStats *TransactionStats) ([]models.Pattern, error) {
	weekendDaysFirst := config.WeekendPatterns[countryCode][0]
	weekendDaysSecond := config.WeekendPatterns[countryCode][1]
	var (
		weekendTotal types.Money
		weekdayTotal types.Money
		weekendCount int
		weekdayCount int
	)
	for _, tx := range transactions {
		day := tx.Date.Weekday()
		txTotal, err := tx.GetTotal(db.DB)
		if err != nil {
			return nil, fmt.Errorf("error getting transaction total: %w", err)
		}
		if day == weekendDaysFirst || day == weekendDaysSecond {
			weekendTotal = weekendTotal.Add(*txTotal)
			weekendCount++
		} else {
			weekdayTotal = weekdayTotal.Add(*txTotal)
			weekdayCount++
		}
	}
	weekendAvg := weekendTotal.Float64() / float64(weekendCount)
	weekdayAvg := weekdayTotal.Float64() / float64(weekdayCount)
	threshold := 0.3
	if weekendAvg > weekdayAvg {
		percentDiff := (weekendAvg - weekdayAvg) / weekdayAvg
		if percentDiff > threshold {
			return []models.Pattern{
				{
					Name: "Weekend Spending Spike",
					Description: fmt.Sprintf(
						"Your average weekend spending ($%.2f) is %.1f%% higher than your weekday spending ($%.2f). "+
							"Consider reviewing your weekend expenses.",
						weekendAvg,
						percentDiff*100,
						weekdayAvg,
					),
					Metadata: map[string]interface{}{
						"weekendAvg":        weekendAvg,
						"weekdayAvg":        weekdayAvg,
						"percentDiff":       percentDiff,
						"totalAmount":       transactionStats.TotalAmount,
						"totalAvg":          transactionStats.AveragePerTransaction,
						"transactionsCount": transactionStats.Count,
					},
				},
			}, nil
		}
	} else if weekdayAvg > weekendAvg {
		percentDiff := (weekdayAvg - weekendAvg) / weekendAvg
		if percentDiff > threshold {
			return []models.Pattern{
				{
					Name: "Weekday Spending Spike",
					Description: fmt.Sprintf(
						"Your average weekday spending ($%.2f) is %.1f%% higher than your weekend spending ($%.2f). "+
							"Consider reviewing your weekday expenses.",
						weekdayAvg,
						percentDiff*100,
						weekendAvg,
					),

					Metadata: map[string]interface{}{
						"weekendAvg":        weekendAvg,
						"weekdayAvg":        weekdayAvg,
						"percentDiff":       percentDiff,
						"totalAmount":       transactionStats.TotalAmount,
						"totalAvg":          transactionStats.AveragePerTransaction,
						"transactionsCount": transactionStats.Count,
					},
				},
			}, nil
		}
	}

	return []models.Pattern{}, nil
}
func (d *WeekendSpikeDetector) MinTransactions() int {
	return 30
}
func (d *WeekendSpikeDetector) ScorePattern(pattern *models.Pattern) float64 {
	extractor, err := NewMetadataExtractor(pattern.Metadata)
	if err != nil {
		return 0
	}

	totalAvg := extractor.GetFloat64("totalAvg")
	weekendAvg := extractor.GetFloat64("weekendAvg")
	weekdayAvg := extractor.GetFloat64("weekdayAvg")
	transactionsCount := extractor.GetFloat64("transactionsCount")
	if extractor.HasErrors() {
		return 0
	}

	impact := (weekendAvg - weekdayAvg) / totalAvg * 10
	confidence := math.Min(transactionsCount/100, 1.0) * 10
	actionability := 7.0
	urgency := 3.0
	finalScore := (impact * ImpactWeight) + (confidence * ConfidenceWeight) + (actionability * ActionWeight) + (urgency * UrgencyWeight)
	return finalScore
}

type CategoryBasedSpendingDetector struct{}

func (d *CategoryBasedSpendingDetector) Detect(transactions []models.Transaction, countryCode string, transactionStats *TransactionStats) ([]models.Pattern, error) {
	categorySum := make(map[string]types.Money)
	var patterns []models.Pattern
	for _, tx := range transactions {
		for _, tc := range tx.TransactionCategory {
			var catName string
			catName = tc.Category.Name
			if tc.Amount != nil {
				if sum, exists := categorySum[catName]; exists {
					categorySum[catName] = sum.Add(*tc.Amount)
				} else {
					categorySum[catName] = *tc.Amount
				}
			}
		}
	}
	var first, second struct {
		Name   string
		Amount types.Money
	}
	for cat, amount := range categorySum {
		if first.Name == "" || amount.GreaterThan(first.Amount) {
			second = first
			first.Name = cat
			first.Amount = amount
		} else if second.Name == "" || amount.GreaterThan(second.Amount) {
			second.Name = cat
			second.Amount = amount
		}
	}
	patterns = append(patterns, models.Pattern{
		Name:        "Top Spending Category",
		Description: fmt.Sprintf("Your top spending category is '%s' with a total of $%.2f spent.", first.Name, first.Amount.Float64()),
		Metadata: map[string]interface{}{
			"percentage": (first.Amount.Float64() / transactionStats.TotalAmount.Float64()) * 100,
		},
	})
	if first.Amount.Float64() >= 0.3*transactionStats.TotalAmount.Float64() {
		patterns = append(patterns, models.Pattern{
			Name:        "High Spending Concentration",
			Description: fmt.Sprintf("A significant portion (%.1f%%) of your total spending is concentrated in the '%s' category.", (first.Amount.Float64()/transactionStats.TotalAmount.Float64())*100, first.Name),
			Metadata: map[string]interface{}{
				"percentage": (first.Amount.Float64() / transactionStats.TotalAmount.Float64()) * 100,
			},
		})
	}
	if first.Amount.Add(second.Amount).Float64() >= 0.8*transactionStats.TotalAmount.Float64() {
		patterns = append(patterns, models.Pattern{
			Name:        "Very High Spending Concentration",
			Description: fmt.Sprintf("An overwhelming majority (%.1f%%) of your total spending is concentrated in just two categories: '%s' and '%s'.", ((first.Amount.Add(second.Amount)).Float64()/transactionStats.TotalAmount.Float64())*100, first.Name, second.Name),
			Metadata: map[string]interface{}{
				"percentage": ((first.Amount.Add(second.Amount)).Float64() / transactionStats.TotalAmount.Float64()) * 100,
			},
		})
	}
	return patterns, nil
}

func (d *CategoryBasedSpendingDetector) MinTransactions() int {
	return 10
}

func (d *CategoryBasedSpendingDetector) ScorePattern(pattern *models.Pattern) float64 {
	extractor, err := NewMetadataExtractor(pattern.Metadata)
	if err != nil {
		return 0
	}
	percentage := extractor.GetFloat64("percentage")
	if extractor.HasErrors() {
		return 0
	}
	impact := (percentage - 30) / 70 * 10
	confidence := 9.0
	actionability := 6.0
	urgency := 2.0
	finalScore := (impact * ImpactWeight) + (confidence * ConfidenceWeight) + (actionability * ActionWeight) + (urgency * UrgencyWeight)
	return finalScore
}

type PurchaseFrequencyDetector struct{}

func (d *PurchaseFrequencyDetector) Detect(transactions []models.Transaction, countryCode string, transactionStats *TransactionStats) ([]models.Pattern, error) {
	// Group transactions by category with dates
	// Example: If a $50 Walmart transaction has categories [Groceries: $30, Household: $20],
	// it will appear in both categoryTransactions["Groceries"] and categoryTransactions["Household"]
	categoryTransactions := make(map[string][]models.Transaction)
	categoryAmounts := make(map[string][]types.Money)

	for _, tx := range transactions {
		for _, tc := range tx.TransactionCategory {
			catName := tc.Category.Name
			// Store the full transaction for date analysis
			categoryTransactions[catName] = append(categoryTransactions[catName], tx)
			if tc.Amount != nil {
				// Store the specific amount allocated to this category
				// Example: For the Walmart transaction above,
				// categoryAmounts["Groceries"] gets $30, categoryAmounts["Household"] gets $20
				categoryAmounts[catName] = append(categoryAmounts[catName], *tc.Amount)
			}
		}
	}

	var patterns []models.Pattern

	// Analyze each category
	for catName, catTxs := range categoryTransactions {
		if len(catTxs) == 0 {
			continue
		}

		// Sort transactions by date
		sortedTxs := make([]models.Transaction, len(catTxs))
		copy(sortedTxs, catTxs)
		// Example: [Jan 15, Jan 3, Jan 20, Jan 1] becomes [Jan 1, Jan 3, Jan 15, Jan 20]
		sort.Slice(sortedTxs, func(i, j int) bool {
			return sortedTxs[i].Date.Before(sortedTxs[j].Date)
		})

		// Calculate intervals between purchases (in days)
		// Example: For dates [Jan 1, Jan 3, Jan 7, Jan 8, Jan 15]
		// intervals = [2 days, 4 days, 1 day, 7 days]
		// Note: 5 transactions produce 4 intervals
		var intervals []float64
		for i := 1; i < len(sortedTxs); i++ {
			// Example: Jan 3 - Jan 1 = 48 hours / 24 = 2 days
			interval := sortedTxs[i].Date.Sub(sortedTxs[i-1].Date).Hours() / 24
			intervals = append(intervals, interval)
		}

		// Calculate metrics
		txCount := len(catTxs)
		var totalAmount types.Money
		var avgAmount float64

		if amounts, exists := categoryAmounts[catName]; exists && len(amounts) > 0 {
			// Example: Coffee category has amounts [$4.50, $5.00, $4.75, $4.50, $5.25]
			// totalAmount = $24.00
			for _, amt := range amounts {
				totalAmount = totalAmount.Add(amt)
			}
			// avgAmount = $24.00 / 5 = $4.80 per transaction
			avgAmount = totalAmount.Float64() / float64(len(amounts))
		}

		var purchasesPerWeek float64
		var medianInterval float64

		if len(sortedTxs) > 1 {
			// Calculate date range in days
			// Example: First tx on Jan 1, Last tx on Jan 31
			// dateRange = 30 days
			dateRange := sortedTxs[len(sortedTxs)-1].Date.Sub(sortedTxs[0].Date).Hours() / 24

			if dateRange > 0 {
				// Example: 15 transactions over 30 days
				// weeks = 30 / 7 = 4.29 weeks
				// purchasesPerWeek = 15 / 4.29 = 3.5 purchases per week
				purchasesPerWeek = float64(txCount) / (dateRange / 7)
			}

			if len(intervals) > 0 {
				// Create a copy to preserve original interval order
				// We need the original order for other potential uses
				sortedIntervals := make([]float64, len(intervals))
				copy(sortedIntervals, intervals)

				// Example: intervals = [2, 1, 7, 3, 1] days
				// After sorting: [1, 1, 2, 3, 7]
				sort.Float64s(sortedIntervals)

				// Calculate median (middle value)
				mid := len(sortedIntervals) / 2

				if len(sortedIntervals)%2 == 0 {
					// Even number of intervals
					// Example: [1, 2, 3, 5] - 4 intervals
					// mid = 2
					// median = (sortedIntervals[1] + sortedIntervals[2]) / 2
					// median = (2 + 3) / 2 = 2.5 days
					medianInterval = (sortedIntervals[mid-1] + sortedIntervals[mid]) / 2
				} else {
					// Odd number of intervals
					// Example: [1, 1, 2, 3, 7] - 5 intervals
					// mid = 2
					// median = sortedIntervals[2] = 2 days
					medianInterval = sortedIntervals[mid]
				}
			}
		}

		// Pattern 1: Daily Habits
		// Example: Coffee purchases
		// txCount = 20, purchasesPerWeek = 5, medianInterval = 1.5 days
		// Qualifies because: txCount >= 5 AND purchasesPerWeek >= 4
		if txCount >= 5 && (purchasesPerWeek >= 4 || medianInterval <= 2) {
			patterns = append(patterns, models.Pattern{
				Name: "Daily Habit",
				Description: fmt.Sprintf(
					"'%s' appears to be a daily habit with %d purchases (%.1f per week) and a median interval of %.1f days between purchases.",
					catName, txCount, purchasesPerWeek, medianInterval,
				),
				Metadata: map[string]interface{}{
					"category":         catName,
					"transactionCount": txCount,
					"purchasesPerWeek": purchasesPerWeek,
					"medianInterval":   medianInterval,
					"totalAmount":      totalAmount.Float64(),
					"averageAmount":    avgAmount,
					"patternType":      "daily_habit",
				},
			})
		}

		// Pattern 2: Weekly Repeats
		// Example: Grocery shopping
		// txCount = 8, medianInterval = 3.5 days
		// Qualifies because: txCount >= 4 AND medianInterval between 3-5 days
		if txCount >= 4 && medianInterval >= 3 && medianInterval <= 5 {
			patterns = append(patterns, models.Pattern{
				Name: "Weekly Repeat",
				Description: fmt.Sprintf(
					"'%s' shows a weekly pattern with %d purchases and a median interval of %.1f days between purchases.",
					catName, txCount, medianInterval,
				),
				Metadata: map[string]interface{}{
					"category":         catName,
					"transactionCount": txCount,
					"medianInterval":   medianInterval,
					"totalAmount":      totalAmount.Float64(),
					"averageAmount":    avgAmount,
					"patternType":      "weekly_repeat",
				},
			})
		}

		// Pattern 3: Infrequent Splurges
		// Example: Electronics purchases
		// txCount = 3, avgAmount = $150, totalAmount = $450
		// Qualifies because: txCount <= 6 AND avgAmount >= $60 AND totalAmount >= $100
		if txCount <= 6 && avgAmount >= 60 && totalAmount.Float64() >= 100 {
			patterns = append(patterns, models.Pattern{
				Name: "Infrequent Splurge",
				Description: fmt.Sprintf(
					"'%s' represents infrequent splurges with only %d purchases averaging $%.2f each (total: $%.2f).",
					catName, txCount, avgAmount, totalAmount.Float64(),
				),
				Metadata: map[string]interface{}{
					"category":         catName,
					"transactionCount": txCount,
					"averageAmount":    avgAmount,
					"totalAmount":      totalAmount.Float64(),
					"patternType":      "infrequent_splurge",
				},
			})
		}
	}

	return patterns, nil
}

func (d *PurchaseFrequencyDetector) MinTransactions() int {
	return 50
}

func (d *PurchaseFrequencyDetector) ScorePattern(pattern *models.Pattern) float64 {
	extractor, err := NewMetadataExtractor(pattern.Metadata)
	if err != nil {
		return 0
	}

	patternType := extractor.GetString("patternType")
	totalAmount := extractor.GetFloat64("totalAmount")
	avgAmount := extractor.GetFloat64("averageAmount")
	txCount := extractor.GetFloat64("transactionCount")

	if extractor.HasErrors() {
		return 0
	}

	var impact, confidence, actionability, urgency float64

	switch patternType {
	case "daily_habit":
		impact = math.Min(totalAmount/1000*10, 10)

		confidence = math.Min(txCount/20, 1.0) * 10

		actionability = 9.0
		urgency = 7.0

	case "weekly_repeat":
		impact = math.Min(totalAmount/500*10, 10)

		confidence = math.Min(txCount/10, 1.0) * 10

		actionability = 7.0
		urgency = 5.0

	case "infrequent_splurge":
		impact = math.Min(avgAmount/100*10, 10)

		confidence = 8.0
		actionability = 5.0
		urgency = 3.0

	default:
		return 0
	}

	finalScore := (impact * ImpactWeight) +
		(confidence * ConfidenceWeight) +
		(actionability * ActionWeight) +
		(urgency * UrgencyWeight)

	return finalScore
}
