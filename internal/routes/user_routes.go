package routes

import (
	"github.com/go-chi/chi/v5"
	"goMangaObserver/internal/handlers"
)

func UserRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/login", handlers.LoginUserHandler)
	return r
}
