package analysis

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"moneef/internal/analysis/dto"
	"moneef/internal/analysis/service"
	analysisUtils "moneef/internal/analysis/utils"
	userRepo "moneef/internal/users/repository"
	"moneef/pkg/middleware"
	"moneef/pkg/utils"
)

func GetAllAnalysisCharts(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value(middleware.ContextKeyProfileID).(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID, ok := r.Context().Value(middleware.ContextKeyUserID).(uint)
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
	if !req.StartDate.IsZero() && !req.EndDate.IsZero() && !req.StartDate.Before(req.EndDate) {
		utils.WriteJsonError(w, http.StatusBadRequest, "start_date must be before end_date")
		return
	}

	q := r.URL.Query()
	aggregationParam := q.Get("aggregation")
	topN, _ := strconv.Atoi(q.Get("top_n"))

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

	if topN > 0 && topN < len(res.Categories) {
		res.Categories = res.Categories[:topN]
	}

	var aggregated []dto.AggregatedPeriod
	if aggregationParam != "" {
		agg := analysisUtils.Aggregation(aggregationParam)
		aggregated = analysisUtils.AggregateByPeriod(res.SpentPerDay, agg)
	}

	response := dto.SpendByCategoryChartResponse{
		AnalysisCharts: *res,
		StartDate:      req.StartDate,
		EndDate:        req.EndDate,
		Currency:       currency,
		Aggregated:     aggregated,
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response)
}
