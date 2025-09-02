package middleware

import (
	"context"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/utils"
	"net/http"
	"strings"
)

func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		AuthHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(AuthHeader, "Bearer") {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Missing token")
			return
		}
		token := strings.TrimPrefix(AuthHeader, "Bearer ")

		claims, err := utils.ValidateJWT(token)
		if err != nil {
			utils.WriteJsonError(w, http.StatusUnauthorized, err.Error())

			return
		}
		email, ok := claims["email"].(string)
		var user models.User
		UserResult := db.DB.Where("email = ?", email).Preload("Profile").First(&user)
		if UserResult.Error != nil {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Error while handling token")
			return
		}
		if !ok {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Error while handling token")
			return
		}
		if user.Profile.ID == 0 {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Profile not found")
			return
		}
		ctx := context.WithValue(r.Context(), "id", user.ID)
		ctx = context.WithValue(ctx, "profileID", user.Profile.ID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
