package tests

import (
	"bytes"
	"encoding/json"
	"moneef/internal/models"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"moneef/internal/analysis/dto"
	"moneef/pkg/types"
)

type AnalysisTestHelper struct {
	suite  *TestSuite
	server *httptest.Server
}

func NewAnalysisTestHelper(suite *TestSuite) *AnalysisTestHelper {
	return &AnalysisTestHelper{
		suite:  suite,
		server: suite.createTestServer(),
	}
}

func (h *AnalysisTestHelper) createAnalysisRequest(startDate, endDate time.Time) dto.SpendByCategoryChartRequest {
	return dto.SpendByCategoryChartRequest{
		StartDate: startDate,
		EndDate:   endDate,
	}
}

func (h *AnalysisTestHelper) executeAnalysisRequest(req dto.SpendByCategoryChartRequest) *httptest.ResponseRecorder {
	body, _ := json.Marshal(req)
	httpReq := h.suite.createAuthenticatedRequest("POST", "/api/v1/analysis/get_spending_by_category", body)
	httpReq.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.server.Config.Handler.ServeHTTP(rr, httpReq)

	if rr.Code >= 400 {
		h.suite.T.Logf("HTTP Request failed with status %d", rr.Code)
		h.suite.T.Logf("Request body: %s", string(body))
		h.suite.T.Logf("Response body: %s", rr.Body.String())
		h.suite.T.Logf("Response headers: %v", rr.Header())
	}

	return rr
}

// Main test function
func TestAnalysisModule(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	suite.CreateAnalysisTestDataSet()
	helper := NewAnalysisTestHelper(suite)

	t.Run("Handler Integration Tests", func(t *testing.T) {
		testAnalysisHandlerIntegration(t, suite, helper)
	})

	t.Run("End-to-End Integration Tests", func(t *testing.T) {
		testAnalysisEndToEndIntegration(t, suite, helper)
	})
}

func testAnalysisHandlerIntegration(t *testing.T, suite *TestSuite, helper *AnalysisTestHelper) {
	t.Logf("Creating analysis test data set...")
	var transactionCount int64
	suite.DB.Model(&models.Transaction{}).Count(&transactionCount)
	t.Logf("Created %d transactions for testing", transactionCount)
	var recurringCount int64
	suite.DB.Model(&models.RecurrenceTemplate{}).Count(&recurringCount)
	t.Logf("Created %d recurring templates for testing", recurringCount)

	t.Run("Valid Request with Real Data", func(t *testing.T) {
		req := helper.createAnalysisRequest(
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 31, 23, 59, 59, 0, time.UTC),
		)
		rr := helper.executeAnalysisRequest(req)

		if rr.Code != http.StatusOK {
			t.Logf("Expected status 200, got %d", rr.Code)
			t.Logf("Response body: %s", rr.Body.String())
		}
		assert.Equal(t, http.StatusOK, rr.Code)

		var response dto.SpendByCategoryChartResponse
		err := json.Unmarshal(rr.Body.Bytes(), &response)
		require.NoError(t, err)

		assert.Equal(t, "USD", response.Currency)
		assert.NotNil(t, response.AnalysisCharts.Categories)
		assert.NotNil(t, response.AnalysisCharts.SpentPerDay)
		assert.NotNil(t, response.AnalysisCharts.NextRecurringTransactions)
		assert.NotEmpty(t, response.AnalysisCharts.Categories, "Should have category data")
		assert.True(t, len(response.AnalysisCharts.Categories) > 0, "Should have at least one category")
		foundFood := false
		foundTransport := false
		for _, cat := range response.AnalysisCharts.Categories {
			if cat.CategoryName == "Food" {
				foundFood = true
				// Should have Grocery Shopping (85.50) + Restaurant Dinner (67.25) = 152.75
				expectedAmount := MoneyFromFloat(152.75)
				assert.True(t, MoneyEqual(cat.TotalAmount, expectedAmount),
					"Food category should have correct total amount. Expected: %v, Got: %v",
					expectedAmount, cat.TotalAmount)
			}
			if cat.CategoryName == "Transport" {
				foundTransport = true
				// Should have Gas Station (45.00) + Uber Ride (18.50) = 63.50
				expectedAmount := MoneyFromFloat(63.50)
				assert.True(t, MoneyEqual(cat.TotalAmount, expectedAmount),
					"Transport category should have correct total amount. Expected: %v, Got: %v",
					expectedAmount, cat.TotalAmount)
			}
		}
		assert.True(t, foundFood, "Should find Food category in results")
		assert.True(t, foundTransport, "Should find Transport category in results")

		// Verify total calculation (sum of all expenses)
		// Food: 152.75, Transport: 63.50, Utilities: 120.75, Entertainment: 32.00 = 369.00
		expectedTotal := MoneyFromFloat(369.00)
		assert.True(t, MoneyEqual(response.AnalysisCharts.Total, expectedTotal),
			"Total should be correct. Expected: %v, Got: %v",
			expectedTotal, response.AnalysisCharts.Total)

		// Verify recurring transactions
		assert.NotEmpty(t, response.AnalysisCharts.NextRecurringTransactions,
			"Should have recurring transactions")
		assert.GreaterOrEqual(t, len(response.AnalysisCharts.NextRecurringTransactions), 2,
			"Should have at least Netflix and Spotify subscriptions")
	})

	t.Run("Previous Period Comparison", func(t *testing.T) {
		req := helper.createAnalysisRequest(
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 31, 23, 59, 59, 0, time.UTC),
		)
		rr := helper.executeAnalysisRequest(req)

		assert.Equal(t, http.StatusOK, rr.Code)

		var response dto.SpendByCategoryChartResponse
		err := json.Unmarshal(rr.Body.Bytes(), &response)
		require.NoError(t, err)

		// Should have previous period data (December 2024)
		assert.NotNil(t, response.AnalysisCharts.CategoriesLastPeriod)
		assert.NotNil(t, response.AnalysisCharts.SpentPerDayLastPeriod)

		// Verify previous period has shopping and travel from December
		foundShopping := false
		foundTravel := false
		for _, cat := range response.AnalysisCharts.CategoriesLastPeriod {
			if cat.CategoryName == "Shopping" {
				foundShopping = true
				expectedAmount := MoneyFromFloat(250.00)
				assert.True(t, MoneyEqual(cat.TotalAmount, expectedAmount))
			}
			if cat.CategoryName == "Travel" {
				foundTravel = true
				expectedAmount := MoneyFromFloat(450.00)
				assert.True(t, MoneyEqual(cat.TotalAmount, expectedAmount))
			}
		}
		assert.True(t, foundShopping || foundTravel, "Should find Shopping or Travel category in previous period")
	})

	t.Run("Missing ProfileID", func(t *testing.T) {
		req := helper.createAnalysisRequest(
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 31, 23, 59, 59, 0, time.UTC),
		)
		body, _ := json.Marshal(req)
		httpReq := httptest.NewRequest("POST", "/api/v1/analysis/get_spending_by_category", bytes.NewBuffer(body))
		httpReq.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		helper.server.Config.Handler.ServeHTTP(rr, httpReq)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
	})

	t.Run("Invalid Date Range", func(t *testing.T) {
		req := helper.createAnalysisRequest(
			time.Date(2025, 1, 31, 0, 0, 0, 0, time.UTC),   // End date as start
			time.Date(2025, 1, 1, 23, 59, 59, 0, time.UTC), // Start date as end
		)
		rr := helper.executeAnalysisRequest(req)
		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	t.Run("Empty Date Range", func(t *testing.T) {
		// Test with future dates where no transactions exist
		req := helper.createAnalysisRequest(
			time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC),
		)
		rr := helper.executeAnalysisRequest(req)

		assert.Equal(t, http.StatusOK, rr.Code)

		var response dto.SpendByCategoryChartResponse
		err := json.Unmarshal(rr.Body.Bytes(), &response)
		require.NoError(t, err)

		// Should return empty data for future dates
		assert.Empty(t, response.AnalysisCharts.Categories)
		assert.True(t, MoneyEqual(response.AnalysisCharts.Total, types.MoneyZero()))
	})
}

// End-to-End Integration Tests
func testAnalysisEndToEndIntegration(t *testing.T, suite *TestSuite, helper *AnalysisTestHelper) {
	t.Run("Multiple Date Range Analysis", func(t *testing.T) {
		testCases := []struct {
			name      string
			startDate time.Time
			endDate   time.Time
			hasData   bool
		}{
			{
				"January 2025 (with data)",
				time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
				time.Date(2025, 1, 31, 23, 59, 59, 0, time.UTC),
				true,
			},
			{
				"December 2024 (with data)",
				time.Date(2024, 12, 1, 0, 0, 0, 0, time.UTC),
				time.Date(2024, 12, 31, 23, 59, 59, 0, time.UTC),
				true,
			},
			{
				"Future month (no data)",
				time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
				time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC),
				false,
			},
		}

		for _, tc := range testCases {
			t.Run(tc.name, func(t *testing.T) {
				req := helper.createAnalysisRequest(tc.startDate, tc.endDate)
				rr := helper.executeAnalysisRequest(req)
				assert.Equal(t, http.StatusOK, rr.Code)

				var response dto.SpendByCategoryChartResponse
				err := json.Unmarshal(rr.Body.Bytes(), &response)
				require.NoError(t, err)

				if tc.hasData {
					assert.NotEmpty(t, response.AnalysisCharts.Categories,
						"Should have category data for period with transactions")
				} else {
					assert.Empty(t, response.AnalysisCharts.Categories,
						"Should have no category data for period without transactions")
					assert.True(t, MoneyEqual(response.AnalysisCharts.Total, types.MoneyZero()),
						"Total should be zero for period without transactions")
				}
			})
		}
	})

	t.Run("Performance with Real Data", func(t *testing.T) {
		// Test concurrent requests with real data
		const numRequests = 10
		results := make(chan int, numRequests)

		req := helper.createAnalysisRequest(
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 31, 23, 59, 59, 0, time.UTC),
		)

		start := time.Now()
		for i := 0; i < numRequests; i++ {
			go func() {
				rr := helper.executeAnalysisRequest(req)
				results <- rr.Code
			}()
		}

		// Collect results
		for i := 0; i < numRequests; i++ {
			statusCode := <-results
			assert.Equal(t, http.StatusOK, statusCode,
				"Concurrent request %d should succeed", i)
		}

		duration := time.Since(start)
		assert.Less(t, duration, 5*time.Second,
			"All concurrent requests should complete within 5 seconds")
	})
}
