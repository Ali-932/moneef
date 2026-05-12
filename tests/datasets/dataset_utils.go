package datasets

import (
	"testing"

	"github.com/stretchr/testify/require"
	"gorm.io/gorm"

	"moneef/internal/models"
	"moneef/pkg/types"
)

// DatasetCreator handles creating test data from dataset definitions
type DatasetCreator struct {
	DB *gorm.DB
	T  *testing.T
}

// NewDatasetCreator creates a new dataset creator instance
func NewDatasetCreator(db *gorm.DB, t *testing.T) *DatasetCreator {
	return &DatasetCreator{DB: db, T: t}
}

// CreateTestTransaction creates a single test transaction with categories
func (dc *DatasetCreator) CreateTestTransaction(params CreateTestTransactionParams) *models.Transaction {
	// Set defaults
	if params.ProfileID == 0 {
		params.ProfileID = 1 // testProfileID
	}
	if params.CurrencyCode == "" {
		params.CurrencyCode = "USD"
	}
	if params.Icon == "" {
		params.Icon = "mdi:cash"
	}
	if params.Color == "" {
		params.Color = "#FF6B6B"
	}

	transaction := &models.Transaction{
		ProfileID:            params.ProfileID,
		Name:                 params.Name,
		Type:                 params.Type,
		Date:                 params.Date,
		CurrencyCode:         params.CurrencyCode,
		Icon:                 params.Icon,
		Color:                params.Color,
		MerchantName:         params.MerchantName,
		Notes:                params.Notes,
		RecurrenceTemplateID: params.RecurrenceTemplateID,
	}

	// Create the transaction
	err := dc.DB.Create(transaction).Error
	if err != nil {
		dc.T.Logf("Failed to create transaction: %v", err)
		dc.T.Logf("Transaction data: %+v", transaction)
	}
	require.NoError(dc.T, err)

	// Create transaction categories
	if len(params.CategoriesTransaction) > 0 {
		var transactionCategories []models.TransactionCategory
		for categoryID, amount := range params.CategoriesTransaction {
			money := types.Money(amount)
			transactionCategories = append(transactionCategories, models.TransactionCategory{
				TransactionID: transaction.ID,
				CategoryID:    categoryID,
				Amount:        &money,
			})
		}
		err := dc.DB.Create(&transactionCategories).Error
		if err != nil {
			dc.T.Logf("Failed to create transaction categories: %v", err)
			dc.T.Logf("Categories data: %+v", transactionCategories)
		}
		require.NoError(dc.T, err)
	}

	return transaction
}

// CreateTestTransactionBatch creates multiple test transactions
func (dc *DatasetCreator) CreateTestTransactionBatch(transactions []CreateTestTransactionParams) []*models.Transaction {
	var results []*models.Transaction
	for _, params := range transactions {
		transaction := dc.CreateTestTransaction(params)
		results = append(results, transaction)
	}
	return results
}

// CreateTestRecurrenceTemplate creates a test recurrence template with categories
func (dc *DatasetCreator) CreateTestRecurrenceTemplate(params CreateTestRecurrenceTemplateParams) *models.RecurrenceTemplate {
	// Set defaults
	if params.ProfileID == 0 {
		params.ProfileID = 1 // testProfileID
	}
	if params.CurrencyCode == "" {
		params.CurrencyCode = "USD"
	}
	if params.Icon == "" {
		params.Icon = "mdi:repeat"
	}
	if params.Color == "" {
		params.Color = "#4ECDC4"
	}

	nextPaymentAmount := types.Money(params.NextPaymentAmount)
	template := &models.RecurrenceTemplate{
		ProfileID:         params.ProfileID,
		Name:              params.Name,
		Type:              params.Type,
		CurrencyCode:      params.CurrencyCode,
		Icon:              params.Icon,
		Color:             params.Color,
		MerchantName:      params.MerchantName,
		Notes:             params.Notes,
		Frequency:         params.Frequency,
		NextDate:          params.NextDate,
		NextPaymentAmount: &nextPaymentAmount,
		HasEndDate:        params.HasEndDate,
		EndDate:           params.EndDate,
		IsActive:          params.IsActive,
		StartDate:         params.StartDate,
	}

	// Set optional money fields
	if params.AmountPaidPreviously != nil {
		amount := types.Money(*params.AmountPaidPreviously)
		template.AmountPaidPreviously = &amount
	}
	if params.AmountLeftToPay != nil {
		amount := types.Money(*params.AmountLeftToPay)
		template.AmountLeftToPay = &amount
	}
	if params.TotalAmountToPay != nil {
		amount := types.Money(*params.TotalAmountToPay)
		template.TotalAmountToPay = &amount
	}

	// Create the template
	err := dc.DB.Create(template).Error
	if err != nil {
		dc.T.Logf("Failed to create recurrence template: %v", err)
		dc.T.Logf("Template data: %+v", template)
	}
	require.NoError(dc.T, err)

	// Create template categories
	if len(params.CategoriesTransaction) > 0 {
		var templateCategories []models.RecurrenceTemplateCategory
		for categoryID, amount := range params.CategoriesTransaction {
			money := types.Money(amount)
			templateCategories = append(templateCategories, models.RecurrenceTemplateCategory{
				RecurrenceTemplateID: template.ID,
				CategoryID:           categoryID,
				Amount:               &money,
			})
		}
		err := dc.DB.Create(&templateCategories).Error
		if err != nil {
			dc.T.Logf("Failed to create template categories: %v", err)
			dc.T.Logf("Template categories data: %+v", templateCategories)
		}
		require.NoError(dc.T, err)
	}

	return template
}

// CreateAnalysisDataset creates the complete analysis test dataset
func (dc *DatasetCreator) CreateAnalysisDataset(dataset *AnalysisDataset) {
	// Create all transactions
	dc.CreateTestTransactionBatch(dataset.CurrentMonthTransactions)
	dc.CreateTestTransactionBatch(dataset.PreviousMonthTransactions)

	// Create recurrence templates
	for _, templateParams := range dataset.RecurrenceTemplates {
		dc.CreateTestRecurrenceTemplate(templateParams)
	}
}
