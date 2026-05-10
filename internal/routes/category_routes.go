package routes

import (
	"github.com/go-chi/chi/v5"
	"moneef/internal/categories"
)

func CategoryRoutes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", categories.ListCategoriesHandler)
	r.Post("/", categories.CreateCategoryHandler)
	r.Put("/{id}", categories.UpdateCategoryHandler)
	r.Delete("/{id}", categories.DeleteCategoryHandler)
	return r
}
