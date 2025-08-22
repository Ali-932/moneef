# How to Create Schemas

## Request/Response Schemas
```go
package schemas

import "time"

type YourRequest struct {
    Name        string    `json:"name" validate:"required"`
    Email       string    `json:"email" validate:"required,email"`
    Age         int       `json:"age" validate:"min=0,max=150"`
    IsActive    bool      `json:"is_active"`
    Tags        []string  `json:"tags"`
    Metadata    map[string]interface{} `json:"metadata"`
}

type YourResponse struct {
    ID          uint      `json:"id"`
    Name        string    `json:"name"`
    Email       string    `json:"email"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
}

type ListYourResponse struct {
    Data       []YourResponse `json:"data"`
    Total      int            `json:"total"`
    Page       int            `json:"page"`
    PerPage    int            `json:"per_page"`
    TotalPages int            `json:"total_pages"`
}

type ErrorResponse struct {
    Error   string `json:"error"`
    Code    int    `json:"code"`
    Message string `json:"message"`
}
```

## Schema Patterns
- Separate request/response structs
- Use validation tags
- Include pagination for lists
- Consistent error responses