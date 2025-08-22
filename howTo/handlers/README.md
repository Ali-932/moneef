# How to Create Handlers

## Basic Handler Structure
```go
package handlers

import (
    "encoding/json"
    "github.com/go-playground/validator/v10"
    "goMangaObserver/internal/services"
    "goMangaObserver/pkg/utils"
    "net/http"
)

type YourRequest struct {
    Name  string `json:"name" validate:"required"`
    Email string `json:"email" validate:"required,email"`
}

func YourHandler(w http.ResponseWriter, r *http.Request) {
    var req YourRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
        return
    }
    
    validate := validator.New()
    if err := validate.Struct(req); err != nil {
        utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
        return
    }
    
    result, err := services.YourService(req.Name, req.Email)
    if err != nil {
        utils.WriteJsonError(w, http.StatusInternalServerError, err.Error())
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}
```

## Validation Tags
- `validate:"required"` - Required field
- `validate:"email"` - Email format
- `validate:"min=3,max=50"` - Length constraints
- `validate:"numeric"` - Numeric only
- `validate:"alpha"` - Alphabetic only