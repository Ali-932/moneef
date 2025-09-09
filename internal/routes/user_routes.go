package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/auth"
)

func UserRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/login", auth.LoginUserHandler)
	return r
}
