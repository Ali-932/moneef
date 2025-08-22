# How to Create Routes

## Basic Routes Structure
```go
package routes

import (
    "github.com/go-chi/chi/v5"
    "goMangaObserver/internal/handlers"
    "goMangaObserver/pkg/middleware"
)

func YourRoutes() chi.Router {
    r := chi.NewRouter()
    
    // Public routes
    r.Post("/create", handlers.CreateYourHandler)
    r.Get("/public/{id}", handlers.GetPublicYourHandler)
    
    // Protected routes
    r.Group(func(r chi.Router) {
        r.Use(middleware.AuthMiddleware)
        r.Get("/protected", handlers.GetProtectedYourHandler)
        r.Put("/update/{id}", handlers.UpdateYourHandler)
        r.Delete("/delete/{id}", handlers.DeleteYourHandler)
    })
    
    return r
}
```

## Mounting Routes
Add to `internal/routes/routes.go`:
```go
r.Mount("/api/v1/your-endpoint", YourRoutes())
```

## Route Patterns
- Group related endpoints
- Apply middleware to groups
- Use RESTful conventions
- Protect sensitive endpoints