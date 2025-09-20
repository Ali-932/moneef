package pattern_engine

import (
	"fmt"
	"moneef/internal/models"
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
	Detect(transactions []models.Transaction, countryCode string) ([]models.Pattern, error)
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
	for _, detector := range engine.detectors {
		if len(transactions) <= detector.MinTransactions() {
			continue
		}
		patterns, err := detector.Detect(transactions, engine.countryCode)
		if err != nil {
			return nil, fmt.Errorf("error in detector %T: %w", detector, err)
		}
		for _, pattern := range patterns {
			pattern.FinalScore = detector.ScorePattern(pattern)
			allPatterns = append(allPatterns, pattern)
		}
	}
	// TODO sort patterns by score descending
	return allPatterns, nil
}

//func GetUserPatterns(profileId uint) ([]models.Pattern, error) {
//	engine := NewEngine([]PatternDetector{
//		&WeekendSpikeDetector{},
//	},
//		"US")
//}
