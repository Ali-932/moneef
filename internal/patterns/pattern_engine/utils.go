package pattern_engine

import (
	"fmt"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/pkg/types"
	"time"
)

type MetadataExtractor struct {
	metadata map[string]interface{}
	errors   []error
}

func NewMetadataExtractor(metadata interface{}) (*MetadataExtractor, error) {
	m, ok := metadata.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid metadata type")
	}
	return &MetadataExtractor{metadata: m, errors: []error{}}, nil
}

func (e *MetadataExtractor) GetFloat64(key string) float64 {
	val, ok := e.metadata[key].(float64)
	if !ok {
		e.errors = append(e.errors, fmt.Errorf("invalid or missing key: %s", key))
		return 0
	}
	return val
}

func (e *MetadataExtractor) GetString(key string) string {
	val, ok := e.metadata[key].(string)
	if !ok {
		e.errors = append(e.errors, fmt.Errorf("invalid or missing key: %s", key))
		return ""
	}
	return val
}

func (e *MetadataExtractor) HasErrors() bool {
	return len(e.errors) > 0
}

func (e *MetadataExtractor) Error() error {
	if len(e.errors) == 0 {
		return nil
	}
	return fmt.Errorf("metadata extraction errors: %v", e.errors)
}

type TransactionStats struct {
	Count                 int
	TotalAmount           types.Money
	AveragePerTransaction float64
	AveragePerDay         float64
	DateRange             int
	EarliestDate          time.Time
	LatestDate            time.Time
	CurrencyCode          string
}

func CalculateTransactionStats(transactions []models.Transaction, db *gorm.DB) (*TransactionStats, error) {
	if len(transactions) == 0 {
		return &TransactionStats{}, nil
	}

	var totalAmount types.Money
	var earliestDate, latestDate time.Time
	currencyCode := transactions[0].CurrencyCode

	earliestDate = transactions[0].Date
	latestDate = transactions[0].Date

	for i, tx := range transactions {
		txTotal, err := tx.GetTotal(db)
		if err != nil {
			return nil, fmt.Errorf("error getting transaction total for transaction %d: %w", i, err)
		}

		totalAmount = totalAmount.Add(*txTotal)

		if tx.Date.Before(earliestDate) {
			earliestDate = tx.Date
		}
		if tx.Date.After(latestDate) {
			latestDate = tx.Date
		}
	}

	count := len(transactions)
	averagePerTransaction := totalAmount.Float64() / float64(count)

	dateRange := int(latestDate.Sub(earliestDate).Hours() / 24)
	if dateRange == 0 {
		dateRange = 1
	}
	averagePerDay := totalAmount.Float64() / float64(dateRange)

	return &TransactionStats{
		Count:                 count,
		TotalAmount:           totalAmount,
		AveragePerTransaction: averagePerTransaction,
		AveragePerDay:         averagePerDay,
		DateRange:             dateRange,
		EarliestDate:          earliestDate,
		LatestDate:            latestDate,
		CurrencyCode:          currencyCode,
	}, nil
}
