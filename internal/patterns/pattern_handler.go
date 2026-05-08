package patterns

import (
	"encoding/json"
	"log"
	"moneef/internal/db"
	"moneef/internal/patterns/pattern_engine"
	"moneef/internal/patterns/repository"
	"moneef/pkg/utils"
	"net/http"

	"gorm.io/gorm"
)

func GetPatternsHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
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

func RefreshPatternsHandler(w http.ResponseWriter, r *http.Request) {
	profileID, ok := r.Context().Value("profileID").(uint)
	if !ok {
		log.Printf("❌ [HANDLER] profileID not found in context")
		utils.WriteJsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	patterns, err := pattern_engine.GetUserPatterns(profileID)
	if err != nil {
		log.Printf("❌ [HANDLER] Pattern engine error: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to analyze patterns")
		return
	}

	if err := db.DB.Transaction(func(tx *gorm.DB) error {
		return repository.UpsertPatterns(tx, profileID, patterns)
	}); err != nil {
		log.Printf("❌ [HANDLER] Failed to upsert patterns: %v", err)
		utils.WriteJsonError(w, http.StatusInternalServerError, "Failed to save patterns")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(patterns)
	w.WriteHeader(http.StatusOK)
}
