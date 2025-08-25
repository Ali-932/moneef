package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/handlers"
)

func TransactionRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/create", handlers.CreateTransactionHandler)
	return r
}
