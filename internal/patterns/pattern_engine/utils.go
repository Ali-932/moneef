package pattern_engine

import (
	"fmt"
	"moneef/internal/models"
	"moneef/pkg/types"
	"strings"
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
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

func GetCurrencyCode(profileID uint, db *gorm.DB) (string, error) {
	var currencyCode string
	err := db.Model(&models.UserSettings{}).
		Select("user_settings.currency_code").
		Joins("JOIN profiles ON profiles.user_id = user_settings.user_id").
		Where("profiles.id = ?", profileID).
		Scan(&currencyCode).Error
	if err != nil {
		return "", err
	}
	return currencyCode, nil
}

func ConvertAmount(amount float64, fromCurrency string, toCurrency string, db *gorm.DB) float64 {
	if fromCurrency == toCurrency {
		return amount
	}
	var rate models.CurrencyExchangeRate
	err := db.Where("currency_code1 = ? AND currency_code2 = ?", fromCurrency, toCurrency).First(&rate).Error
	if err != nil {
		return amount
	}
	return amount * rate.Rate
}

func ConvertMoney(amount types.Money, fromCurrency string, toCurrency string, db *gorm.DB) types.Money {
	converted := ConvertAmount(amount.Float64(), fromCurrency, toCurrency, db)
	return types.Money(decimal.NewFromFloat(converted))
}

func FormatCurrencyAmount(amount float64, currencyCode string) string {
	return fmt.Sprintf("%s %s", currencyCode, humanizeFloat(amount))
}

func humanizeFloat(amount float64) string {
	s := fmt.Sprintf("%.2f", amount)
	parts := strings.Split(s, ".")
	intPart := parts[0]
	if intPart[0] == '-' {
		intPart = intPart[1:]
	}
	var result []byte
	for i, j := len(intPart)-1, 0; i >= 0; i, j = i-1, j+1 {
		if j > 0 && j%3 == 0 {
			result = append([]byte{','}, result...)
		}
		result = append([]byte{intPart[i]}, result...)
	}
	if amount < 0 {
		result = append([]byte{'-'}, result...)
	}
	if len(parts) == 2 {
		return string(result) + "." + parts[1]
	}
	return string(result)
}

func formatPeriod(stats *TransactionStats) string {
	if stats == nil || stats.Count == 0 {
		return ""
	}
	return fmt.Sprintf(" across %d transactions (%s – %s)",
		stats.Count,
		stats.EarliestDate.Format("Jan 2, 2006"),
		stats.LatestDate.Format("Jan 2, 2006"),
	)
}
