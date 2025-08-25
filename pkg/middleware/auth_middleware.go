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
		username, ok := claims["username"].(string)
		var user models.User
		UserResult := db.DB.Where("username = ?", username).First(&user)
		if UserResult.Error != nil {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Error while handling token")
			return
		}
		if !ok {
			utils.WriteJsonError(w, http.StatusUnauthorized, "Error while handling token")
			return

		}
		ctx := context.WithValue(r.Context(), "id", user.ID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
