package pattern_engine

import (
	"fmt"
	"moneef/internal/db"
	"moneef/internal/models"
	"sort"
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
	Detect(transactions []models.Transaction, countryCode string, transactionStats *TransactionStats) ([]models.Pattern, error)
	MinTransactions() int
	ScorePattern(pattern models.Pattern) float64
}

type Engine struct {
	detectors   []PatternDetector
	countryCode string
}

func NewEngine(detectors []PatternDetector, countryCode string) *Engine {
	return &Engine{detectors: detectors, countryCode: countryCode}
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
		patterns, err := detector.Detect(transactions, engine.countryCode, transactionStats)
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

func GetUserPatterns(profileId uint) ([]models.Pattern, error) {
	var transactions []models.Transaction
	err := db.DB.
		Preload("TransactionCategory.Category").
		Where("profile_id = ? AND deleted_at IS NULL", profileId).
		Find(&transactions).Error
	if err != nil {
		return nil, fmt.Errorf("failed to fetch transactions: %w", err)
	}
	// TODO: use actual user country code once the model supports it
	countryCode := "US"
	engine := NewEngine([]PatternDetector{
		&WeekendSpikeDetector{},
		&CategoryBasedSpendingDetector{},
		&PurchaseFrequencyDetector{},
	}, countryCode)

	return engine.Analyze(transactions)
}
