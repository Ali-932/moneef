package tests

import (
	"encoding/json"
	"moneef/internal/models"
	"moneef/internal/transactions/dto"
	"moneef/internal/transactions/repository"
	"moneef/internal/transactions/service"
	"moneef/pkg/types"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/shopspring/decimal"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

type TransactionTestHelper struct {
	suite  *TestSuite
	server *httptest.Server
}

func NewTransactionTestHelper(suite *TestSuite) *TransactionTestHelper {
	return &TransactionTestHelper{
		suite:  suite,
		server: suite.createTestServer(),
	}
}

func (h *TransactionTestHelper) createTransactionRequest(name string, amount float64, trasnType string, opts ...TransactionOption) dto.TransactionRequest {
	req := dto.TransactionRequest{
		TransactionName: name,
		CurrencyCode:    "USD",
		TransactionType: trasnType,
		Date:            time.Now(),
		TransactionCategories: []dto.TransactionCategoryRequest{
			{CategoryId: 1, Amount: decimal.NewFromFloat(amount)},
		},
	}

	for _, opt := range opts {
		opt(&req)
	}

	return req
}

type TransactionOption func(*dto.TransactionRequest)

type CategoryAmount struct {
	ID     uint
	Amount decimal.Decimal
}

func WithCategories(categories ...CategoryAmount) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.TransactionCategories = make([]dto.TransactionCategoryRequest, len(categories))
		for i, cat := range categories {
			r.TransactionCategories[i] = dto.TransactionCategoryRequest{
				CategoryId: cat.ID,
				Amount:     cat.Amount,
			}
		}
	}
}

func WithRecurrence(frequency string, active bool) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.IsRecurrent = PtrBool(true)
		r.RecurrentFreq = PtrString(frequency)
		r.IsActiveRecurrent = PtrBool(active)
		r.RecurrentHasEndDate = PtrBool(false)
	}
}

func WithRecurrenceEndDate(endDate time.Time, totalAmount, paidPreviously float64) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.RecurrentHasEndDate = PtrBool(true)
		r.RecurrentEndDate = &endDate
		r.RecurrentTotalAmount = PtrDecimal(decimal.NewFromFloat(totalAmount))
		r.RecurrentPaidPreviously = PtrDecimal(decimal.NewFromFloat(paidPreviously))
	}
}

func WithMerchant(name string) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.MerchantName = PtrString(name)
	}
}

func WithNotes(notes string) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.Notes = PtrString(notes)
	}
}

func WithIconAndColor(icon, color string) TransactionOption {
	return func(r *dto.TransactionRequest) {
		r.Icon = icon
		r.Color = color
	}
}

func (h *TransactionTestHelper) executeTransactionRequest(req dto.TransactionRequest) *httptest.ResponseRecorder {
	body, _ := json.Marshal(req)
	httpReq := h.suite.createAuthenticatedRequest("POST", "/api/v1/transaction/create", body)
	httpReq.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	h.server.Config.Handler.ServeHTTP(rr, httpReq)
	return rr
}

func (h *TransactionTestHelper) assertTransactionCreated(rr *httptest.ResponseRecorder) {
	assert.Equal(h.suite.T, http.StatusCreated, rr.Code, "Response body: %s", rr.Body.String())
}

func (h *TransactionTestHelper) getTransactionByName(name string) (*models.Transaction, error) {
	var transaction models.Transaction
	err := h.suite.DB.
		Preload("TransactionCategory").
		Preload("TransactionCategory.Category").
		Preload("RecurrenceTemplate").
		Where("name = ?", name).
		First(&transaction).Error
	return &transaction, err
}

type TransactionAssertion struct {
	t           *testing.T
	transaction *models.Transaction
}

func NewTransactionAssertion(t *testing.T, tx *models.Transaction) *TransactionAssertion {
	return &TransactionAssertion{t: t, transaction: tx}
}

func (a *TransactionAssertion) AssertBasicFields(name string, totalAmount string, txType string) {
	assert.Equal(a.t, name, a.transaction.Name)
	assert.Equal(a.t, txType, a.transaction.Type)
	assert.Equal(a.t, "USD", a.transaction.CurrencyCode)

	calculatedTotal := decimal.Zero
	for _, cat := range a.transaction.TransactionCategory {
		if cat.Amount != nil {
			calculatedTotal = calculatedTotal.Add(decimal.Decimal(*cat.Amount))
		}
	}
	assert.Equal(a.t, totalAmount, "$"+calculatedTotal.String())
}

func (a *TransactionAssertion) AssertCategories(expectedIDs ...uint) {
	require.NotNil(a.t, a.transaction.TransactionCategory)
	assert.Len(a.t, a.transaction.TransactionCategory, len(expectedIDs))

	categoryIDs := make(map[uint]bool)
	for _, cat := range a.transaction.TransactionCategory {
		categoryIDs[cat.CategoryID] = true
	}

	for _, expectedID := range expectedIDs {
		assert.True(a.t, categoryIDs[expectedID], "Expected category ID %d not found", expectedID)
	}
}

func (a *TransactionAssertion) AssertRecurrenceTemplate(assertions func(*models.RecurrenceTemplate)) {
	require.NotNil(a.t, a.transaction.RecurrenceTemplateID, "RecurrenceTemplateID should be set")
	require.NotNil(a.t, a.transaction.RecurrenceTemplate, "RecurrenceTemplate should be loaded")
	assertions(a.transaction.RecurrenceTemplate)
}

func TestTransactionCreation(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	helper := NewTransactionTestHelper(suite)

	t.Run("Integration Tests", func(t *testing.T) {
		testNormalTransaction(t, suite, helper)
		testRecurrentTransaction(t, suite, helper)
		testRecurrentTransactionIncome(t, suite, helper)
		testRecurrentTransactionWithEndDate(t, suite, helper)
	})

	t.Run("Repository Tests", func(t *testing.T) {
		testRepositoryOperations(t, suite)
	})

	t.Run("Service Tests", func(t *testing.T) {
		testServiceLayer(t, suite)
	})

	t.Run("Validation Tests", func(t *testing.T) {
		testValidation(t, suite, helper)
	})

	t.Run("Edge Cases", func(t *testing.T) {
		testEdgeCases(t, suite)
	})
}

func testNormalTransaction(t *testing.T, suite *TestSuite, helper *TransactionTestHelper) {
	req := helper.createTransactionRequest("Normal Transaction", 125.50, "expense")
	rr := helper.executeTransactionRequest(req)
	helper.assertTransactionCreated(rr)

	tx, err := helper.getTransactionByName("Normal Transaction")
	require.NoError(t, err)

	assertion := NewTransactionAssertion(t, tx)
	assertion.AssertBasicFields("Normal Transaction", "$125.5", "expense")
	assertion.AssertCategories(1)

	assert.Equal(t, testProfileID, tx.ProfileID)
}

func testRecurrentTransaction(t *testing.T, suite *TestSuite, helper *TransactionTestHelper) {
	req := helper.createTransactionRequest(
		"Netflix Subscription",
		15.99,
		"expense",
		WithCategories(
			CategoryAmount{ID: 1, Amount: decimal.NewFromFloat(8.00)},
			CategoryAmount{ID: 2, Amount: decimal.NewFromFloat(7.99)},
		),
		WithRecurrence("monthly", true),
		WithMerchant("Netflix"),
		WithNotes("Monthly streaming subscription"),
		WithIconAndColor("mdi:television-classic", "#E50914"),
	)

	rr := helper.executeTransactionRequest(req)
	helper.assertTransactionCreated(rr)

	tx, err := helper.getTransactionByName("Netflix Subscription")
	require.NoError(t, err)

	assertion := NewTransactionAssertion(t, tx)
	assertion.AssertBasicFields("Netflix Subscription", "$15.99", "expense")
	assertion.AssertCategories(1, 2)

	assert.Equal(t, "mdi:television-classic", tx.Icon)
	assert.Equal(t, "#E50914", tx.Color)
	require.NotNil(t, tx.MerchantName)
	assert.Equal(t, "Netflix", *tx.MerchantName)
	require.NotNil(t, tx.Notes)
	assert.Equal(t, "Monthly streaming subscription", *tx.Notes)

	assertion.AssertRecurrenceTemplate(func(rt *models.RecurrenceTemplate) {
		assert.Equal(t, "Netflix Subscription", rt.Name)
		assert.Equal(t, "monthly", rt.Frequency)
		assert.False(t, rt.HasEndDate)
		assert.True(t, rt.IsActive)
		assert.Nil(t, rt.EndDate)
		assert.NotNil(t, rt.StartDate)
		assert.NotNil(t, rt.NextPaymentAmount)
		assert.Equal(t, "$15.99", rt.NextPaymentAmount.String())
	})
}

func testRecurrentTransactionIncome(t *testing.T, suite *TestSuite, helper *TransactionTestHelper) {
	req := helper.createTransactionRequest(
		"Salary",
		200,
		"income",
		WithCategories(
			CategoryAmount{ID: 1, Amount: decimal.NewFromFloat(120.00)},
			CategoryAmount{ID: 2, Amount: decimal.NewFromFloat(80.00)},
		),
		WithRecurrence("monthly", true),
		WithMerchant("MDOC"),
		WithNotes("Monthly salary"),
		WithIconAndColor("working", "#E50914"),
	)

	rr := helper.executeTransactionRequest(req)
	helper.assertTransactionCreated(rr)

	tx, err := helper.getTransactionByName("Salary")
	require.NoError(t, err)

	assertion := NewTransactionAssertion(t, tx)
	assertion.AssertBasicFields("Salary", "$200", "income")
	assertion.AssertCategories(1, 2)

	assert.Equal(t, "working", tx.Icon)
	assert.Equal(t, "#E50914", tx.Color)
	require.NotNil(t, tx.MerchantName)
	assert.Equal(t, "MDOC", *tx.MerchantName)
	require.NotNil(t, tx.Notes)
	assert.Equal(t, "Monthly salary", *tx.Notes)

	assertion.AssertRecurrenceTemplate(func(rt *models.RecurrenceTemplate) {
		assert.Equal(t, "Salary", rt.Name)
		assert.Equal(t, "monthly", rt.Frequency)
		assert.False(t, rt.HasEndDate)
		assert.True(t, rt.IsActive)
		assert.Nil(t, rt.EndDate)
		assert.NotNil(t, rt.StartDate)
		assert.NotNil(t, rt.NextPaymentAmount)
		assert.Equal(t, "$200", rt.NextPaymentAmount.String())
	})
}

func testRecurrentTransactionWithEndDate(t *testing.T, suite *TestSuite, helper *TransactionTestHelper) {
	endDate := time.Now().AddDate(0, 6, 0)

	req := helper.createTransactionRequest(
		"Gym Membership",
		50.00,
		"expense",
		WithCategories(
			CategoryAmount{ID: 3, Amount: decimal.NewFromFloat(50.00)},
		),
		WithRecurrence("monthly", true),
		WithRecurrenceEndDate(endDate, 300.00, 100.00),
		WithMerchant("FitLife Gym"),
		WithNotes("6-month gym membership"),
		WithIconAndColor("mdi:dumbbell", "#FF6B35"),
	)

	rr := helper.executeTransactionRequest(req)
	helper.assertTransactionCreated(rr)

	tx, err := helper.getTransactionByName("Gym Membership")
	require.NoError(t, err)

	assertion := NewTransactionAssertion(t, tx)
	assertion.AssertBasicFields("Gym Membership", "$50", "expense")

	assertion.AssertRecurrenceTemplate(func(rt *models.RecurrenceTemplate) {
		assert.True(t, rt.HasEndDate)
		assert.NotNil(t, rt.EndDate)
		assert.NotNil(t, rt.TotalAmountToPay)
		assert.Equal(t, "$300", rt.TotalAmountToPay.String())
		assert.NotNil(t, rt.AmountPaidPreviously)
		assert.Equal(t, "$100", rt.AmountPaidPreviously.String())
		assert.NotNil(t, rt.AmountLeftToPay)
		assert.Equal(t, "$150", rt.AmountLeftToPay.String())
	})
}

func testRepositoryOperations(t *testing.T, suite *TestSuite) {
	t.Run("Create Transaction", func(t *testing.T) {
		transaction := &models.Transaction{
			ProfileID:    testProfileID,
			Name:         "Repository Test",
			Type:         "expense",
			Date:         time.Now(),
			CurrencyCode: "USD",
			Icon:         "mdi:cart",
			Color:        "#FF0000",
		}

		err := suite.DB.Transaction(func(tx *gorm.DB) error {
			_, err := repository.CreateTransaction(tx, transaction)
			return err
		})

		assert.NoError(t, err)
		assert.NotZero(t, transaction.ID)
	})
}

func testServiceLayer(t *testing.T, suite *TestSuite) {
	t.Run("Create Without Categories", func(t *testing.T) {
		err := suite.DB.Transaction(func(tx *gorm.DB) error {
			params := dto.CreateTransactionParams{
				ProfileID:             testProfileID,
				Name:                  "Service Test",
				Type:                  "expense",
				Date:                  time.Now(),
				CurrencyCode:          "USD",
				Icon:                  "mdi:credit-card",
				Color:                 "#FF5722",
				CategoriesTransaction: map[uint]decimal.Decimal{},
			}
			_, err := service.CreateTransactionWithTx(tx, params)
			return err
		})

		assert.NoError(t, err)

		var count int64
		suite.DB.Model(&models.Transaction{}).Where("name = ?", "Service Test").Count(&count)
		assert.Equal(t, int64(1), count)
	})

}

func testValidation(t *testing.T, suite *TestSuite, helper *TransactionTestHelper) {
	testCases := []struct {
		name           string
		modifyRequest  func(*dto.TransactionRequest)
		expectedStatus int
	}{
		{
			name: "Zero Amount",
			modifyRequest: func(r *dto.TransactionRequest) {
				r.TransactionCategories[0].Amount = decimal.Zero
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Negative Amount",
			modifyRequest: func(r *dto.TransactionRequest) {
				r.TransactionCategories[0].Amount = decimal.NewFromFloat(-10.00)
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Empty Name",
			modifyRequest: func(r *dto.TransactionRequest) {
				r.TransactionName = ""
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Invalid Transaction Type",
			modifyRequest: func(r *dto.TransactionRequest) {
				r.TransactionType = "invalid"
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Empty Categories",
			modifyRequest: func(r *dto.TransactionRequest) {
				r.TransactionCategories = []dto.TransactionCategoryRequest{}
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := helper.createTransactionRequest("Validation Test", 50.00, "expense")
			tc.modifyRequest(&req)

			rr := helper.executeTransactionRequest(req)
			assert.Equal(t, tc.expectedStatus, rr.Code, "Test case: %s", tc.name)
		})
	}

}

func testEdgeCases(t *testing.T, suite *TestSuite) {
	testCases := []struct {
		name   string
		amount float64
		txType string
	}{
		{"Large Amount", 999999.99, "expense"},
		{"Small Amount", 0.01, "expense"},
		{"Income Transaction", 2500.00, "income"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			transaction := &models.Transaction{
				ProfileID:    testProfileID,
				Name:         tc.name,
				Type:         tc.txType,
				Date:         time.Now(),
				CurrencyCode: "USD",
				Icon:         "mdi:cash",
				Color:        "#00FF00",
			}

			err := suite.DB.Transaction(func(tx *gorm.DB) error {
				_, err := repository.CreateTransaction(tx, transaction)
				if err != nil {
					return err
				}

				amount := decimal.NewFromFloat(tc.amount)
				categoryAmount := types.Money(amount)
				transactionCategory := &models.TransactionCategory{
					TransactionID: transaction.ID,
					CategoryID:    1, // Use the first test category
					Amount:        &categoryAmount,
				}

				return repository.CreateTransactionCategoryBulk(tx, []*models.TransactionCategory{transactionCategory})
			})
			assert.NoError(t, err, "Failed to create transaction: %s", tc.name)
		})
	}
}
