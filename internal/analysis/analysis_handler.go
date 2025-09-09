package analysis

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"log"
	"moneef/pkg/utils"
	"net/http"
)

func SpendByCategoryChartHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req SpendByCategoryChartRequest
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
	res, err := GetSpendByCategoryChart(profileID, req.StartDate, req.EndDate)
	if err != nil {
		log.Printf("❌ [HANDLER] Service error: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Internal Server Error")
		return
	}

	response := SpendByCategoryChartResponse(*res)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response)
	w.WriteHeader(http.StatusOK)
}
