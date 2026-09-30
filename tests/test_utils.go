package tests

import (
	"bytes"
	"fmt"
	"moneef/internal/analysis"
	"moneef/internal/iconlookup"
	"moneef/internal/transactions"
	"moneef/tests/datasets"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/shopspring/decimal"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"

	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/middleware"
	"moneef/pkg/types"
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
		r.Use(middleware.ProfileMiddleware)

		r.Route("/transaction", func(r chi.Router) {
			r.Post("/create", transactions.CreateTransactionHandler)
		})
		r.Route("/analysis", func(r chi.Router) {
			r.Post("/get_spending_by_category", analysis.GetAllAnalysisCharts)
		})
	})

	return httptest.NewServer(r)
}

func (suite *TestSuite) createAuthenticatedRequest(method, url string, body []byte) *http.Request {
	req := httptest.NewRequest(method, url, bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Profile-ID", fmt.Sprintf("%d", testProfileID))
	return req
}

func setupTestDB(t *testing.T) (*gorm.DB, func()) {
	dbName := fmt.Sprintf("file:memdb_%d?mode=memory&cache=shared", time.Now().UnixNano())
	testDB, err := gorm.Open(sqlite.Open(dbName), &gorm.Config{})
	require.NoError(t, err, "Failed to connect to test database")

	err = testDB.AutoMigrate(
		&models.User{},
		&models.Profile{},
		&models.UserSettings{},
		&models.Category{},
		&models.Transaction{},
		&models.TransactionCategory{},
		&models.RecurrenceTemplate{},
		&models.RecurrenceTemplateCategory{},
		&models.Currency{},
		&models.CurrencyExchangeRate{},
		&models.Pattern{},
		&models.IconLookup{},
		&models.Account{},
		&models.Transfer{},
	)
	require.NoError(t, err, "Failed to migrate test database")

	testDB.Exec(`
		CREATE VIRTUAL TABLE IF NOT EXISTS icon_lookups_fts
		USING fts5(keyword, icon, color, content=icon_lookups, content_rowid=id)
	`)

	seedTestData(t, testDB)

	if err := iconlookup.LoadCache(testDB); err != nil {
		t.Logf("Failed to load icon lookup cache: %v", err)
	}

	originalDB := db.DB
	db.DB = testDB

	return testDB, func() { db.DB = originalDB }
}

func seedTestData(t *testing.T, testDB *gorm.DB) {
	user := &models.User{
		ID:       testUserID,
		Email:    testEmail,
		Password: "hashedpassword",
	}
	require.NoError(t, testDB.Create(user).Error)

	profile := &models.Profile{
		ID:        testProfileID,
		FirstName: "Test",
		LastName:  "User",
		UserID:    testUserID,
	}
	require.NoError(t, testDB.Create(profile).Error)

	settings := &models.UserSettings{
		UserID:                testUserID,
		CurrencyCode:          "USD",
		Language:              "en",
		IsNotificationEnabled: true,
		IsDarkMode:            false,
	}
	require.NoError(t, testDB.Create(settings).Error)

	categories := []models.Category{
		{ID: 1, Name: "Food", Icon: "mdi:food", Color: "#FF6B6B"},
		{ID: 2, Name: "Transport", Icon: "mdi:car", Color: "#4ECDC4"},
		{ID: 3, Name: "Utilities", Icon: "mdi:flash", Color: "#96CEB4"},
		{ID: 4, Name: "Entertainment", Icon: "mdi:movie", Color: "#45B7D1"},
		{ID: 5, Name: "Shopping", Icon: "mdi:shopping", Color: "#FFEAA7"},
		{ID: 8, Name: "Travel", Icon: "mdi:airplane", Color: "#74B9FF"},
		{ID: 12, Name: "Business", Icon: "mdi:briefcase", Color: "#A29BFE"},
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

func MoneyEqual(a, b types.Money) bool {
	return decimal.Decimal(a).Equal(decimal.Decimal(b))
}

func MoneyFromFloat(value float64) types.Money {
	return types.Money(decimal.NewFromFloat(value))
}

func (suite *TestSuite) CleanupTestData() {
	suite.DB.Where("1 = 1").Delete(&models.RecurrenceTemplateCategory{})
	suite.DB.Where("1 = 1").Delete(&models.TransactionCategory{})
	suite.DB.Where("1 = 1").Delete(&models.Transaction{})
	suite.DB.Where("1 = 1").Delete(&models.RecurrenceTemplate{})
	suite.DB.Where("1 = 1").Delete(&models.CurrencyExchangeRate{})
	suite.DB.Where("1 = 1").Delete(&models.Currency{})
	suite.DB.Where("1 = 1").Delete(&models.Category{})
	suite.DB.Where("1 = 1").Delete(&models.UserSettings{})
	suite.DB.Where("1 = 1").Delete(&models.Profile{})
	suite.DB.Where("1 = 1").Delete(&models.User{})
}

func PtrBool(b bool) *bool                          { return &b }
func PtrString(s string) *string                    { return &s }
func PtrFloat64(f float64) *float64                 { return &f }
func PtrDecimal(d decimal.Decimal) *decimal.Decimal { return &d }
func PtrTime(t time.Time) *time.Time                { return &t }
func PtrUint(u uint) *uint                          { return &u }
func PtrInt64(i int64) *int64                       { return &i }
func PtrMoney(m types.Money) *types.Money           { return &m }

func (suite *TestSuite) CreateAnalysisTestDataSet() {
	dataset := datasets.NewAnalysisDataset()
	creator := datasets.NewDatasetCreator(suite.DB, suite.T)
	creator.CreateAnalysisDataset(dataset)
}
