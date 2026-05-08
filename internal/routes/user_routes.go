package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/auth"
	"moneef/internal/users"
	"moneef/pkg/middleware"
)

func UserRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/login", auth.LoginUserHandler)
	r.Post("/register", users.RegisterUserHandler)

	r.Group(func(r chi.Router) {
		r.Use(middleware.AuthMiddleware)
		r.Get("/profile", users.GetProfileHandler)
		r.Put("/profile", users.UpdateProfileHandler)
		r.Get("/settings", users.GetSettingsHandler)
		r.Put("/settings", users.UpdateSettingsHandler)
	})

	return r
}
