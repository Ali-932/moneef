package middleware

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"moneef/internal/db"
	"moneef/internal/models"

	"gorm.io/gorm"
)

func ProfileMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		profileIDStr := r.Header.Get("X-Profile-ID")
		if profileIDStr == "" {
			http.Error(w, `{"error":"X-Profile-ID header required"}`, http.StatusUnauthorized)
			return
		}

		profileID, err := strconv.ParseUint(profileIDStr, 10, 32)
		if err != nil {
			http.Error(w, `{"error":"invalid profile ID"}`, http.StatusBadRequest)
			return
		}

		var profile models.Profile
		fmt.Printf("profileID: %d\n", profileID)
		if err := db.DB.Preload("User").Where("id = ?", profileID).
			First(&profile).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				http.Error(w, `{"error":"profile not found"}`, http.StatusNotFound)
				return
			}
			http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
			return
		}

		ctx := context.WithValue(r.Context(), ContextKeyProfileID, uint(profileID))
		ctx = context.WithValue(ctx, ContextKeyUserID, profile.UserID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
