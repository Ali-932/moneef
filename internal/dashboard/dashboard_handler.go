package dashboard

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"moneef/internal/dashboard/service"
	"moneef/pkg/middleware"
	"moneef/pkg/utils"
)

func GetDashboardHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value(middleware.ContextKeyProfileID).(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	q := r.URL.Query()
	var dateFrom, dateTo *time.Time

	if fromStr := q.Get("date_from"); fromStr != "" {
		if t, err := time.Parse("2006-01-02", fromStr); err == nil {
			dateFrom = &t
		}
	}
	if toStr := q.Get("date_to"); toStr != "" {
		if t, err := time.Parse("2006-01-02", toStr); err == nil {
			// Include the full day
			t = t.Add(24*time.Hour - time.Second)
			dateTo = &t
		}
	}

	res, err := service.GetDashboard(profileID, dateFrom, dateTo)
	if err != nil {
		log.Printf("❌ [HANDLER] Dashboard service error: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to load dashboard")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(res)
}
