# How to Create Utils

## Basic Utility Functions
```go
package utils

import (
    "encoding/json"
    "net/http"
    "strings"
    "unicode"
)

// JSON response utilities
func WriteJsonSuccess(w http.ResponseWriter, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(data)
}

func WriteJsonError(w http.ResponseWriter, statusCode int, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(statusCode)
    json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func WriteJsonResponse(w http.ResponseWriter, statusCode int, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(statusCode)
    json.NewEncoder(w).Encode(data)
}

// String utilities
func NormalizeString(s string) string {
    return strings.ToLower(strings.TrimSpace(s))
}

func IsEmpty(s string) bool {
    return strings.TrimSpace(s) == ""
}

func ToSnakeCase(s string) string {
    var result strings.Builder
    for i, r := range s {
        if unicode.IsUpper(r) && i > 0 {
            result.WriteRune('_')
        }
        result.WriteRune(unicode.ToLower(r))
    }
    return result.String()
}

// Validation utilities
func IsValidEmail(email string) bool {
    return strings.Contains(email, "@") && strings.Contains(email, ".")
}

func IsNumeric(s string) bool {
    for _, r := range s {
        if !unicode.IsDigit(r) {
            return false
        }
    }
    return len(s) > 0
}

// Pagination utilities
func CalculateOffset(page, limit int) int {
    if page < 1 {
        page = 1
    }
    return (page - 1) * limit
}

func CalculateTotalPages(total, limit int) int {
    if limit <= 0 {
        return 0
    }
    return (total + limit - 1) / limit
}
```

## Utility Categories
- JSON response helpers
- String manipulation
- Validation helpers
- Pagination utilities
- Date/time utilities
- File operations
- Cryptographic functions