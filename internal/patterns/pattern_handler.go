package patterns

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"gorm.io/gorm"

	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/patterns/engine"
	"moneef/internal/patterns/pattern_engine"
	"moneef/internal/patterns/repository"
	"moneef/pkg/middleware"
	"moneef/pkg/utils"
)

func GetPatternsHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value(middleware.ContextKeyProfileID).(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	patterns, err := repository.GetPatternsByProfileID(db.DB, profileID)
	if err != nil {
		log.Printf("❌ [HANDLER] Failed to get patterns: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to load patterns")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(patterns)
	w.WriteHeader(http.StatusOK)
}

type RefreshPatternsRequest struct {
	StartDate *string `json:"start_date,omitempty"`
	EndDate   *string `json:"end_date,omitempty"`
}

func RefreshPatternsHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value(middleware.ContextKeyProfileID).(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req RefreshPatternsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		// Empty body is fine — defaults to all-time
		req = RefreshPatternsRequest{}
	}

	var startDate, endDate *time.Time
	if req.StartDate != nil && req.EndDate != nil {
		parsedStart, err := time.Parse(time.RFC3339, *req.StartDate)
		if err == nil {
			startDate = &parsedStart
		}
		parsedEnd, err := time.Parse(time.RFC3339, *req.EndDate)
		if err == nil {
			endDate = &parsedEnd
		}
	}

	isCustomRange := startDate != nil && endDate != nil

	patterns, err := pattern_engine.GetUserPatterns(profileID, startDate, endDate)
	if err != nil {
		log.Printf("❌ [HANDLER] Pattern engine error: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to analyze patterns")
		return
	}

	if isCustomRange {
		// Transient analysis: resolve icons in-memory, do not persist
		for i := range patterns {
			engine.ResolvePatternIconInMemory(&patterns[i])
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(patterns)
		w.WriteHeader(http.StatusOK)
		return
	}

	// All-time analysis: persist to DB
	var persisted []models.Pattern
	if err := db.DB.Transaction(func(tx *gorm.DB) error {
		result, err := repository.UpsertPatterns(tx, profileID, patterns)
		if err != nil {
			return err
		}
		persisted = result
		return nil
	}); err != nil {
		log.Printf("❌ [HANDLER] Failed to upsert patterns: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to save patterns")
		return
	}

	for i := range persisted {
		engine.ResolvePatternIcon(persisted[i].ID)
	}

	finalPatterns, err := repository.GetPatternsByProfileID(db.DB, profileID)
	if err != nil {
		log.Printf("❌ [HANDLER] Failed to reload patterns after icon resolution: %v", err)
		finalPatterns = persisted
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(finalPatterns)
	w.WriteHeader(http.StatusOK)
}
