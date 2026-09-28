package routes

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"moneef/internal/currencies"
	"moneef/internal/users"
	"moneef/pkg/middleware"
)

func SetupRoutes() http.Handler {
	r := chi.NewRouter()
	r.Use(chiMiddleware.Logger)
	r.Use(corsMiddleware)

	r.Route("/api/v1", func(r chi.Router) {
		r.Post("/setup", users.SetupHandler)
		r.Get("/currencies", currencies.ListCurrenciesHandler)
		r.Get("/healthz", HealthCheckHandler)

		r.Group(func(r chi.Router) {
			r.Use(middleware.ProfileMiddleware)
			r.Mount("/transaction", TransactionRoutes())
			r.Mount("/analysis", AnalysisRoute())
			r.Mount("/category", CategoryRoutes())
			r.Mount("/dashboard", DashboardRoutes())
			r.Mount("/recurrence", RecurrenceRoutes())
			r.Mount("/user", UserRoutes())
		})
	})

	return r
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Profile-ID")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
