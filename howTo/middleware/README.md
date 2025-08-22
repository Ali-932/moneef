# How to Create Middleware

## Basic Middleware Structure
```go
package middleware

import (
    "context"
    "net/http"
    "goMangaObserver/pkg/utils"
)

func YourMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Pre-processing
        if !validateSomething(r) {
            utils.WriteJsonError(w, http.StatusBadRequest, "Validation failed")
            return
        }
        
        // Add to context
        ctx := context.WithValue(r.Context(), "key", "value")
        r = r.WithContext(ctx)
        
        // Call next handler
        next.ServeHTTP(w, r)
        
        // Post-processing (optional)
    })
}

func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Log request
        log.Printf("Request: %s %s", r.Method, r.URL.Path)
        
        next.ServeHTTP(w, r)
    })
}

func CORSMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}
```

## Usage in Routes
```go
r.Use(middleware.YourMiddleware)
r.Group(func(r chi.Router) {
    r.Use(middleware.AuthMiddleware)
    // Protected routes
})
```