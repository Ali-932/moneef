package analysis

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"log"
	"moneef/internal/analysis/dto"
	"moneef/internal/analysis/service"
	userRepo "moneef/internal/users/repository"
	"moneef/pkg/utils"
	"net/http"
)

func GetAllAnalysisCharts(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
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
		log.Printf("❌ [HANDLER] Failed to decode request body: %v", err)
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		log.Printf("❌ [HANDLER] Validation failed: %v", err)
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
		log.Printf("❌ [HANDLER] Service error: %v", err)
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
	w.WriteHeader(http.StatusOK)
}
