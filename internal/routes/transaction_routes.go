package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/transactions"
)

func TransactionRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/create", transactions.CreateTransactionHandler)
	return r
}
