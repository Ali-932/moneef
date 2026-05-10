package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/transactions"
)

func RecurrenceRoutes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", transactions.ListRecurrencesHandler)
	r.Get("/timeline", transactions.GetTimelineHandler)
	r.Put("/{id}", transactions.UpdateRecurrenceHandler)
	r.Delete("/{id}", transactions.DeleteRecurrenceHandler)
	return r
}
