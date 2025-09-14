package datasets

import (
	"time"

	"github.com/shopspring/decimal"
)

// AnalysisDataset contains all the test data configuration for analysis tests
type AnalysisDataset struct {
	BaseDate                  time.Time
	CurrentMonthTransactions  []CreateTestTransactionParams
	PreviousMonthTransactions []CreateTestTransactionParams
	RecurrenceTemplates       []CreateTestRecurrenceTemplateParams
}

// CreateTestTransactionParams represents parameters for creating a test transaction
type CreateTestTransactionParams struct {
	Name                  string
	Type                  string // "income" or "expense"
	Date                  time.Time
	ProfileID             uint
	CurrencyCode          string
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal // CategoryID -> Amount
	RecurrenceTemplateID  *uint
}

// CreateTestRecurrenceTemplateParams represents parameters for creating a test recurrence template
type CreateTestRecurrenceTemplateParams struct {
	Name                  string
	Type                  string
	ProfileID             uint
	CurrencyCode          string
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	Frequency             string
	NextDate              time.Time
	NextPaymentAmount     decimal.Decimal
	HasEndDate            bool
	EndDate               *time.Time
	IsActive              bool
	AmountPaidPreviously  *decimal.Decimal
	AmountLeftToPay       *decimal.Decimal
	TotalAmountToPay      *decimal.Decimal
	StartDate             *time.Time
}

// NewAnalysisDataset creates a comprehensive set of test data for analysis testing
func NewAnalysisDataset() *AnalysisDataset {
	baseDate := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)

	return &AnalysisDataset{
		BaseDate: baseDate,
		CurrentMonthTransactions: []CreateTestTransactionParams{
			{
				Name: "Grocery Shopping",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 2), // Jan 3
				CategoriesTransaction: map[uint]decimal.Decimal{
					1: decimal.NewFromFloat(85.50), // Food
				},
			},
			{
				Name: "Gas Station",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 5), // Jan 6
				CategoriesTransaction: map[uint]decimal.Decimal{
					2: decimal.NewFromFloat(45.00), // Transport
				},
			},
			{
				Name: "Electricity Bill",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 10), // Jan 11
				CategoriesTransaction: map[uint]decimal.Decimal{
					3: decimal.NewFromFloat(120.75), // Utilities
				},
			},
			{
				Name: "Movie Theater",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 15), // Jan 16
				CategoriesTransaction: map[uint]decimal.Decimal{
					4: decimal.NewFromFloat(32.00), // Entertainment
				},
			},
			{
				Name: "Salary Payment",
				Type: "income",
				Date: baseDate.AddDate(0, 0, 1), // Jan 2
				CategoriesTransaction: map[uint]decimal.Decimal{
					12: decimal.NewFromFloat(3500.00), // Business
				},
			},
			{
				Name: "Restaurant Dinner",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 20), // Jan 21
				CategoriesTransaction: map[uint]decimal.Decimal{
					1: decimal.NewFromFloat(67.25), // Food
				},
			},
			{
				Name: "Uber Ride",
				Type: "expense",
				Date: baseDate.AddDate(0, 0, 22), // Jan 23
				CategoriesTransaction: map[uint]decimal.Decimal{
					2: decimal.NewFromFloat(18.50), // Transport
				},
			},
		},
		PreviousMonthTransactions: []CreateTestTransactionParams{
			{
				Name: "Christmas Gifts",
				Type: "expense",
				Date: baseDate.AddDate(0, -1, 20), // Dec 21
				CategoriesTransaction: map[uint]decimal.Decimal{
					5: decimal.NewFromFloat(250.00), // Shopping
				},
			},
			{
				Name: "Holiday Travel",
				Type: "expense",
				Date: baseDate.AddDate(0, -1, 22), // Dec 23
				CategoriesTransaction: map[uint]decimal.Decimal{
					8: decimal.NewFromFloat(450.00), // Travel
				},
			},
			{
				Name: "December Salary",
				Type: "income",
				Date: baseDate.AddDate(0, -1, 1), // Dec 2
				CategoriesTransaction: map[uint]decimal.Decimal{
					12: decimal.NewFromFloat(3500.00), // Business
				},
			},
		},
		RecurrenceTemplates: []CreateTestRecurrenceTemplateParams{
			{
				Name:              "Netflix Subscription",
				Type:              "expense",
				Frequency:         "monthly",
				NextDate:          time.Now().AddDate(0, 0, 7),
				NextPaymentAmount: decimal.NewFromFloat(15.99),
				IsActive:          true,
				CategoriesTransaction: map[uint]decimal.Decimal{
					4: decimal.NewFromFloat(15.99), // Entertainment
				},
			},
			{
				Name:              "Spotify Premium",
				Type:              "expense",
				Frequency:         "monthly",
				NextDate:          time.Now().AddDate(0, 0, 14),
				NextPaymentAmount: decimal.NewFromFloat(9.99),
				IsActive:          true,
				CategoriesTransaction: map[uint]decimal.Decimal{
					4: decimal.NewFromFloat(9.99), // Entertainment
				},
			},
		},
	}
}
