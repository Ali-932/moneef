package routes

import (
	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"goMangaObserver/pkg/middleware"
)

func SetupRoutes() *chi.Mux {
	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.CORSMiddleware)
		r.Mount("/user", UserRoutes())
		//r.Group(func(r chi.Router) {
		//	r.Use(middleware.AuthMiddleware)
		//	// protected rorutes
		//
		//}

	})

	return r
}
