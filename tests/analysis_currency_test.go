package tests

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/stretchr/testify/assert"
	"moneef/internal/analysis"
	"moneef/internal/models"
	"moneef/pkg/middleware"
)

func TestAnalysisReturnsCurrencyFromSettings(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	suite.DB.Create(&models.Currency{Code: "EUR", Name: "Euro", Symbol: "€"})
	suite.DB.Model(&models.UserSettings{}).Where("user_id = ?", testUserID).Update("currency_code", "EUR")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.ProfileMiddleware)
		r.Post("/analysis/get_spending_by_category", analysis.GetAllAnalysisCharts)
	})

	body, _ := json.Marshal(map[string]string{
		"start_date": time.Now().AddDate(0, -1, 0).Format(time.RFC3339),
		"end_date":   time.Now().Format(time.RFC3339),
	})
	req := suite.createAuthenticatedRequest(http.MethodPost, "/api/v1/analysis/get_spending_by_category", body)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	var resp map[string]interface{}
	assert.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	assert.Equal(t, "EUR", resp["currency"])

	// Assert icon and color are present in CategorySummary (if any categories exist)
	analysisCharts, ok := resp["AnalysisCharts"].(map[string]interface{})
	assert.True(t, ok, "AnalysisCharts should be present")
	if ok {
		categories, _ := analysisCharts["categories"].([]interface{})
		if len(categories) > 0 {
			firstCat, ok := categories[0].(map[string]interface{})
			assert.True(t, ok, "first category should be a map")
			assert.NotNil(t, firstCat["icon"], "icon should be present")
			assert.NotNil(t, firstCat["color"], "color should be present")
		}
	}
}
