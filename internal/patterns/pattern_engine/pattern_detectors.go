package pattern_engine

import (
	"fmt"
	"math"
	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/types"
)

type WeekendSpikeDetector struct{}

func (d *WeekendSpikeDetector) Detect(transactions []models.Transaction, countryCode string) ([]models.Pattern, error) {
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
	totalAvg := (weekendTotal.Add(weekdayTotal)).Float64() / float64(weekdayCount+weekendCount)
	transactionsCount := len(transactions)
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
						"totalAmount":       weekendTotal.Add(weekdayTotal).Float64(),
						"totalAvg":          totalAvg,
						"transactionsCount": transactionsCount,
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
						"totalAmount":       weekendTotal.Add(weekdayTotal).Float64(),
						"totalAvg":          totalAvg,
						"transactionsCount": transactionsCount,
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

func (d *CategoryBasedSpendingDetector) Detect(transactions []models.Transaction, countryCode string) ([]models.Pattern, error) {

}
