package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/analysis"
	"moneef/internal/patterns"
)

func AnalysisRoute() chi.Router {
	r := chi.NewRouter()
	r.Post("/get_spending_by_category", analysis.GetAllAnalysisCharts)
	r.Get("/patterns", patterns.GetPatternsHandler)
	r.Post("/patterns/refresh", patterns.RefreshPatternsHandler)
	return r
}
