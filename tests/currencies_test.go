package tests

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"moneef/internal/currencies"
	"moneef/internal/models"
)

func TestListCurrencies(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	suite.DB.Create(&models.Currency{Code: "EUR", Name: "Euro", Symbol: "€"})

	r := chi.NewRouter()
	r.Get("/api/v1/currencies", currencies.ListCurrenciesHandler)
	server := httptest.NewServer(r)
	defer server.Close()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/currencies", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	var result []models.Currency
	assert.NoError(t, json.Unmarshal(w.Body.Bytes(), &result))
	assert.GreaterOrEqual(t, len(result), 2)
}
