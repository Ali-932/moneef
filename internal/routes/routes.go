package routes

import (
	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"moneef/internal/currencies"
	"moneef/pkg/middleware"
)

func SetupRoutes() *chi.Mux {
	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(chiMiddleware.Logger)
		r.Use(middleware.CORSMiddleware)

		r.Group(func(r chi.Router) {
			r.Mount("/user", UserRoutes())
		})

		r.Get("/currencies", currencies.ListCurrenciesHandler)

		r.Group(func(r chi.Router) {
			r.Use(middleware.AuthMiddleware)
			r.Mount("/transaction", TransactionRoutes())
			r.Mount("/analysis", AnalysisRoute())
			r.Mount("/category", CategoryRoutes())
			r.Mount("/dashboard", DashboardRoutes())
			r.Mount("/recurrence", RecurrenceRoutes())
		})
	})

	return r
}
