package tests

import (
	"bytes"
	"encoding/json"
	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"moneef/internal/db"
	"moneef/internal/handlers"
	"moneef/internal/models"
	"moneef/internal/repository"
	"moneef/internal/services"
	"moneef/pkg/middleware"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/shopspring/decimal"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

const (
	testUserID    = uint(1)
	testProfileID = uint(1)
	testEmail     = "test@example.com"
)

type TestSuite struct {
	DB      *gorm.DB
	Cleanup func()
	T       *testing.T
}

func NewTestSuite(t *testing.T) *TestSuite {
	testDB, cleanup := setupTestDB(t)
	return &TestSuite{
		DB:      testDB,
		Cleanup: cleanup,
		T:       t,
	}
}

func (suite *TestSuite) createTestServer() *httptest.Server {
	r := chi.NewRouter()

	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.CORSMiddleware)
		r.Use(middleware.AuthMiddleware)

		r.Route("/transaction", func(r chi.Router) {
			r.Post("/create", handlers.CreateTransactionHandler)
		})
	})

	return httptest.NewServer(r)
}

func (suite *TestSuite) generateTestJWT(email string) (string, error) {
	return utils.GenerateJWT(email)
}

func (suite *TestSuite) createAuthenticatedRequest(method, url string, body []byte) *http.Request {
	req := httptest.NewRequest(method, url, bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	token, err := suite.generateTestJWT(testEmail)
	if err != nil {
		suite.T.Fatalf("Failed to generate test JWT: %v", err)
	}

	req.Header.Set("Authorization", "Bearer "+token)
	return req
}

func setupTestDB(t *testing.T) (*gorm.DB, func()) {
	testDB, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	require.NoError(t, err, "Failed to connect to test database")

	err = testDB.AutoMigrate(
		&models.User{},
		&models.Profile{},
		&models.UserSettings{},
		&models.Category{},
		&models.Transaction{},
		&models.RecurrenceTemplate{},
		&models.Currency{},
	)
	require.NoError(t, err, "Failed to migrate test database")

	seedTestData(t, testDB)

	originalDB := db.DB
	db.DB = testDB

	return testDB, func() { db.DB = originalDB }
}

func seedTestData(t *testing.T, testDB *gorm.DB) {
	user := &models.User{
		Model:    gorm.Model{ID: testUserID},
		Email:    testEmail,
		Password: "hashedpassword",
	}
	require.NoError(t, testDB.Create(user).Error)

	profile := &models.Profile{
		Model:     gorm.Model{ID: testProfileID},
		FirstName: "Test",
		LastName:  "User",
		UserID:    testUserID,
	}
	require.NoError(t, testDB.Create(profile).Error)

	categories := []models.Category{
		{Model: gorm.Model{ID: 1}, Name: "Food", Icon: "🍔", Color: "#FF6B6B"},
		{Model: gorm.Model{ID: 2}, Name: "Transport", Icon: "🚗", Color: "#4ECDC4"},
		{Model: gorm.Model{ID: 3}, Name: "Entertainment", Icon: "🎬", Color: "#45B7D1"},
	}
	for _, cat := range categories {
		require.NoError(t, testDB.Create(&cat).Error)
	}

	currency := &models.Currency{
		Code:   "USD",
		Name:   "US Dollar",
		Symbol: "$",
	}
	require.NoError(t, testDB.Create(currency).Error)
}

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

func (h *TransactionTestHelper) createTransactionRequest(name string, amount float64, trasnType string, opts ...TransactionOption) handlers.TransactionRequest {
	req := handlers.TransactionRequest{
		TransactionName: name,
		Amount:          decimal.NewFromFloat(amount),
		CurrencyCode:    "USD",
		TransactionType: trasnType,
		Date:            time.Now(),
		Categories:      []handlers.CategoryRequest{{ID: 1}},
	}

	for _, opt := range opts {
		opt(&req)
	}

	return req
}

type TransactionOption func(*handlers.TransactionRequest)

func WithCategories(categoryIDs ...uint) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.Categories = make([]handlers.CategoryRequest, len(categoryIDs))
		for i, id := range categoryIDs {
			r.Categories[i] = handlers.CategoryRequest{ID: id}
		}
	}
}

func WithRecurrence(frequency string, active bool) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.IsRecurrent = ptrBool(true)
		r.RecurrentFreq = ptrString(frequency)
		r.IsActiveRecurrent = ptrBool(active)
		r.RecurrentHasEndDate = ptrBool(false)
	}
}

func WithRecurrenceEndDate(endDate time.Time, totalAmount, paidPreviously float64) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.RecurrentHasEndDate = ptrBool(true)
		r.RecurrentEndDate = &endDate
		r.RecurrentTotalAmount = ptrDecimal(decimal.NewFromFloat(totalAmount))
		r.RecurrentPaidPreviously = ptrDecimal(decimal.NewFromFloat(paidPreviously))
	}
}

func WithMerchant(name string) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.MerchantName = ptrString(name)
	}
}

func WithNotes(notes string) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.Notes = ptrString(notes)
	}
}

func WithIconAndColor(icon, color string) TransactionOption {
	return func(r *handlers.TransactionRequest) {
		r.Icon = icon
		r.Color = color
	}
}

func (h *TransactionTestHelper) executeTransactionRequest(req handlers.TransactionRequest) *httptest.ResponseRecorder {
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
		Preload("Category").
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

func (a *TransactionAssertion) AssertBasicFields(name string, amount string, txType string) {
	assert.Equal(a.t, name, a.transaction.Name)
	assert.NotNil(a.t, a.transaction.Amount)
	assert.Equal(a.t, amount, a.transaction.Amount.String())
	assert.Equal(a.t, txType, a.transaction.Type)
	assert.Equal(a.t, "USD", a.transaction.CurrencyCode)
}

func (a *TransactionAssertion) AssertCategories(expectedIDs ...uint) {
	require.NotNil(a.t, a.transaction.Category)
	assert.Len(a.t, a.transaction.Category, len(expectedIDs))

	categoryIDs := make(map[uint]bool)
	for _, cat := range a.transaction.Category {
		categoryIDs[cat.ID] = true
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
		WithCategories(1, 2),
		WithRecurrence("monthly", true),
		WithMerchant("Netflix"),
		WithNotes("Monthly streaming subscription"),
		WithIconAndColor("📺", "#E50914"),
	)

	rr := helper.executeTransactionRequest(req)
	helper.assertTransactionCreated(rr)

	tx, err := helper.getTransactionByName("Netflix Subscription")
	require.NoError(t, err)

	assertion := NewTransactionAssertion(t, tx)
	assertion.AssertBasicFields("Netflix Subscription", "$15.99", "expense")
	assertion.AssertCategories(1, 2)

	assert.Equal(t, "📺", tx.Icon)
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
		WithCategories(1, 2),
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
		WithCategories(3),
		WithRecurrence("monthly", true),
		WithRecurrenceEndDate(endDate, 300.00, 100.00),
		WithMerchant("FitLife Gym"),
		WithNotes("6-month gym membership"),
		WithIconAndColor("💪", "#FF6B35"),
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
		amount := decimal.NewFromFloat(100.00)
		transaction := &models.Transaction{
			ProfileID:    testProfileID,
			Name:         "Repository Test",
			Type:         "expense",
			Date:         time.Now(),
			Amount:       (*types.Money)(&amount),
			CurrencyCode: "USD",
			Icon:         "🛒",
			Color:        "#FF0000",
		}

		err := suite.DB.Transaction(func(tx *gorm.DB) error {
			return repository.CreateTransaction(tx, transaction)
		})

		assert.NoError(t, err)
		assert.NotZero(t, transaction.ID)
	})
}

func testServiceLayer(t *testing.T, suite *TestSuite) {
	t.Run("Create Without Categories", func(t *testing.T) {
		err := suite.DB.Transaction(func(tx *gorm.DB) error {
			params := services.CreateTransactionParams{
				ProfileID:    testProfileID,
				Name:         "Service Test",
				Type:         "expense",
				Date:         time.Now(),
				Amount:       decimal.NewFromFloat(50.00),
				CurrencyCode: "USD",
				Icon:         "💳",
				Color:        "#FF5722",
				CategoryIDs:  []uint{},
			}
			return services.CreateTransactionWithTx(tx, params)
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
		modifyRequest  func(*handlers.TransactionRequest)
		expectedStatus int
	}{
		{
			name: "Zero Amount",
			modifyRequest: func(r *handlers.TransactionRequest) {
				r.Amount = decimal.Zero
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Negative Amount",
			modifyRequest: func(r *handlers.TransactionRequest) {
				r.Amount = decimal.NewFromFloat(-10.00)
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Empty Name",
			modifyRequest: func(r *handlers.TransactionRequest) {
				r.TransactionName = ""
			},
			expectedStatus: http.StatusBadRequest,
		},
		{
			name: "Invalid Transaction Type",
			modifyRequest: func(r *handlers.TransactionRequest) {
				r.TransactionType = "invalid"
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
			amount := decimal.NewFromFloat(tc.amount)
			transaction := &models.Transaction{
				ProfileID:    testProfileID,
				Name:         tc.name,
				Type:         tc.txType,
				Date:         time.Now(),
				Amount:       (*types.Money)(&amount),
				CurrencyCode: "USD",
				Icon:         "💰",
				Color:        "#00FF00",
			}

			err := repository.CreateTransaction(suite.DB, transaction)
			assert.NoError(t, err, "Failed to create transaction: %s", tc.name)
		})
	}
}

func ptrBool(b bool) *bool                          { return &b }
func ptrString(s string) *string                    { return &s }
func ptrDecimal(d decimal.Decimal) *decimal.Decimal { return &d }
