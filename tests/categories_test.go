package tests

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/stretchr/testify/assert"
	"moneef/internal/categories"
	"moneef/internal/models"
	"moneef/pkg/middleware"
)

func setupCategoryRouter() *chi.Mux {
	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.AuthMiddleware)
		r.Route("/category", func(r chi.Router) {
			r.Delete("/{id}", categories.DeleteCategoryHandler)
		})
	})
	return r
}

func TestDeleteCategory(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	pid := testProfileID
	cat := models.Category{
		Name:      "CustomCat",
		ProfileID: &pid,
	}
	suite.DB.Create(&cat)

	r := setupCategoryRouter()
	req := suite.createAuthenticatedRequest(http.MethodDelete, fmt.Sprintf("/api/v1/category/%d", cat.ID), nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNoContent, w.Code)

	var check models.Category
	result := suite.DB.Unscoped().First(&check, cat.ID)
	assert.Error(t, result.Error)
}
