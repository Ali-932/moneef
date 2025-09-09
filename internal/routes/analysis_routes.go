package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/analysis"
)

func AnalysisRoute() chi.Router {
	r := chi.NewRouter()
	r.Post("/get_spending_by_category", analysis.SpendByCategoryChartHandler)
	return r
}
