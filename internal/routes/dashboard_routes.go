package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/dashboard"
)

func DashboardRoutes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", dashboard.GetDashboardHandler)
	return r
}
