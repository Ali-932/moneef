package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/transactions"
)

func TransactionRoutes() chi.Router {
	r := chi.NewRouter()
	r.Post("/create", transactions.CreateTransactionHandler)
	r.Get("/", transactions.ListTransactionsHandler)
	r.Route("/{id}", func(r chi.Router) {
		r.Get("/", transactions.GetTransactionHandler)
		r.Put("/", transactions.UpdateTransactionHandler)
		r.Delete("/", transactions.DeleteTransactionHandler)
	})
	return r
}
