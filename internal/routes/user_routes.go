package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/auth"
	"moneef/internal/users"
)

func UserRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/login", auth.LoginUserHandler)
	r.Post("/register", users.RegisterUserHandler)
	return r
}
