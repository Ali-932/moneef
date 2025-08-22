# Development Guides

This directory contains guides for extending the API boilerplate.

## Quick Start Guide

1. **Create a Model** (`howTo/models/README.md`)
   - Define your data structure with GORM tags
   - Add to database migrations

2. **Create a Repository** (`howTo/repository/README.md`)
   - Implement data access functions
   - Handle database queries and operations

3. **Create a Service** (`howTo/services/README.md`)
   - Implement business logic
   - Call repository functions
   - Handle data processing

4. **Create Request/Response Schemas** (`howTo/schemas/README.md`)
   - Define API contracts
   - Add validation rules

5. **Create a Handler** (`howTo/handlers/README.md`)
   - Handle HTTP requests
   - Validate input and call services
   - Return JSON responses

6. **Create Routes** (`howTo/routes/README.md`)
   - Define API endpoints
   - Apply middleware
   - Mount to main router

7. **Create Middleware** (`howTo/middleware/README.md`) (Optional)
   - Add cross-cutting concerns
   - Authentication, logging, CORS, etc.

## Example Flow

For a "Todo" feature:
1. Model: `internal/models/todo.go`
2. Repository: `internal/repository/todo_repository.go`
3. Service: `internal/services/todo_service.go`
4. Schema: `internal/schemas/todo_request.go`
5. Handler: `internal/handlers/todo_handler.go`
6. Routes: `internal/routes/todo_routes.go`
7. Mount: Add to `internal/routes/routes.go`

## Conventions

- Use singular names for models
- Use descriptive function names
- Follow Go naming conventions
- Handle errors properly
- Use validation tags for input