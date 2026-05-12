package pattern_engine

import (
	"fmt"
	"moneef/internal/db"
	"moneef/internal/models"
	"sort"
	"time"
)

const (
	ImpactWeight     = 0.4
	ConfidenceWeight = 0.3
	ActionWeight     = 0.1
	UrgencyWeight    = 0.2
)

type Analyzer interface {
	Analyze(transactions []models.Transaction) ([]models.Pattern, error)
}

type PatternDetector interface {
	Detect(transactions []models.Transaction, currencyCode string, transactionStats *TransactionStats) ([]models.Pattern, error)
	MinTransactions() int
	ScorePattern(pattern models.Pattern) float64
}

type Engine struct {
	detectors    []PatternDetector
	currencyCode string
}

func NewEngine(detectors []PatternDetector, currencyCode string) *Engine {
	return &Engine{detectors: detectors, currencyCode: currencyCode}
}

func (engine *Engine) Analyze(transactions []models.Transaction) ([]models.Pattern, error) {
	var allPatterns []models.Pattern
	transactionStats, err := CalculateTransactionStats(transactions, db.DB)
	if err != nil {
		return nil, fmt.Errorf("error calculating transaction stats: %w", err)
	}

	for _, detector := range engine.detectors {
		if len(transactions) <= detector.MinTransactions() {
			continue
		}
		patterns, err := detector.Detect(transactions, engine.currencyCode, transactionStats)
		if err != nil {
			return nil, fmt.Errorf("error in detector %T: %w", detector, err)
		}
		for _, pattern := range patterns {
			pattern.FinalScore = detector.ScorePattern(pattern)
			allPatterns = append(allPatterns, pattern)
		}
	}
	sort.Slice(allPatterns, func(i, j int) bool {
		return allPatterns[i].FinalScore > allPatterns[j].FinalScore
	})
	return allPatterns, nil
}

func GetUserPatterns(profileId uint, startDate, endDate *time.Time) ([]models.Pattern, error) {
	var transactions []models.Transaction
	query := db.DB.
		Preload("TransactionCategory.Category").
		Where("profile_id = ? AND type = ?", profileId, "expense")
	if startDate != nil && endDate != nil {
		query = query.Where("date >= ? AND date <= ?", *startDate, *endDate)
	}
	err := query.Find(&transactions).Error
	if err != nil {
		return nil, fmt.Errorf("failed to fetch transactions: %w", err)
	}
	currencyCode, err := GetCurrencyCode(profileId, db.DB)
	if err != nil {
		return nil, fmt.Errorf("failed to get currency code: %w", err)
	}

	for i := range transactions {
		if transactions[i].CurrencyCode != currencyCode {
			for j := range transactions[i].TransactionCategory {
				if transactions[i].TransactionCategory[j].Amount != nil {
					converted := ConvertMoney(
						*transactions[i].TransactionCategory[j].Amount,
						transactions[i].CurrencyCode,
						currencyCode,
						db.DB,
					)
					transactions[i].TransactionCategory[j].Amount = &converted
				}
			}
			transactions[i].CurrencyCode = currencyCode
		}
	}

	engine := NewEngine([]PatternDetector{
		&WeekendSpikeDetector{},
		&CategoryBasedSpendingDetector{},
		&PurchaseFrequencyDetector{},
	}, currencyCode)

	return engine.Analyze(transactions)
}
