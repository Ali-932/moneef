# Desktop Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Moneef desktop frontend (React + Tailwind + DaisyUI) and fill the four backend gaps it requires.

**Architecture:** The Go backend (chi v5, vertical slice layout under `internal/<feature>/`) exposes a REST API on `localhost:7331`. The React SPA (Vite, HashRouter) lives in `desktop/frontend/src/` and fetches data via `apiFetch` from `services/api.ts`. Four backend endpoints are missing or broken; those are fixed first so the frontend can be built against correct APIs.

**Tech Stack:** Go 1.22, chi v5, GORM + SQLite, React 18, TypeScript, Vite, Tailwind CSS v4, DaisyUI v5, Recharts, React Router DOM v6.

---

## File Map

### Backend (new/modified)
| File | Change |
|------|--------|
| `internal/categories/repository/category_repository.go` | Add `DeleteCategory` |
| `internal/categories/service/category_service.go` | Add `DeleteCategory` |
| `internal/categories/category_handler.go` | Add `DeleteCategoryHandler` |
| `internal/routes/category_routes.go` | Add `DELETE /{id}` |
| `internal/currencies/currency_handler.go` | **New** — `GET /api/v1/currencies` |
| `internal/currencies/currency_service.go` | **New** |
| `internal/currencies/currency_repository.go` | **New** |
| `internal/routes/routes.go` | Mount `/currencies` (no auth) |
| `internal/analysis/service/analysis_service.go` | Accept `currency string` param |
| `internal/analysis/analysis_handler.go` | Read `userID` from ctx, fetch settings, pass currency |
| `internal/transactions/repository/recurrence_repository.go` | Add List, Update, Delete |
| `internal/recurrences/recurrence_handler.go` | **New** — GET list, PUT update, DELETE |
| `internal/recurrences/recurrence_service.go` | **New** |
| `internal/routes/recurrence_routes.go` | **New** — mount `/recurrence` |
| `internal/routes/routes.go` | Mount `/recurrence` |
| `tests/categories_test.go` | Add delete test |
| `tests/currencies_test.go` | **New** |
| `tests/analysis_currency_test.go` | **New / extend** |
| `tests/recurrences_test.go` | **New** |

### Frontend (new/modified)
| File | Change |
|------|--------|
| `desktop/frontend/package.json` | Add deps |
| `desktop/frontend/vite.config.ts` | Add Tailwind plugin |
| `desktop/frontend/src/index.css` | DaisyUI theme tokens (Tailwind v4 is CSS-first — no `tailwind.config.ts` needed) |
| `desktop/frontend/src/types/api.ts` | **New** — all response shapes |
| `desktop/frontend/src/hooks/useTheme.ts` | **New** |
| `desktop/frontend/src/hooks/useDashboard.ts` | **New** |
| `desktop/frontend/src/hooks/useTransactions.ts` | **New** |
| `desktop/frontend/src/hooks/useInsights.ts` | **New** |
| `desktop/frontend/src/hooks/usePatterns.ts` | **New** |
| `desktop/frontend/src/hooks/useProfile.ts` | **New** |
| `desktop/frontend/src/hooks/useCategories.ts` | **New** |
| `desktop/frontend/src/hooks/useRecurrences.ts` | **New** |
| `desktop/frontend/src/hooks/useCurrencies.ts` | **New** |
| `desktop/frontend/src/components/layout/AppShell.tsx` | **New** |
| `desktop/frontend/src/components/layout/Sidebar.tsx` | **New** |
| `desktop/frontend/src/components/layout/TopBar.tsx` | **New** |
| `desktop/frontend/src/components/ui/StatCard.tsx` | **New** |
| `desktop/frontend/src/components/ui/TransactionTable.tsx` | **New** |
| `desktop/frontend/src/components/ui/CategoryBadge.tsx` | **New** |
| `desktop/frontend/src/components/ui/NotifBar.tsx` | **New** |
| `desktop/frontend/src/pages/Home.tsx` | **New** |
| `desktop/frontend/src/pages/Transactions.tsx` | **New** |
| `desktop/frontend/src/pages/Insights.tsx` | **New** |
| `desktop/frontend/src/pages/Profile.tsx` | **New** |
| `desktop/frontend/src/modals/AddTransactionModal.tsx` | **New** |
| `desktop/frontend/src/pages/Onboarding.tsx` | **New** |
| `desktop/frontend/src/App.tsx` | Rewrite with HashRouter |
| `desktop/frontend/src/main.tsx` | Add theme init |

---

## Task 1: DELETE category endpoint

**Files:**
- Modify: `internal/categories/repository/category_repository.go`
- Modify: `internal/categories/service/category_service.go`
- Modify: `internal/categories/category_handler.go`
- Modify: `internal/routes/category_routes.go`
- Create: `tests/categories_test.go`

- [ ] **Step 1: Write failing test**

```go
// tests/categories_test.go
package tests

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"moneef/internal/categories"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/middleware"
	"gorm.io/gorm"
)

func TestDeleteCategory(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	// seed a user-owned category
	pid := testProfileID
	cat := models.Category{ProfileID: &pid, Name: "MyCategory", Icon: "🎯", Color: "#123456"}
	suite.DB.Create(&cat)

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.AuthMiddleware)
		r.Route("/category", func(r chi.Router) {
			r.Delete("/{id}", categories.DeleteCategoryHandler)
		})
	})
	server := httptest.NewServer(r)
	defer server.Close()

	req := suite.createAuthenticatedRequest(http.MethodDelete, "/api/v1/category/"+fmt.Sprintf("%d", cat.ID), nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusNoContent, w.Code)

	// confirm soft-deleted
	var check models.Category
	err := db.DB.Unscoped().First(&check, cat.ID).Error
	assert.NoError(t, err)
	assert.NotNil(t, check.DeletedAt)
}

func TestDeleteDefaultCategoryForbidden(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()

	// category with no profile_id = default, must not be deletable
	req := suite.createAuthenticatedRequest(http.MethodDelete, "/api/v1/category/1", nil)
	// category ID 1 in seed has profile_id = NULL
	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(middleware.AuthMiddleware)
		r.Route("/category", func(r chi.Router) {
			r.Delete("/{id}", categories.DeleteCategoryHandler)
		})
	})
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusNotFound, w.Code)
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd /home/james/GolandProjects/moneef-backend
go test ./tests/... -run TestDeleteCategory -v
```
Expected: compile error — `categories.DeleteCategoryHandler` undefined.

- [ ] **Step 3: Add `DeleteCategory` to repository**

Add to `internal/categories/repository/category_repository.go`:
```go
func DeleteCategory(id uint, profileID uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).Delete(&models.Category{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
```

- [ ] **Step 4: Add `DeleteCategory` to service**

Add to `internal/categories/service/category_service.go`:
```go
func DeleteCategory(id uint, profileID uint) error {
	return repository.DeleteCategory(id, profileID)
}
```

- [ ] **Step 5: Add handler**

Add to `internal/categories/category_handler.go`:
```go
func DeleteCategoryHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	categoryID, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid category ID")
		return
	}
	if err := service.DeleteCategory(uint(categoryID), profileID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Category not found or cannot delete default categories")
			return
		}
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to delete category")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

- [ ] **Step 6: Wire route**

In `internal/routes/category_routes.go` add:
```go
r.Delete("/{id}", categories.DeleteCategoryHandler)
```

- [ ] **Step 7: Run test — expect pass**

```bash
go test ./tests/... -run TestDeleteCategory -v
```

- [ ] **Step 8: Commit**

```bash
git add internal/categories/ internal/routes/category_routes.go tests/categories_test.go
git commit -m "feat(categories): add DELETE /category/{id} endpoint"
```

---

## Task 2: GET /api/v1/currencies endpoint

**Files:**
- Create: `internal/currencies/currency_handler.go`
- Create: `internal/currencies/currency_service.go`
- Create: `internal/currencies/currency_repository.go`
- Modify: `internal/routes/routes.go`
- Create: `tests/currencies_test.go`

- [ ] **Step 1: Write failing test**

```go
// tests/currencies_test.go
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

	// seed a second currency
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
```

- [ ] **Step 2: Run to confirm it fails**

```bash
go test ./tests/... -run TestListCurrencies -v
```
Expected: compile error — package `currencies` undefined.

- [ ] **Step 3: Create repository**

```go
// internal/currencies/currency_repository.go
package currencies

import (
	"moneef/internal/db"
	"moneef/internal/models"
)

func listCurrencies() ([]models.Currency, error) {
	var list []models.Currency
	err := db.DB.Order("code ASC").Find(&list).Error
	return list, err
}
```

- [ ] **Step 4: Create service**

```go
// internal/currencies/currency_service.go
package currencies

import "moneef/internal/models"

func ListCurrencies() ([]models.Currency, error) {
	return listCurrencies()
}
```

- [ ] **Step 5: Create handler**

```go
// internal/currencies/currency_handler.go
package currencies

import (
	"encoding/json"
	"moneef/pkg/utils"
	"net/http"
)

func ListCurrenciesHandler(w http.ResponseWriter, r *http.Request) {
	list, err := ListCurrencies()
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list currencies")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(list)
}
```

- [ ] **Step 6: Add route (no auth)**

In `internal/routes/routes.go`, inside the `/api/v1` block before the auth group, add:
```go
import "moneef/internal/currencies"

// inside r.Route("/api/v1", ...):
r.Get("/currencies", currencies.ListCurrenciesHandler)
```

- [ ] **Step 7: Run test — expect pass**

```bash
go test ./tests/... -run TestListCurrencies -v
```

- [ ] **Step 8: Commit**

```bash
git add internal/currencies/ internal/routes/routes.go tests/currencies_test.go
git commit -m "feat(currencies): add GET /api/v1/currencies endpoint (no auth)"
```

---

## Task 3: Fix analysis currency (read from user settings)

**Files:**
- Modify: `internal/analysis/service/analysis_service.go`
- Modify: `internal/analysis/analysis_handler.go`
- Create: `tests/analysis_currency_test.go`

The handler currently hardcodes `Currency: "USD"` in the response and the service hardcodes `"USD"` in every repository call. The fix reads `userID` from context (`"id"` key), looks up `UserSettings.CurrencyCode`, and passes it through.

- [ ] **Step 1: Write failing test**

```go
// tests/analysis_currency_test.go
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

	// seed a EUR currency so the foreign key constraint is satisfied
	suite.DB.Create(&models.Currency{Code: "EUR", Name: "Euro", Symbol: "€"})
	// update user's currency to EUR using standard GORM model pattern
	suite.DB.Model(&models.UserSettings{}).Where("user_id = ?", testUserID).Update("currency_code", "EUR")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.AuthMiddleware)
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
	// SpendByCategoryChartResponse.Currency has no json tag → serialised as "Currency" (title-case)
	assert.Equal(t, "EUR", resp["Currency"])
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
go test ./tests/... -run TestAnalysisReturnsCurrencyFromSettings -v
```
Expected: FAIL — response returns `"USD"` not `"EUR"`.

- [ ] **Step 3: Update service signature**

Change `GetAllAnalysisChartsService` in `internal/analysis/service/analysis_service.go`:
```go
// Before:
func GetAllAnalysisChartsService(profileId uint, startDate, endDate time.Time) (*dto.AnalysisCharts, error) {

// After:
func GetAllAnalysisChartsService(profileId uint, startDate, endDate time.Time, currency string) (*dto.AnalysisCharts, error) {
```

Replace all five occurrences of `"USD"` inside the function body with `currency`:
```go
// All repository calls become e.g.:
result, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, currency)
```

- [ ] **Step 4: Update handler**

In `internal/analysis/analysis_handler.go`:
```go
import (
	// existing imports...
	userRepo "moneef/internal/users/repository"
)

func GetAllAnalysisCharts(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID, ok := r.Context().Value("id").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.SpendByCategoryChartRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}

	settings, err := userRepo.GetUserSettingsByUserID(userID)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to read user settings")
		return
	}
	currency := settings.CurrencyCode

	res, err := service.GetAllAnalysisChartsService(profileID, req.StartDate, req.EndDate, currency)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Internal Server Error")
		return
	}
	response := dto.SpendByCategoryChartResponse{
		AnalysisCharts: *res,
		StartDate:      req.StartDate,
		EndDate:        req.EndDate,
		Currency:       currency,
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response)
}
```

- [ ] **Step 5: Run test — expect pass**

```bash
go test ./tests/... -run TestAnalysisReturnsCurrencyFromSettings -v
```

- [ ] **Step 6: Run all tests to confirm no regressions**

```bash
go test ./... -v
```

- [ ] **Step 7: Commit**

```bash
git add internal/analysis/ tests/analysis_currency_test.go
git commit -m "fix(analysis): read currency from user settings instead of hardcoding USD"
```

---

## Task 4: Recurring template CRUD (List, Update, Delete)

**Files:**
- Modify: `internal/transactions/repository/recurrence_repository.go`
- Create: `internal/recurrences/recurrence_handler.go`
- Create: `internal/recurrences/recurrence_service.go`
- Create: `internal/routes/recurrence_routes.go`
- Modify: `internal/routes/routes.go`
- Create: `tests/recurrences_test.go`

- [ ] **Step 1: Write failing tests**

```go
// tests/recurrences_test.go
package tests

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/stretchr/testify/assert"
	"moneef/internal/models"
	"moneef/internal/recurrences"
	"moneef/pkg/middleware"
	"moneef/pkg/types"
	"github.com/shopspring/decimal"
)

func setupRecurrenceRouter() *chi.Mux {
	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.AuthMiddleware)
		r.Route("/recurrence", func(r chi.Router) {
			r.Get("/", recurrences.ListRecurrencesHandler)
			r.Put("/{id}", recurrences.UpdateRecurrenceHandler)
			r.Delete("/{id}", recurrences.DeleteRecurrenceHandler)
		})
	})
	return r
}

func seedRecurrence(suite *TestSuite) models.RecurrenceTemplate {
	amount := types.Money(decimal.NewFromFloat(50.00))
	tpl := models.RecurrenceTemplate{
		ProfileID:         testProfileID,
		Name:              "Netflix",
		Type:              "expense",
		CurrencyCode:      "USD",
		Icon:              "📺",
		Color:             "#E50914",
		Frequency:         "monthly",
		NextDate:          time.Now().AddDate(0, 0, 7),
		NextPaymentAmount: &amount,
		IsActive:          true,
	}
	suite.DB.Create(&tpl)
	return tpl
}

func TestListRecurrences(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	seedRecurrence(suite)

	r := setupRecurrenceRouter()
	req := suite.createAuthenticatedRequest(http.MethodGet, "/api/v1/recurrence/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	var result []map[string]interface{}
	assert.NoError(t, json.Unmarshal(w.Body.Bytes(), &result))
	assert.Equal(t, 1, len(result))
}

func TestDeleteRecurrence(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	tpl := seedRecurrence(suite)

	r := setupRecurrenceRouter()
	req := suite.createAuthenticatedRequest(http.MethodDelete, fmt.Sprintf("/api/v1/recurrence/%d", tpl.ID), nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusNoContent, w.Code)
	var check models.RecurrenceTemplate
	suite.DB.Unscoped().First(&check, tpl.ID)
	assert.NotNil(t, check.DeletedAt)
}

func TestUpdateRecurrence(t *testing.T) {
	suite := NewTestSuite(t)
	defer suite.Cleanup()
	tpl := seedRecurrence(suite)

	r := setupRecurrenceRouter()
	body, _ := json.Marshal(map[string]interface{}{"name": "Spotify", "frequency": "monthly"})
	req := suite.createAuthenticatedRequest(http.MethodPut, fmt.Sprintf("/api/v1/recurrence/%d", tpl.ID), body)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	var check models.RecurrenceTemplate
	suite.DB.First(&check, tpl.ID)
	assert.Equal(t, "Spotify", check.Name)
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
go test ./tests/... -run TestListRecurrences -v
```
Expected: compile error — package `recurrences` undefined.

- [ ] **Step 3: Add repo functions**

Add to `internal/transactions/repository/recurrence_repository.go`:
```go
func ListRecurrenceTemplates(profileID uint) ([]models.RecurrenceTemplate, error) {
	var list []models.RecurrenceTemplate
	err := db.DB.
		Preload("TransactionCategory.Category").
		Where("profile_id = ?", profileID).
		Order("next_date ASC").
		Find(&list).Error
	return list, err
}

func UpdateRecurrenceTemplate(profileID uint, id uint, updates map[string]interface{}) error {
	result := db.DB.Model(&models.RecurrenceTemplate{}).
		Where("id = ? AND profile_id = ?", id, profileID).
		Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func DeleteRecurrenceTemplate(profileID uint, id uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).
		Delete(&models.RecurrenceTemplate{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
```

Note: add `"moneef/internal/db"` import if not already present (it is — existing Create functions use it via the `tx *gorm.DB` param, but the new List/Update/Delete use `db.DB` directly; add the import).

- [ ] **Step 4: Create service**

```go
// internal/recurrences/recurrence_service.go
package recurrences

import (
	"moneef/internal/models"
	"moneef/internal/transactions/repository"
)

func ListRecurrences(profileID uint) ([]models.RecurrenceTemplate, error) {
	return repository.ListRecurrenceTemplates(profileID)
}

func UpdateRecurrence(profileID, id uint, updates map[string]interface{}) error {
	return repository.UpdateRecurrenceTemplate(profileID, id, updates)
}

func DeleteRecurrence(profileID, id uint) error {
	return repository.DeleteRecurrenceTemplate(profileID, id)
}
```

- [ ] **Step 5: Create handler**

```go
// internal/recurrences/recurrence_handler.go
package recurrences

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"gorm.io/gorm"
	"moneef/pkg/utils"
)

func ListRecurrencesHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	list, err := ListRecurrences(profileID)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list recurring templates")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(list)
}

func UpdateRecurrenceHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	id, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid ID")
		return
	}
	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid input")
		return
	}
	// whitelist editable fields
	allowed := map[string]bool{"name": true, "frequency": true, "next_date": true, "end_date": true, "has_end_date": true, "is_active": true, "notes": true, "merchant_name": true}
	filtered := make(map[string]interface{})
	for k, v := range updates {
		if allowed[k] {
			filtered[k] = v
		}
	}
	if err := UpdateRecurrence(profileID, uint(id), filtered); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Recurring template not found")
			return
		}
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to update")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "updated"})
}

func DeleteRecurrenceHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	id, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid ID")
		return
	}
	if err := DeleteRecurrence(profileID, uint(id)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Recurring template not found")
			return
		}
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to delete")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

- [ ] **Step 6: Create route file**

```go
// internal/routes/recurrence_routes.go
package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/recurrences"
)

func RecurrenceRoutes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", recurrences.ListRecurrencesHandler)
	r.Put("/{id}", recurrences.UpdateRecurrenceHandler)
	r.Delete("/{id}", recurrences.DeleteRecurrenceHandler)
	return r
}
```

- [ ] **Step 7: Mount in routes.go**

In `internal/routes/routes.go` inside the auth group add:
```go
r.Mount("/recurrence", RecurrenceRoutes())
```

- [ ] **Step 8: Run tests — expect pass**

```bash
go test ./tests/... -run "TestListRecurrences|TestDeleteRecurrence|TestUpdateRecurrence" -v
```

- [ ] **Step 9: Run full test suite**

```bash
go test ./... -v
```

- [ ] **Step 10: Commit**

```bash
git add internal/recurrences/ internal/routes/recurrence_routes.go internal/transactions/repository/recurrence_repository.go internal/routes/routes.go tests/recurrences_test.go
git commit -m "feat(recurrences): add GET list, PUT update, DELETE endpoints for recurring templates"
```

---

## Task 5: Frontend tooling setup

**Files:**
- Modify: `desktop/frontend/package.json`
- Modify: `desktop/frontend/vite.config.ts`
- Create: `desktop/frontend/src/index.css`

Note: Tailwind CSS v4 is entirely CSS-based — there is no `tailwind.config.ts`. All theme customisation goes in `index.css` via `@theme` blocks.

- [ ] **Step 1: Install dependencies**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend
npm install tailwindcss @tailwindcss/vite daisyui recharts react-router-dom
npm install --save-dev @types/react-router-dom
```

- [ ] **Step 2: Update vite.config.ts**

```ts
// desktop/frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
})
```

- [ ] **Step 3: Create index.css with theme**

```css
/* desktop/frontend/src/index.css */
@import "tailwindcss";
@plugin "daisyui";

/* DaisyUI v5 custom themes — override CSS variables per data-theme attribute.
   The @plugin directive registers base DaisyUI classes; themes are defined below.
   Set data-theme="moneef-light" (default) or "moneef-dark" on <html>. */
[data-theme="moneef-light"] {
  --color-primary: #6B5CE7;
  --color-primary-content: #ffffff;
  --color-base-100: #F7F6FB;
  --color-base-200: #FFFFFF;
  --color-base-300: #EBEBEB;
  --color-base-content: #1a1a2e;
}

[data-theme="moneef-dark"] {
  --color-primary: #6B5CE7;
  --color-primary-content: #ffffff;
  --color-base-100: #1E1B3A;
  --color-base-200: #2A2650;
  --color-base-300: #15122E;
  --color-base-content: #e8e6f5;
}
```

- [ ] **Step 4: Import CSS in main.tsx**

In `desktop/frontend/src/main.tsx`:
```tsx
import './index.css'
```

- [ ] **Step 5: Verify dev server starts without errors**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend
npm run dev
```
Expected: no compile errors, Vite reports ready on localhost:5173.

- [ ] **Step 6: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/package.json desktop/frontend/package-lock.json desktop/frontend/vite.config.ts desktop/frontend/src/index.css desktop/frontend/src/main.tsx
git commit -m "feat(frontend): add Tailwind v4 + DaisyUI v5 + Recharts + React Router DOM"
```

---

## Task 6: TypeScript API types

**Files:**
- Create: `desktop/frontend/src/types/api.ts`

- [ ] **Step 1: Create types file**

```ts
// desktop/frontend/src/types/api.ts

export type TransactionType = 'income' | 'expense'
export type Frequency = 'daily' | 'weekly' | 'bi-weekly' | 'monthly' | 'yearly'

export interface Category {
  ID: number
  name: string
  icon: string
  color: string
  type?: string
  profile_id?: number
}

export interface Currency {
  Code: string
  Name: string
  Symbol: string
}

export interface TransactionCategory {
  ID: number
  category_id: number
  amount: string        // decimal string from backend
  Category: Category
}

export interface Transaction {
  ID: number
  name: string
  type: TransactionType
  date: string          // RFC3339
  currency_code: string
  icon: string
  color: string
  merchant_name?: string
  notes?: string
  TransactionCategory: TransactionCategory[]
  recurrence_template_id?: number
}

export interface RecurrenceTemplate {
  ID: number
  name: string
  type: TransactionType
  frequency: Frequency
  next_date: string
  next_payment_amount: string
  amount_paid_previously: string
  amount_left_to_pay?: string
  total_amount_to_pay?: string
  end_date?: string
  has_end_date: boolean
  is_active: boolean
  currency_code: string
  icon: string
  color: string
  merchant_name?: string
  notes?: string
}

// Dashboard
export interface DashboardSummary {
  period_totals: { Income: string; Expense: string }
  top_categories: Array<{ CategoryID: number; CategoryName: string; TotalAmount: string }>
  daily_spend: Array<{ Date: string; Amount: string }>
  recent_transactions: Transaction[]
  upcoming_recurring: RecurrenceTemplate[]
}

// Analysis
export interface CategorySummary {
  category_id: number
  category_name: string
  total_amount: string
  percentage: string
}

export interface AmountPerDay {
  date: string
  amount: string
}

export interface NextRecurringTransaction {
  amount: string
  date: string
  name: string
}

export interface AnalysisCharts {
  categories: CategorySummary[]
  categories_last_period: CategorySummary[]
  spent_per_day: AmountPerDay[]
  spent_per_day_last_period: AmountPerDay[]
  next_recurring_transactions: NextRecurringTransaction[]
  total: string
}

export interface AnalysisResponse {
  AnalysisCharts: AnalysisCharts
  start_date: string
  end_date: string
  currency: string
}

// Patterns
export interface Pattern {
  ID: number
  pattern_type: string
  description: string
  final_score: number
  created_at: string
}

// Profile
export interface Profile {
  ID: number
  first_name: string
  last_name: string
  user_id: number
}

export interface UserSettings {
  ID: number
  user_id: number
  currency_code: string
  language: string
  is_notification_enabled: boolean
  is_dark_mode: boolean
}
```

- [ ] **Step 2: Commit**

```bash
git add desktop/frontend/src/types/
git commit -m "feat(frontend): add TypeScript API types"
```

---

## Task 7: Data fetching hooks

**Files:**
- Create: `desktop/frontend/src/hooks/useTheme.ts`
- Create: `desktop/frontend/src/hooks/useDashboard.ts`
- Create: `desktop/frontend/src/hooks/useTransactions.ts`
- Create: `desktop/frontend/src/hooks/useInsights.ts`
- Create: `desktop/frontend/src/hooks/usePatterns.ts`
- Create: `desktop/frontend/src/hooks/useProfile.ts`
- Create: `desktop/frontend/src/hooks/useCategories.ts`
- Create: `desktop/frontend/src/hooks/useRecurrences.ts`
- Create: `desktop/frontend/src/hooks/useCurrencies.ts`

All hooks follow the same pattern. Write them all in one step.

- [ ] **Step 1: Create useTheme.ts**

```ts
// desktop/frontend/src/hooks/useTheme.ts
import { useEffect, useState } from 'react'

export function useTheme() {
  const [theme, setTheme] = useState<'moneef-light' | 'moneef-dark'>(
    () => (localStorage.getItem('theme') as 'moneef-light' | 'moneef-dark') ?? 'moneef-light'
  )

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('theme', theme)
  }, [theme])

  const toggleTheme = () =>
    setTheme(t => (t === 'moneef-light' ? 'moneef-dark' : 'moneef-light'))

  return { theme, toggleTheme }
}
```

- [ ] **Step 2: Create data hooks**

```ts
// desktop/frontend/src/hooks/useDashboard.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { DashboardSummary } from '../types/api'

export function useDashboard(dateFrom?: string, dateTo?: string) {
  const [data, setData] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    const params = new URLSearchParams()
    if (dateFrom) params.set('date_from', dateFrom)
    if (dateTo) params.set('date_to', dateTo)
    apiFetch(`/api/v1/dashboard/summary?${params}`)
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount, dateFrom, dateTo])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useTransactions.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { Transaction } from '../types/api'

export function useTransactions() {
  const [data, setData] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/transaction/')
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useInsights.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { AnalysisResponse } from '../types/api'

export function useInsights(startDate: string, endDate: string) {
  const [data, setData] = useState<AnalysisResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/analysis/get_spending_by_category', {
      method: 'POST',
      body: JSON.stringify({ start_date: startDate, end_date: endDate }),
    })
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount, startDate, endDate])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/usePatterns.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { Pattern } from '../types/api'

export function usePatterns() {
  const [data, setData] = useState<Pattern[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/analysis/patterns')
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useProfile.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { Profile, UserSettings } from '../types/api'

export function useProfile() {
  const [profile, setProfile] = useState<Profile | null>(null)
  const [settings, setSettings] = useState<UserSettings | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    Promise.all([
      apiFetch('/api/v1/user/profile').then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() }),
      apiFetch('/api/v1/user/settings').then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() }),
    ])
      .then(([p, s]) => { setProfile(p); setSettings(s) })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  return { profile, settings, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useCategories.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { Category } from '../types/api'

export function useCategories() {
  const [data, setData] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/category/')
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useRecurrences.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { RecurrenceTemplate } from '../types/api'

export function useRecurrences() {
  const [data, setData] = useState<RecurrenceTemplate[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    setLoading(true)
    setError(null)
    apiFetch('/api/v1/recurrence/')
      .then(r => { if (!r.ok) throw new Error(r.statusText); return r.json() })
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [retryCount])

  return { data, loading, error, refetch: () => setRetryCount(c => c + 1) }
}
```

```ts
// desktop/frontend/src/hooks/useCurrencies.ts
import { useState, useEffect } from 'react'
import { apiFetch } from '../services/api'
import type { Currency } from '../types/api'

export function useCurrencies() {
  const [data, setData] = useState<Currency[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    apiFetch('/api/v1/currencies')
      .then(r => r.json())
      .then(setData)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  return { data, loading, error }
}
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend
npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/hooks/
git commit -m "feat(frontend): add data fetching hooks"
```

---

## Task 8: AppShell layout (Sidebar + TopBar + routing)

**Files:**
- Create: `desktop/frontend/src/components/layout/Sidebar.tsx`
- Create: `desktop/frontend/src/components/layout/TopBar.tsx`
- Create: `desktop/frontend/src/components/layout/AppShell.tsx`
- Rewrite: `desktop/frontend/src/App.tsx`

- [ ] **Step 1: Create Sidebar**

```tsx
// desktop/frontend/src/components/layout/Sidebar.tsx
import { NavLink } from 'react-router-dom'

const navItems = [
  { to: '/', label: 'Home', icon: '🏠' },
  { to: '/insights', label: 'Insights', icon: '📊' },
  { to: '/transactions', label: 'Transactions', icon: '💳' },
  { to: '/profile', label: 'Profile', icon: '👤' },
]

interface SidebarProps {
  onAddTransaction: () => void
}

export function Sidebar({ onAddTransaction }: SidebarProps) {
  return (
    <aside className="w-[210px] min-h-screen flex flex-col py-4 px-3 gap-1" style={{ background: '#6B5CE7' }}>
      <div className="text-white font-bold text-xs tracking-widest mb-4 px-2">MONEEF</div>
      {navItems.map(item => (
        <NavLink
          key={item.to}
          to={item.to}
          end={item.to === '/'}
          className={({ isActive }) =>
            `flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
              isActive
                ? 'bg-white/[0.18] text-white'
                : 'text-white/70 hover:bg-white/10 hover:text-white'
            }`
          }
        >
          <span className="text-base">{item.icon}</span>
          {item.label}
        </NavLink>
      ))}
      <div className="mt-auto">
        <button
          onClick={onAddTransaction}
          className="w-full bg-white text-[#6B5CE7] font-semibold text-sm py-2 rounded-lg hover:bg-white/90 transition-colors"
        >
          + Add Transaction
        </button>
      </div>
    </aside>
  )
}
```

- [ ] **Step 2: Create TopBar**

```tsx
// desktop/frontend/src/components/layout/TopBar.tsx
interface TopBarProps {
  title: string
  children?: React.ReactNode
}

export function TopBar({ title, children }: TopBarProps) {
  return (
    <header className="h-12 bg-base-200 border-b border-[#EBEBEB] flex items-center justify-between px-6 flex-shrink-0">
      <h1 className="font-bold text-[0.9rem]">{title}</h1>
      <div className="flex items-center gap-3">{children}</div>
    </header>
  )
}
```

- [ ] **Step 3: Create AppShell**

```tsx
// desktop/frontend/src/components/layout/AppShell.tsx
import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { TopBar } from './TopBar'
import { AddTransactionModal } from '../../modals/AddTransactionModal'

const pageTitles: Record<string, string> = {
  '/': 'Home',
  '/transactions': 'Transactions',
  '/insights': 'Insights',
  '/insights/analysis': 'Insights',
  '/insights/patterns': 'Insights',
  '/profile': 'Profile',
}

export function AppShell() {
  const [addOpen, setAddOpen] = useState(false)
  const location = useLocation()
  const title = pageTitles[location.pathname] ?? 'Moneef'

  return (
    <div className="flex h-screen overflow-hidden bg-base-100">
      <Sidebar onAddTransaction={() => setAddOpen(true)} />
      <div className="flex flex-col flex-1 overflow-hidden">
        <TopBar title={title} />
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
      <AddTransactionModal open={addOpen} onClose={() => setAddOpen(false)} />
    </div>
  )
}
```

- [ ] **Step 4: Rewrite App.tsx with HashRouter**

```tsx
// desktop/frontend/src/App.tsx
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import { setApiBase } from './services/api'
import { AppShell } from './components/layout/AppShell'
import { Home } from './pages/Home'
import { Transactions } from './pages/Transactions'
import { Insights } from './pages/Insights'
import { Profile } from './pages/Profile'
import { Onboarding } from './pages/Onboarding'

setApiBase('http://127.0.0.1:7331')

function RequireAuth({ children }: { children: React.ReactNode }) {
  const jwt = localStorage.getItem('jwt')
  if (!jwt) return <Navigate to="/onboarding" replace />
  return <>{children}</>
}

function App() {
  return (
    <HashRouter>
      <Routes>
        <Route path="/onboarding" element={<Onboarding />} />
        <Route
          path="/"
          element={
            <RequireAuth>
              <AppShell />
            </RequireAuth>
          }
        >
          <Route index element={<Home />} />
          <Route path="transactions" element={<Transactions />} />
          <Route path="insights" element={<Insights tab="overview" />} />
          <Route path="insights/analysis" element={<Insights tab="analysis" />} />
          <Route path="insights/patterns" element={<Insights tab="patterns" />} />
          <Route path="profile" element={<Profile />} />
        </Route>
      </Routes>
    </HashRouter>
  )
}

export default App
```

- [ ] **Step 5: Create stub page files so App.tsx compiles**

Create minimal stubs (will be filled in later tasks):

```tsx
// desktop/frontend/src/pages/Home.tsx
export function Home() { return <div>Home</div> }

// desktop/frontend/src/pages/Transactions.tsx
export function Transactions() { return <div>Transactions</div> }

// desktop/frontend/src/pages/Insights.tsx
export function Insights({ tab }: { tab: string }) { return <div>Insights: {tab}</div> }

// desktop/frontend/src/pages/Profile.tsx
export function Profile() { return <div>Profile</div> }

// desktop/frontend/src/pages/Onboarding.tsx
export function Onboarding() { return <div>Onboarding</div> }

// desktop/frontend/src/modals/AddTransactionModal.tsx
export function AddTransactionModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  return null
}
```

- [ ] **Step 6: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend
npx tsc --noEmit
```

- [ ] **Step 7: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/
git commit -m "feat(frontend): add AppShell layout with Sidebar, TopBar, and HashRouter routing"
```

---

## Task 9: Onboarding screen

**Files:**
- Rewrite: `desktop/frontend/src/pages/Onboarding.tsx`

The onboarding screen detects first launch (no JWT), silently registers an auto-generated account, then collects the user's display name and preferred currency. On submit it updates the profile and redirects to Home.

- [ ] **Step 1: Implement Onboarding.tsx**

```tsx
// desktop/frontend/src/pages/Onboarding.tsx
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '../services/api'
import { useCurrencies } from '../hooks/useCurrencies'

function generateEmail() {
  return `user_${Math.random().toString(36).slice(2, 10)}@moneef.local`
}

export function Onboarding() {
  const navigate = useNavigate()
  const { data: currencies } = useCurrencies()
  const [name, setName] = useState('')
  const [currency, setCurrency] = useState('USD')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const email = generateEmail()
      const password = Math.random().toString(36).slice(2, 18)

      // register
      const regRes = await apiFetch('/api/v1/user/register', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      })
      if (!regRes.ok) throw new Error('Registration failed')

      // login
      const loginRes = await apiFetch('/api/v1/user/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      })
      if (!loginRes.ok) throw new Error('Login failed')
      const { token } = await loginRes.json()
      localStorage.setItem('jwt', token)

      // update profile name
      const [firstName, ...rest] = name.trim().split(' ')
      await apiFetch('/api/v1/user/profile', {
        method: 'PUT',
        body: JSON.stringify({ first_name: firstName, last_name: rest.join(' ') }),
      })

      // update currency setting
      await apiFetch('/api/v1/user/settings', {
        method: 'PUT',
        body: JSON.stringify({ currency_code: currency }),
      })

      navigate('/', { replace: true })
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-base-100 flex items-center justify-center">
      <div className="card bg-base-200 shadow-xl w-full max-w-sm p-8">
        <div className="text-center mb-8">
          <div className="text-5xl mb-3">💜</div>
          <h1 className="text-2xl font-bold">Welcome to Moneef</h1>
          <p className="text-sm text-gray-400 mt-1">Set up your personal finance tracker</p>
        </div>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="form-control">
            <label className="label"><span className="label-text text-xs font-semibold uppercase tracking-wide">Your name</span></label>
            <input
              className="input input-bordered w-full"
              placeholder="e.g. Ali"
              value={name}
              onChange={e => setName(e.target.value)}
              required
            />
          </div>
          <div className="form-control">
            <label className="label"><span className="label-text text-xs font-semibold uppercase tracking-wide">Default currency</span></label>
            <select
              className="select select-bordered w-full"
              value={currency}
              onChange={e => setCurrency(e.target.value)}
            >
              {currencies.map(c => (
                <option key={c.Code} value={c.Code}>{c.Symbol} {c.Code} — {c.Name}</option>
              ))}
            </select>
          </div>
          {error && <div className="alert alert-error text-sm">{error}</div>}
          <button className="btn btn-primary w-full mt-2" disabled={loading}>
            {loading ? <span className="loading loading-spinner loading-sm" /> : 'Get started'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Onboarding.tsx
git commit -m "feat(frontend): add onboarding screen with silent registration"
```

---

## Task 10: UI components (StatCard, CategoryBadge, NotifBar, TransactionTable)

**Files:**
- Create: `desktop/frontend/src/components/ui/StatCard.tsx`
- Create: `desktop/frontend/src/components/ui/CategoryBadge.tsx`
- Create: `desktop/frontend/src/components/ui/NotifBar.tsx`
- Create: `desktop/frontend/src/components/ui/TransactionTable.tsx`

- [ ] **Step 1: StatCard**

```tsx
// desktop/frontend/src/components/ui/StatCard.tsx
interface StatCardProps {
  label: string
  value: string
  borderColor: string
  bgColor?: string
  textColor?: string
}

export function StatCard({ label, value, borderColor, bgColor = 'bg-base-200', textColor = 'text-base-content' }: StatCardProps) {
  return (
    <div className={`rounded-xl px-4 py-3 ${bgColor} border-l-4 flex flex-col gap-1`} style={{ borderLeftColor: borderColor }}>
      <span className="text-[0.7rem] font-semibold uppercase tracking-wide text-gray-400">{label}</span>
      <span className={`text-[1.125rem] font-bold ${textColor}`}>{value}</span>
    </div>
  )
}
```

- [ ] **Step 2: CategoryBadge**

```tsx
// desktop/frontend/src/components/ui/CategoryBadge.tsx
interface CategoryBadgeProps {
  name: string
  color?: string
  icon?: string
}

export function CategoryBadge({ name, color = '#6B5CE7', icon }: CategoryBadgeProps) {
  return (
    <span
      className="inline-flex items-center gap-1 text-[0.7rem] font-medium px-2 py-0.5 rounded"
      style={{ background: color + '22', color }}
    >
      {icon && <span>{icon}</span>}
      {name}
    </span>
  )
}
```

- [ ] **Step 3: NotifBar (animated ticker)**

```tsx
// desktop/frontend/src/components/ui/NotifBar.tsx
interface NotifBarProps {
  items: string[]
}

export function NotifBar({ items }: NotifBarProps) {
  if (items.length === 0) return null
  const text = items.join('   ·   ')

  return (
    <div className="overflow-hidden bg-[#F0EEF9] text-[#6B5CE7] text-[0.75rem] font-medium py-1.5 rounded-lg">
      <div
        className="whitespace-nowrap"
        style={{
          display: 'inline-block',
          animation: 'ticker 20s linear infinite',
        }}
      >
        {text}&nbsp;&nbsp;&nbsp;&nbsp;{text}
      </div>
      <style>{`
        @keyframes ticker {
          0%   { transform: translateX(100vw); }
          100% { transform: translateX(-100%); }
        }
      `}</style>
    </div>
  )
}
```

- [ ] **Step 4: TransactionTable**

```tsx
// desktop/frontend/src/components/ui/TransactionTable.tsx
import type { Transaction } from '../../types/api'
import { CategoryBadge } from './CategoryBadge'

interface TransactionTableProps {
  transactions: Transaction[]
  compact?: boolean
}

function formatAmount(tx: Transaction): string {
  const total = tx.TransactionCategory?.reduce((sum, tc) => sum + parseFloat(tc.amount || '0'), 0) ?? 0
  const sign = tx.type === 'income' ? '+' : '-'
  return `${sign}${total.toFixed(2)}`
}

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

export function TransactionTable({ transactions, compact = false }: TransactionTableProps) {
  if (transactions.length === 0) {
    return (
      <div className="text-center text-sm text-gray-400 py-8">
        No transactions yet — add one to get started.
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-[0.8rem]">
        <tbody>
          {transactions.map(tx => {
            const firstCat = tx.TransactionCategory?.[0]
            const amount = formatAmount(tx)
            const isIncome = tx.type === 'income'
            return (
              <tr key={tx.ID} className="border-b border-base-100 hover:bg-base-100 transition-colors">
                <td className="py-2 pr-3 w-8">
                  <span className="text-base">{tx.icon || '💳'}</span>
                </td>
                <td className="py-2 pr-3 flex-1">
                  <div className="font-medium">{tx.name}</div>
                  {!compact && <div className="text-[0.7rem] text-gray-400">{formatTime(tx.date)}</div>}
                </td>
                <td className="py-2 pr-3">
                  {firstCat && (
                    <CategoryBadge
                      name={firstCat.Category?.name ?? ''}
                      color={firstCat.Category?.color}
                      icon={firstCat.Category?.icon}
                    />
                  )}
                </td>
                <td className={`py-2 text-right font-semibold ${isIncome ? 'text-[#2D7A2D]' : 'text-[#EF5350]'}`}>
                  {amount}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 5: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 6: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/components/ui/
git commit -m "feat(frontend): add StatCard, CategoryBadge, NotifBar, TransactionTable components"
```

---

## Task 11: Home / Dashboard page

**Files:**
- Rewrite: `desktop/frontend/src/pages/Home.tsx`

- [ ] **Step 1: Implement Home.tsx**

```tsx
// desktop/frontend/src/pages/Home.tsx
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboard } from '../hooks/useDashboard'
import { StatCard } from '../components/ui/StatCard'
import { NotifBar } from '../components/ui/NotifBar'
import { TransactionTable } from '../components/ui/TransactionTable'

function formatMoney(val: string | undefined) {
  if (!val) return '0.00'
  return parseFloat(val).toFixed(2)
}

export function Home() {
  const { data, loading, error, refetch } = useDashboard()

  if (loading) {
    return (
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => <div key={i} className="skeleton h-16 rounded-xl" />)}
        </div>
        <div className="skeleton h-8 rounded-lg" />
        <div className="skeleton h-64 rounded-xl" />
      </div>
    )
  }

  if (error) {
    return (
      <div className="alert alert-error">
        <span>{error}</span>
        <button className="btn btn-sm btn-ghost" onClick={refetch}>Retry</button>
      </div>
    )
  }

  const income = formatMoney(data?.period_totals?.Income)
  const expense = formatMoney(data?.period_totals?.Expense)
  const net = (parseFloat(income) - parseFloat(expense)).toFixed(2)

  const chartData = (data?.daily_spend ?? []).map(d => ({
    day: new Date(d.Date).toLocaleDateString('en', { weekday: 'short' }),
    amount: parseFloat(d.Amount),
  }))

  const notifItems = (data?.upcoming_recurring ?? []).map(
    r => `${r.name} · next ${new Date(r.next_date).toLocaleDateString()}`
  )

  return (
    <div className="flex flex-col gap-4">
      {/* Stat strip */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label="Income" value={`$${income}`} borderColor="#2D7A2D" bgColor="bg-[#E8F5E8]" textColor="text-[#2D7A2D]" />
        <StatCard label="Expenses" value={`$${expense}`} borderColor="#EF5350" bgColor="bg-[#FDE8E8]" textColor="text-[#EF5350]" />
        <StatCard label="Net" value={`$${net}`} borderColor="#6B5CE7" />
        <StatCard label="Avg / Day" value={chartData.length ? `$${(parseFloat(expense) / chartData.length).toFixed(2)}` : '$0.00'} borderColor="#26C6DA" />
      </div>

      {/* Notification ticker */}
      {notifItems.length > 0 && <NotifBar items={notifItems} />}

      {/* Two-column: chart + recent transactions */}
      <div className="grid gap-4" style={{ gridTemplateColumns: '1fr 340px' }}>
        <div className="card bg-base-200 rounded-xl p-4">
          <h2 className="text-[0.8rem] font-bold mb-3">Weekly Spending</h2>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} barSize={16}>
              <XAxis dataKey="day" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip formatter={(v: number) => [`$${v.toFixed(2)}`, 'Amount']} />
              <Bar dataKey="amount" fill="#6B5CE7" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="card bg-base-200 rounded-xl p-4">
          <h2 className="text-[0.8rem] font-bold mb-3">Recent Transactions</h2>
          <TransactionTable transactions={data?.recent_transactions ?? []} compact />
        </div>
      </div>

      {/* Two-column bottom: patterns + upcoming */}
      <div className="grid grid-cols-2 gap-4">
        <div className="card bg-base-200 rounded-xl p-4">
          <h2 className="text-[0.8rem] font-bold mb-3">Spending Patterns</h2>
          {(data?.top_categories ?? []).length === 0 ? (
            <p className="text-sm text-gray-400">No patterns yet.</p>
          ) : (
            <ul className="flex flex-col gap-2">
              {(data?.top_categories ?? []).slice(0, 4).map(cat => (
                <li key={cat.CategoryID} className="flex justify-between text-[0.8rem]">
                  <span className="font-medium">{cat.CategoryName}</span>
                  <span className="text-gray-500">${parseFloat(cat.TotalAmount).toFixed(2)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="card bg-base-200 rounded-xl p-4">
          <h2 className="text-[0.8rem] font-bold mb-3">Upcoming Recurring</h2>
          {(data?.upcoming_recurring ?? []).length === 0 ? (
            <p className="text-sm text-gray-400">No upcoming payments.</p>
          ) : (
            <ul className="flex flex-col gap-2">
              {(data?.upcoming_recurring ?? []).slice(0, 3).map(r => (
                <li key={r.ID} className="flex justify-between items-center text-[0.8rem]">
                  <div className="flex items-center gap-2">
                    <span>{r.icon}</span>
                    <span className="font-medium">{r.name}</span>
                  </div>
                  <div className="text-right">
                    <div className="text-[#EF5350] font-semibold">${parseFloat(r.next_payment_amount).toFixed(2)}</div>
                    <div className="text-[0.7rem] text-gray-400">{new Date(r.next_date).toLocaleDateString()}</div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Home.tsx
git commit -m "feat(frontend): implement Home dashboard page"
```

---

## Task 12: Add Transaction modal

**Files:**
- Rewrite: `desktop/frontend/src/modals/AddTransactionModal.tsx`

- [ ] **Step 1: Implement AddTransactionModal.tsx**

```tsx
// desktop/frontend/src/modals/AddTransactionModal.tsx
import { useState } from 'react'
import { apiFetch } from '../services/api'
import { useCategories } from '../hooks/useCategories'
import type { TransactionType } from '../types/api'

interface Props {
  open: boolean
  onClose: () => void
}

interface CategoryRow {
  category_id: string
  amount: string
}

export function AddTransactionModal({ open, onClose }: Props) {
  const { data: categories } = useCategories()
  const [type, setType] = useState<TransactionType>('expense')
  const [name, setName] = useState('')
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [merchant, setMerchant] = useState('')
  const [categoryRows, setCategoryRows] = useState<CategoryRow[]>([{ category_id: '', amount: '' }])
  const [isRecurrent, setIsRecurrent] = useState(false)
  const [frequency, setFrequency] = useState('monthly')
  const [hasEndDate, setHasEndDate] = useState(false)
  const [endDate, setEndDate] = useState('')
  const [totalAmount, setTotalAmount] = useState('')
  const [amountPaid, setAmountPaid] = useState('0')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function addCategoryRow() {
    setCategoryRows(rows => [...rows, { category_id: '', amount: '' }])
  }

  function updateRow(i: number, field: keyof CategoryRow, value: string) {
    setCategoryRows(rows => rows.map((r, idx) => idx === i ? { ...r, [field]: value } : r))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const categories_payload = categoryRows
        .filter(r => r.category_id && r.amount)
        .map(r => ({ category_id: parseInt(r.category_id), amount: r.amount }))

      const body: Record<string, unknown> = {
        name,
        type,
        date: new Date(date).toISOString(),
        merchant_name: merchant || undefined,
        categories: categories_payload,
        is_recurrent: isRecurrent,
      }

      if (isRecurrent) {
        body.frequency = frequency
        body.amount_paid_previously = amountPaid
        if (hasEndDate) {
          body.end_date = new Date(endDate).toISOString()
          body.total_amount_to_pay = totalAmount
        }
      }

      const res = await apiFetch('/api/v1/transaction/create', {
        method: 'POST',
        body: JSON.stringify(body),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error ?? 'Failed to create transaction')
      }
      onClose()
      // reset form
      setName(''); setMerchant(''); setCategoryRows([{ category_id: '', amount: '' }]); setIsRecurrent(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <dialog open className="modal modal-open">
      <div className="modal-box max-w-md">
        <h3 className="font-bold text-base mb-4">Add Transaction</h3>

        {/* Type tabs */}
        <div className="tabs tabs-boxed mb-4">
          <button className={`tab ${type === 'expense' ? 'tab-active' : ''}`} onClick={() => setType('expense')}>Expense</button>
          <button className={`tab ${type === 'income' ? 'tab-active' : ''}`} onClick={() => setType('income')}>Income</button>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <input className="input input-bordered w-full input-sm" placeholder="Transaction name" value={name} onChange={e => setName(e.target.value)} required />
          <input className="input input-bordered w-full input-sm" type="date" value={date} onChange={e => setDate(e.target.value)} required />
          <input className="input input-bordered w-full input-sm" placeholder="Merchant name (optional)" value={merchant} onChange={e => setMerchant(e.target.value)} />

          {/* Category rows */}
          <div className="flex flex-col gap-2">
            {categoryRows.map((row, i) => (
              <div key={i} className="flex gap-2">
                <select className="select select-bordered select-sm flex-1" value={row.category_id} onChange={e => updateRow(i, 'category_id', e.target.value)} required>
                  <option value="">Category</option>
                  {categories.map(c => <option key={c.ID} value={c.ID}>{c.icon} {c.name}</option>)}
                </select>
                <input className="input input-bordered input-sm w-24" placeholder="Amount" value={row.amount} onChange={e => updateRow(i, 'amount', e.target.value)} required />
              </div>
            ))}
            <button type="button" className="btn btn-sm btn-ghost btn-dashed border-dashed border text-xs" onClick={addCategoryRow}>
              + Add Category
            </button>
          </div>

          {/* Recurring */}
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Is Recurring?</span>
            <input type="checkbox" className="toggle toggle-primary toggle-sm" checked={isRecurrent} onChange={e => setIsRecurrent(e.target.checked)} />
          </div>
          {isRecurrent && (
            <div className="flex flex-col gap-2 pl-2 border-l-2 border-primary">
              <select className="select select-bordered select-sm" value={frequency} onChange={e => setFrequency(e.target.value)}>
                <option value="weekly">Weekly</option>
                <option value="bi-weekly">Bi-Weekly</option>
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
              </select>
              <input className="input input-bordered input-sm" placeholder="Amount paid previously" value={amountPaid} onChange={e => setAmountPaid(e.target.value)} />
              <div className="flex items-center justify-between">
                <span className="text-sm">Has end date?</span>
                <input type="checkbox" className="toggle toggle-sm" checked={hasEndDate} onChange={e => setHasEndDate(e.target.checked)} />
              </div>
              {hasEndDate && (
                <>
                  <input className="input input-bordered input-sm" type="date" value={endDate} onChange={e => setEndDate(e.target.value)} />
                  <input className="input input-bordered input-sm" placeholder="Total amount to pay" value={totalAmount} onChange={e => setTotalAmount(e.target.value)} />
                </>
              )}
            </div>
          )}

          {error && <div className="alert alert-error text-sm py-2">{error}</div>}

          <div className="modal-action mt-2">
            <button type="button" className="btn btn-ghost btn-sm" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary btn-sm" disabled={loading}>
              {loading ? <span className="loading loading-spinner loading-xs" /> : 'Add'}
            </button>
          </div>
        </form>
      </div>
      <div className="modal-backdrop" onClick={onClose} />
    </dialog>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/modals/AddTransactionModal.tsx
git commit -m "feat(frontend): implement Add Transaction modal"
```

---

## Task 13: Transactions page

**Files:**
- Rewrite: `desktop/frontend/src/pages/Transactions.tsx`

- [ ] **Step 1: Implement Transactions.tsx**

```tsx
// desktop/frontend/src/pages/Transactions.tsx
import { useState, useMemo } from 'react'
import { useTransactions } from '../hooks/useTransactions'
import { useRecurrences } from '../hooks/useRecurrences'
import { TransactionTable } from '../components/ui/TransactionTable'
import type { Transaction } from '../types/api'

function groupByDate(txs: Transaction[]): Map<string, Transaction[]> {
  const map = new Map<string, Transaction[]>()
  for (const tx of txs) {
    const key = new Date(tx.date).toLocaleDateString('en', { year: 'numeric', month: 'long', day: 'numeric' })
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(tx)
  }
  return map
}

export function Transactions() {
  const { data: transactions, loading, error, refetch } = useTransactions()
  const { data: recurrences } = useRecurrences()
  const [search, setSearch] = useState('')
  const [activeCategory, setActiveCategory] = useState<string | null>(null)

  const categories = useMemo(() => {
    const seen = new Set<string>()
    for (const tx of transactions) {
      for (const tc of tx.TransactionCategory ?? []) {
        if (tc.Category?.name) seen.add(tc.Category.name)
      }
    }
    return Array.from(seen)
  }, [transactions])

  const filtered = useMemo(() => {
    return transactions.filter(tx => {
      const matchSearch = !search || tx.name.toLowerCase().includes(search.toLowerCase()) || (tx.merchant_name ?? '').toLowerCase().includes(search.toLowerCase())
      const matchCat = !activeCategory || tx.TransactionCategory?.some(tc => tc.Category?.name === activeCategory)
      return matchSearch && matchCat
    })
  }, [transactions, search, activeCategory])

  const grouped = groupByDate(filtered)

  if (loading) return <div className="skeleton h-64 rounded-xl" />
  if (error) return <div className="alert alert-error">{error}<button className="btn btn-sm btn-ghost ml-2" onClick={refetch}>Retry</button></div>

  return (
    <div className="flex flex-col gap-4">
      {/* Toolbar */}
      <div className="flex items-center gap-3">
        <input
          className="input input-bordered input-sm flex-1 max-w-xs"
          placeholder="Search transactions..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {/* Category pill strip */}
      <div className="flex gap-2 overflow-x-auto pb-1">
        <button
          className={`btn btn-sm flex-shrink-0 ${!activeCategory ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => setActiveCategory(null)}
        >
          All
        </button>
        {categories.map(cat => (
          <button
            key={cat}
            className={`btn btn-sm flex-shrink-0 ${activeCategory === cat ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => setActiveCategory(cat === activeCategory ? null : cat)}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Transaction groups */}
      {filtered.length === 0 ? (
        <div className="text-center text-gray-400 text-sm py-12">
          No transactions yet — add one to get started.
        </div>
      ) : (
        Array.from(grouped.entries()).map(([date, txs]) => {
          const dayNet = txs.reduce((sum, tx) => {
            const total = tx.TransactionCategory?.reduce((s, tc) => s + parseFloat(tc.amount || '0'), 0) ?? 0
            return sum + (tx.type === 'income' ? total : -total)
          }, 0)
          return (
            <div key={date} className="card bg-base-200 rounded-xl p-4">
              <div className="flex justify-between items-center mb-2">
                <span className="text-[0.8rem] font-bold">{date}</span>
                <span className={`text-[0.75rem] font-semibold ${dayNet >= 0 ? 'text-[#2D7A2D]' : 'text-[#EF5350]'}`}>
                  {dayNet >= 0 ? '+' : ''}{dayNet.toFixed(2)}
                </span>
              </div>
              <TransactionTable transactions={txs} />
            </div>
          )
        })
      )}

      {/* Recurring section */}
      {recurrences.length > 0 && (
        <div className="card bg-base-200 rounded-xl p-4">
          <div className="flex justify-between items-center mb-3">
            <h2 className="text-[0.8rem] font-bold">Recurring Transactions</h2>
          </div>
          <div className="flex flex-col gap-2">
            {recurrences.map(r => (
              <div key={r.ID} className="flex justify-between items-center text-[0.8rem] py-1.5 border-b border-base-100 last:border-0">
                <div className="flex items-center gap-2">
                  <span className="w-7 h-7 rounded flex items-center justify-center text-sm" style={{ background: r.color + '33' }}>{r.icon}</span>
                  <div>
                    <div className="font-medium">{r.name}</div>
                    <div className="text-[0.7rem] text-gray-400">Next · {new Date(r.next_date).toLocaleDateString()}</div>
                  </div>
                </div>
                <span className="text-[#EF5350] font-semibold">${parseFloat(r.next_payment_amount).toFixed(2)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Transactions.tsx
git commit -m "feat(frontend): implement Transactions page"
```

---

## Task 14: Insights page

**Files:**
- Rewrite: `desktop/frontend/src/pages/Insights.tsx`

- [ ] **Step 1: Implement Insights.tsx**

```tsx
// desktop/frontend/src/pages/Insights.tsx
import { useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend,
  LineChart, Line, RadarChart, PolarGrid, PolarAngleAxis, Radar
} from 'recharts'
import { useInsights } from '../hooks/useInsights'
import { usePatterns } from '../hooks/usePatterns'
import { StatCard } from '../components/ui/StatCard'

interface InsightsProps {
  tab: 'overview' | 'analysis' | 'patterns'
}

function getPeriodDates(): { start: string; end: string } {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  const end = now.toISOString()
  return { start, end }
}

export function Insights({ tab }: InsightsProps) {
  const { start, end } = useMemo(() => getPeriodDates(), [])
  const { data, loading, error, refetch } = useInsights(start, end)
  const { data: patterns, loading: pLoading } = usePatterns()
  const navigate = useNavigate()

  if (loading) return <div className="skeleton h-96 rounded-xl" />
  if (error) return <div className="alert alert-error">{error} <button className="btn btn-sm btn-ghost" onClick={refetch}>Retry</button></div>

  const charts = data?.AnalysisCharts

  const income = 0 // dashboard endpoint; insights only has expense breakdown
  const expense = parseFloat(charts?.total ?? '0')
  const net = -expense

  // Merge current and last-period spend-per-day by date label for grouped bar chart
  const spendPerDayData = useMemo(() => {
    const map = new Map<string, { date: string; current: number; last: number }>()
    for (const d of charts?.spent_per_day ?? []) {
      const key = new Date(d.date).toLocaleDateString('en', { month: 'short', day: 'numeric' })
      map.set(key, { date: key, current: parseFloat(d.amount), last: 0 })
    }
    for (const d of charts?.spent_per_day_last_period ?? []) {
      const key = new Date(d.date).toLocaleDateString('en', { month: 'short', day: 'numeric' })
      const existing = map.get(key) ?? { date: key, current: 0, last: 0 }
      map.set(key, { ...existing, last: parseFloat(d.amount) })
    }
    return Array.from(map.values())
  }, [charts])

  const categoryData = (charts?.categories ?? []).map(c => ({
    name: c.category_name,
    amount: parseFloat(c.total_amount),
    pct: parseFloat(c.percentage),
  }))

  return (
    <div className="flex flex-col gap-4">
      {/* Sub-tab bar */}
      <div className="tabs tabs-boxed w-fit">
        <button className={`tab ${tab === 'overview' ? 'tab-active' : ''}`} onClick={() => navigate('/insights')}>Overview</button>
        <button className={`tab ${tab === 'analysis' ? 'tab-active' : ''}`} onClick={() => navigate('/insights/analysis')}>Analysis</button>
        <button className={`tab ${tab === 'patterns' ? 'tab-active' : ''}`} onClick={() => navigate('/insights/patterns')}>Patterns</button>
      </div>

      {tab === 'overview' && (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-3 gap-4">
            <StatCard label="Expenses" value={`$${expense.toFixed(2)}`} borderColor="#EF5350" bgColor="bg-[#FDE8E8]" textColor="text-[#EF5350]" />
            <StatCard label="Net" value={`$${net.toFixed(2)}`} borderColor="#6B5CE7" />
            <StatCard label="Categories" value={`${categoryData.length}`} borderColor="#26C6DA" />
          </div>

          {/* Category breakdown */}
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Spending by Category</h2>
            {categoryData.length === 0 ? (
              <p className="text-sm text-gray-400">No data for this period.</p>
            ) : (
              <div className="flex flex-col gap-2">
                {categoryData.map(c => (
                  <div key={c.name} className="flex items-center gap-3">
                    <span className="text-[0.75rem] w-28 truncate">{c.name}</span>
                    <div className="flex-1 bg-base-100 rounded-full h-2 overflow-hidden">
                      <div className="h-2 rounded-full bg-primary" style={{ width: `${Math.min(c.pct, 100)}%` }} />
                    </div>
                    <span className="text-[0.75rem] w-16 text-right">${c.amount.toFixed(2)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Pattern insights */}
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Spending Patterns</h2>
            {pLoading ? (
              <div className="skeleton h-20" />
            ) : patterns.length === 0 ? (
              <p className="text-sm text-gray-400">No patterns detected yet.</p>
            ) : (
              <ul className="flex flex-col gap-2">
                {patterns.slice(0, 3).map(p => (
                  <li key={p.ID} className="text-[0.8rem] flex gap-2 items-start">
                    <span className="text-primary">•</span>
                    <span>{p.description}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}

      {tab === 'analysis' && (
        <div className="flex flex-col gap-4">
          {/* Spending trends bar chart */}
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Daily Spending — This Period vs Last</h2>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={spendPerDayData} barSize={8}>
                <XAxis dataKey="date" tick={{ fontSize: 10 }} />
                <YAxis hide />
                <Tooltip />
                <Legend />
                <Bar dataKey="current" name="This period" fill="#6B5CE7" radius={[3, 3, 0, 0]} />
                <Bar dataKey="last" name="Last period" fill="#A89EF0" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Cumulative line chart */}
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Cumulative Spending</h2>
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={spendPerDayData}>
                <XAxis dataKey="date" tick={{ fontSize: 10 }} />
                <YAxis hide />
                <Tooltip />
                <Line type="monotone" dataKey="current" stroke="#6B5CE7" dot={false} strokeWidth={2} name="This period" />
                <Line type="monotone" dataKey="last" stroke="#A89EF0" dot={false} strokeWidth={2} strokeDasharray="4 2" name="Last period" />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Category radar */}
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Spending by Category (Radar)</h2>
            {categoryData.length > 0 ? (
              <ResponsiveContainer width="100%" height={220}>
                <RadarChart data={categoryData}>
                  <PolarGrid />
                  <PolarAngleAxis dataKey="name" tick={{ fontSize: 10 }} />
                  <Radar name="Amount" dataKey="amount" fill="#6B5CE7" fillOpacity={0.3} stroke="#6B5CE7" />
                </RadarChart>
              </ResponsiveContainer>
            ) : (
              <p className="text-sm text-gray-400">No data.</p>
            )}
          </div>

          {/* Upcoming recurring */}
          {(charts?.next_recurring_transactions ?? []).length > 0 && (
            <div className="card bg-base-200 rounded-xl p-4">
              <h2 className="text-[0.8rem] font-bold mb-3">Upcoming Recurring</h2>
              <ul className="flex flex-col gap-2">
                {charts!.next_recurring_transactions.map((r, i) => (
                  <li key={i} className="flex justify-between text-[0.8rem]">
                    <span>{r.name}</span>
                    <div className="text-right">
                      <div className="text-[#EF5350] font-semibold">${parseFloat(r.amount).toFixed(2)}</div>
                      <div className="text-[0.7rem] text-gray-400">{new Date(r.date).toLocaleDateString()}</div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {tab === 'patterns' && (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4">
            <StatCard label="Patterns Found" value={`${patterns.length}`} borderColor="#6B5CE7" />
            <StatCard label="Top Score" value={patterns[0] ? `${patterns[0].final_score.toFixed(0)}%` : '—'} borderColor="#26C6DA" />
          </div>
          <div className="card bg-base-200 rounded-xl p-4">
            <h2 className="text-[0.8rem] font-bold mb-3">Spending Pattern Insights</h2>
            {pLoading ? (
              <div className="skeleton h-32" />
            ) : patterns.length === 0 ? (
              <p className="text-sm text-gray-400">No patterns detected. Add more transactions to build history.</p>
            ) : (
              <ul className="flex flex-col gap-3">
                {patterns.map(p => (
                  <li key={p.ID} className="flex gap-3 items-start border-b border-base-100 pb-3 last:border-0">
                    <span className="text-primary text-lg">💡</span>
                    <div>
                      <div className="text-[0.8rem] font-medium">{p.description}</div>
                      <div className="text-[0.7rem] text-gray-400 mt-0.5">
                        Score: {p.final_score.toFixed(0)}% · {p.pattern_type} · {new Date(p.created_at).toLocaleDateString()}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Insights.tsx
git commit -m "feat(frontend): implement Insights page with Overview, Analysis, Patterns tabs"
```

---

## Task 15: Profile page

**Files:**
- Rewrite: `desktop/frontend/src/pages/Profile.tsx`

- [ ] **Step 1: Implement Profile.tsx**

```tsx
// desktop/frontend/src/pages/Profile.tsx
import { useState, useEffect } from 'react'
import { useProfile } from '../hooks/useProfile'
import { useCategories } from '../hooks/useCategories'
import { useRecurrences } from '../hooks/useRecurrences'
import { useCurrencies } from '../hooks/useCurrencies'
import { useTheme } from '../hooks/useTheme'
import { apiFetch } from '../services/api'
import { CategoryBadge } from '../components/ui/CategoryBadge'

export function Profile() {
  const { profile, settings, loading, error, refetch } = useProfile()
  const { data: categories, refetch: refetchCategories } = useCategories()
  const { data: recurrences, refetch: refetchRecurrences } = useRecurrences()
  const { data: currencies } = useCurrencies()
  const { theme, toggleTheme } = useTheme()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [currency, setCurrency] = useState('USD')
  const [notifications, setNotifications] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)

  useEffect(() => {
    if (profile) { setFirstName(profile.first_name); setLastName(profile.last_name) }
    if (settings) { setCurrency(settings.currency_code); setNotifications(settings.is_notification_enabled) }
  }, [profile, settings])

  async function saveProfile() {
    setSaving(true)
    setSaveError(null)
    try {
      await apiFetch('/api/v1/user/profile', {
        method: 'PUT',
        body: JSON.stringify({ first_name: firstName, last_name: lastName }),
      })
      await apiFetch('/api/v1/user/settings', {
        method: 'PUT',
        body: JSON.stringify({ currency_code: currency, is_notification_enabled: notifications }),
      })
      refetch()
    } catch (e: any) {
      setSaveError(e.message)
    } finally {
      setSaving(false)
    }
  }

  async function deleteCategory(id: number) {
    await apiFetch(`/api/v1/category/${id}`, { method: 'DELETE' })
    refetchCategories()
  }

  async function deleteRecurrence(id: number) {
    await apiFetch(`/api/v1/recurrence/${id}`, { method: 'DELETE' })
    refetchRecurrences()
  }

  if (loading) return <div className="skeleton h-96 rounded-xl max-w-[640px] mx-auto" />
  if (error) return <div className="alert alert-error max-w-[640px] mx-auto">{error}</div>

  return (
    <div className="max-w-[640px] mx-auto flex flex-col gap-4">
      {/* User card */}
      <div className="card bg-base-200 rounded-xl p-6">
        <div className="flex items-center gap-4 mb-4">
          <div className="avatar placeholder">
            <div className="bg-primary text-white rounded-full w-14">
              <span className="text-xl">{firstName?.[0] ?? '?'}</span>
            </div>
          </div>
          <div>
            <div className="font-bold text-base">{firstName} {lastName}</div>
            <div className="text-[0.75rem] text-gray-400">Local account</div>
          </div>
        </div>
        <div className="flex flex-col gap-2">
          <div className="flex gap-2">
            <input className="input input-bordered input-sm flex-1" placeholder="First name" value={firstName} onChange={e => setFirstName(e.target.value)} />
            <input className="input input-bordered input-sm flex-1" placeholder="Last name" value={lastName} onChange={e => setLastName(e.target.value)} />
          </div>
        </div>
      </div>

      {/* Preferences */}
      <div className="card bg-base-200 rounded-xl p-6">
        <h2 className="text-[0.8rem] font-bold uppercase tracking-wide mb-4">Preferences</h2>
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <span className="text-sm">Currency</span>
            <select className="select select-bordered select-sm w-40" value={currency} onChange={e => setCurrency(e.target.value)}>
              {currencies.map(c => <option key={c.Code} value={c.Code}>{c.Symbol} {c.Code}</option>)}
            </select>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm">Notifications</span>
            <input type="checkbox" className="toggle toggle-primary toggle-sm" checked={notifications} onChange={e => setNotifications(e.target.checked)} />
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm">Dark Mode</span>
            <input type="checkbox" className="toggle toggle-primary toggle-sm" checked={theme === 'moneef-dark'} onChange={toggleTheme} />
          </div>
        </div>
        {saveError && <div className="alert alert-error text-sm mt-3">{saveError}</div>}
        <button className="btn btn-primary btn-sm mt-4 w-full" onClick={saveProfile} disabled={saving}>
          {saving ? <span className="loading loading-spinner loading-xs" /> : 'Save Changes'}
        </button>
      </div>

      {/* Categories */}
      <div className="card bg-base-200 rounded-xl p-6">
        <h2 className="text-[0.8rem] font-bold uppercase tracking-wide mb-4">Categories</h2>
        <div className="flex flex-wrap gap-2">
          {categories.filter(c => c.profile_id).map(c => (
            <div key={c.ID} className="flex items-center gap-1">
              <CategoryBadge name={c.name} color={c.color} icon={c.icon} />
              <button className="btn btn-xs btn-ghost text-error" onClick={() => deleteCategory(c.ID)}>×</button>
            </div>
          ))}
        </div>
        {categories.filter(c => c.profile_id).length === 0 && (
          <p className="text-sm text-gray-400">No custom categories yet.</p>
        )}
      </div>

      {/* Recurring */}
      <div className="card bg-base-200 rounded-xl p-6">
        <h2 className="text-[0.8rem] font-bold uppercase tracking-wide mb-4">Recurring Transactions</h2>
        {recurrences.length === 0 ? (
          <p className="text-sm text-gray-400">No recurring transactions.</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {recurrences.map(r => (
              <li key={r.ID} className="flex justify-between items-center text-[0.8rem]">
                <div className="flex items-center gap-2">
                  <span>{r.icon}</span>
                  <span className="font-medium">{r.name}</span>
                  <span className="text-gray-400 text-[0.7rem]">{r.frequency}</span>
                </div>
                <button className="btn btn-xs btn-ghost text-error" onClick={() => deleteRecurrence(r.ID)}>Delete</button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npx tsc --noEmit
```

- [ ] **Step 3: Run all Go tests**

```bash
cd /home/james/GolandProjects/moneef-backend && go test ./... -v
```

- [ ] **Step 4: Build frontend**

```bash
cd /home/james/GolandProjects/moneef-backend/desktop/frontend && npm run build
```
Expected: dist/ output with no errors.

- [ ] **Step 5: Commit**

```bash
cd /home/james/GolandProjects/moneef-backend
git add desktop/frontend/src/pages/Profile.tsx
git commit -m "feat(frontend): implement Profile page"
```

---

## Final verification

- [ ] Run full Go test suite: `go test ./... -v`
- [ ] Build frontend production bundle: `cd desktop/frontend && npm run build`
- [ ] Start dev server: `wails dev -tags webkit2_41`
- [ ] Walk through: Onboarding → Home → Add Transaction → Transactions → Insights → Profile
- [ ] Toggle dark mode — confirm `data-theme` persists across navigation
- [ ] Commit any remaining fixes
