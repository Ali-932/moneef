package categories

import (
	"encoding/json"
	"errors"
	"moneef/internal/categories/dto"
	"moneef/internal/categories/service"
	"moneef/pkg/utils"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"gorm.io/gorm"
)

func ListCategoriesHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	categories, err := service.ListCategories(profileID)
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to list categories")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(categories)
}

func CreateCategoryHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.CreateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}

	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	category, err := service.CreateCategory(profileID, req)
	if errors.Is(err, service.ErrDuplicateName) {
		utils.WriteJsonError(w, http.StatusConflict, "Category name already exists")
		return
	}
	if err != nil {
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to create category")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(category)
}

func UpdateCategoryHandler(w http.ResponseWriter, r *http.Request) {
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

	var req dto.UpdateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}

	if err := service.UpdateCategory(uint(categoryID), profileID, req); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			utils.WriteJsonError(w, http.StatusNotFound, "Category not found or cannot edit default categories")
			return
		}
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to update category")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "category updated"})
}
