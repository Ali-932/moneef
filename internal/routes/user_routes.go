package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/users"
)

func UserRoutes() chi.Router {
	r := chi.NewRouter()
	r.Get("/profile", users.GetProfileHandler)
	r.Put("/profile", users.UpdateProfileHandler)
	r.Get("/settings", users.GetSettingsHandler)
	r.Put("/settings", users.UpdateSettingsHandler)
	r.Get("/rates", users.ListExchangeRatesHandler)
	r.Put("/rates", users.UpsertExchangeRateHandler)
	r.Post("/rates/fetch", users.FetchExchangeRatesHandler)
	return r
}
