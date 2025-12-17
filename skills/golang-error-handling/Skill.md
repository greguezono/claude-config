---
name: golang-error-handling
description: Go error handling patterns including error wrapping, sentinel errors, custom error types, errors.Is/As, and structured error information. Covers error design, recovery patterns, and error handling in APIs and services. Use when designing error strategies, wrapping errors for context, implementing custom errors, or debugging error chains.
---

# Golang Error Handling Skill

## Overview

The Go Error Handling skill provides comprehensive expertise for designing and implementing robust error handling in Go applications. It covers error wrapping, sentinel errors, custom error types, and the errors package for error inspection.

This skill consolidates error handling patterns from production Go services, emphasizing clear error messages, proper error wrapping for debugging, and API-friendly error responses. It covers both the technical aspects of Go's error system and the design decisions around error strategies.

Whether designing error types for a new package, implementing error handling in services, or debugging production issues with error chains, this skill provides the patterns for effective Go error handling.

## When to Use

Use this skill when you need to:

- Design error handling strategy for a package or service
- Wrap errors with context while preserving the chain
- Create sentinel errors or custom error types
- Use errors.Is and errors.As for error inspection
- Implement structured error responses in APIs
- Handle errors in concurrent code
- Debug issues using error chains

## Core Capabilities

### 1. Error Wrapping

Wrap errors with context using fmt.Errorf and %w, building useful error chains for debugging while preserving the ability to inspect underlying errors.

See [error-wrapping.md](error-wrapping.md) for wrapping patterns.

### 2. Custom Error Types

Design custom error types that carry structured information, implement the error interface, and work with errors.Is/As.

See [custom-errors.md](custom-errors.md) for type design.

### 3. Sentinel Errors

Create and use sentinel errors for expected error conditions that callers need to handle specifically.

See [sentinel-errors.md](sentinel-errors.md) for sentinel patterns.

### 4. API Error Responses

Design error responses for REST APIs and gRPC services, mapping internal errors to appropriate responses.

See [api-errors.md](api-errors.md) for API error patterns.

## Quick Start Workflows

### Basic Error Wrapping

```go
import (
    "errors"
    "fmt"
)

func loadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        // Wrap with context, preserve original error
        return nil, fmt.Errorf("failed to read config file %s: %w", path, err)
    }

    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, fmt.Errorf("failed to parse config: %w", err)
    }

    if err := cfg.Validate(); err != nil {
        return nil, fmt.Errorf("invalid config: %w", err)
    }

    return &cfg, nil
}

// Caller can inspect error chain
func main() {
    cfg, err := loadConfig("config.json")
    if err != nil {
        if errors.Is(err, os.ErrNotExist) {
            log.Fatal("Config file not found, please create one")
        }
        log.Fatalf("Failed to load config: %v", err)
    }
}
```

### Sentinel Errors

```go
package user

import "errors"

// Sentinel errors for expected conditions
var (
    ErrNotFound      = errors.New("user not found")
    ErrAlreadyExists = errors.New("user already exists")
    ErrInvalidEmail  = errors.New("invalid email format")
)

func (s *Service) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("failed to get user %s: %w", id, err)
    }
    return user, nil
}

// Caller handles sentinel errors specifically
func handler(w http.ResponseWriter, r *http.Request) {
    user, err := userService.GetUser(id)
    if err != nil {
        switch {
        case errors.Is(err, user.ErrNotFound):
            http.Error(w, "User not found", http.StatusNotFound)
        default:
            log.Printf("Error getting user: %v", err)
            http.Error(w, "Internal error", http.StatusInternalServerError)
        }
        return
    }
    json.NewEncoder(w).Encode(user)
}
```

### Custom Error Types

```go
// ValidationError carries field-specific validation failures
type ValidationError struct {
    Field   string
    Message string
    Value   interface{}
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for %s: %s", e.Field, e.Message)
}

// Implement Is for errors.Is comparison
func (e *ValidationError) Is(target error) bool {
    _, ok := target.(*ValidationError)
    return ok
}

// Use the custom error
func validateUser(u *User) error {
    if u.Email == "" {
        return &ValidationError{
            Field:   "email",
            Message: "email is required",
        }
    }
    if !isValidEmail(u.Email) {
        return &ValidationError{
            Field:   "email",
            Message: "invalid email format",
            Value:   u.Email,
        }
    }
    return nil
}

// Caller uses errors.As to extract type
func handler(u *User) error {
    if err := validateUser(u); err != nil {
        var validationErr *ValidationError
        if errors.As(err, &validationErr) {
            return fmt.Errorf("bad request: field %s: %s",
                validationErr.Field, validationErr.Message)
        }
        return err
    }
    return nil
}
```

### Multiple Errors with errors.Join

```go
func validateOrder(o *Order) error {
    var errs []error

    if o.CustomerID == "" {
        errs = append(errs, errors.New("customer_id is required"))
    }
    if len(o.Items) == 0 {
        errs = append(errs, errors.New("order must have at least one item"))
    }
    if o.Total <= 0 {
        errs = append(errs, fmt.Errorf("invalid total: %v", o.Total))
    }

    return errors.Join(errs...) // Returns nil if errs is empty
}

// Or use a multi-error type for richer information
type MultiError struct {
    Errors []error
}

func (m *MultiError) Error() string {
    if len(m.Errors) == 1 {
        return m.Errors[0].Error()
    }
    var b strings.Builder
    b.WriteString(fmt.Sprintf("%d errors occurred:\n", len(m.Errors)))
    for _, err := range m.Errors {
        b.WriteString("  - ")
        b.WriteString(err.Error())
        b.WriteString("\n")
    }
    return b.String()
}
```

## Core Principles

### 1. Wrap Errors at Package Boundaries

Add context when errors cross package boundaries. The context should help answer "what operation failed?" without duplicating the underlying error's message.

```go
// Good: Adds context about the operation
return nil, fmt.Errorf("failed to create order: %w", err)

// Bad: Redundant context
return nil, fmt.Errorf("error: %w", err)

// Bad: Loses error chain (no %w)
return nil, fmt.Errorf("failed to create order: %v", err)
```

### 2. Use Sentinel Errors for Expected Conditions

Create sentinel errors for conditions callers should handle specifically (not found, already exists, invalid input). Document them as part of the package API.

```go
// Package exports sentinel errors
var ErrNotFound = errors.New("resource not found")

// Document in function comments
// GetUser retrieves a user by ID.
// Returns ErrNotFound if the user doesn't exist.
func (s *Service) GetUser(id string) (*User, error)
```

### 3. Errors.Is for Sentinel, Errors.As for Types

Use `errors.Is` to check for specific error values. Use `errors.As` to extract error types. Both work through wrapped error chains.

```go
// errors.Is: Check for specific error
if errors.Is(err, sql.ErrNoRows) { }
if errors.Is(err, context.DeadlineExceeded) { }

// errors.As: Extract error type
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    fmt.Printf("Operation %s failed on %s", pathErr.Op, pathErr.Path)
}
```

### 4. Don't Log and Return

Either log the error or return it—not both. Logging at every level creates duplicate log entries and noise.

```go
// Bad: Log and return
if err != nil {
    log.Printf("Failed to process: %v", err)
    return err  // Caller will also log
}

// Good: Return with context, let caller decide
if err != nil {
    return fmt.Errorf("failed to process item %s: %w", id, err)
}
```

### 5. Handle Errors Once

Once you've handled an error (logged it, returned a response, etc.), don't propagate it further. Return nil or a new error if needed.

```go
// Good: Handle once at API boundary
func handler(w http.ResponseWriter, r *http.Request) {
    result, err := service.DoThing()
    if err != nil {
        log.Printf("DoThing failed: %v", err)  // Log once
        http.Error(w, "Internal error", 500)    // Respond
        return                                   // Done
    }
    json.NewEncoder(w).Encode(result)
}
```

## API Error Pattern

```go
// API error response structure
type APIError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Details any    `json:"details,omitempty"`
}

// Map internal errors to API errors
func toAPIError(err error) (int, *APIError) {
    switch {
    case errors.Is(err, ErrNotFound):
        return http.StatusNotFound, &APIError{
            Code:    "NOT_FOUND",
            Message: "The requested resource was not found",
        }
    case errors.Is(err, ErrUnauthorized):
        return http.StatusUnauthorized, &APIError{
            Code:    "UNAUTHORIZED",
            Message: "Authentication required",
        }
    default:
        var validationErr *ValidationError
        if errors.As(err, &validationErr) {
            return http.StatusBadRequest, &APIError{
                Code:    "VALIDATION_ERROR",
                Message: validationErr.Message,
                Details: map[string]string{"field": validationErr.Field},
            }
        }
        // Internal errors: log details, return generic message
        log.Printf("Internal error: %v", err)
        return http.StatusInternalServerError, &APIError{
            Code:    "INTERNAL_ERROR",
            Message: "An unexpected error occurred",
        }
    }
}
```

## Resource References

- **[references.md](references.md)**: errors package reference, interface details
- **[examples.md](examples.md)**: Complete error handling examples
- **Sub-skill files**: error-wrapping.md, custom-errors.md, sentinel-errors.md, api-errors.md
- **[templates/](templates/)**: Error type templates, API error templates

## Success Criteria

Go error handling is effective when:

- Error chains preserve context for debugging
- Sentinel errors are used for expected conditions
- Custom error types carry structured information
- Errors are handled once (no duplicate logging)
- API errors don't leak internal details
- errors.Is/As work correctly through the chain
- Error messages are actionable and clear

## Next Steps

1. Study [error-wrapping.md](error-wrapping.md) for context patterns
2. Learn [custom-errors.md](custom-errors.md) for type design
3. Review [sentinel-errors.md](sentinel-errors.md) for error values
4. Implement [api-errors.md](api-errors.md) for services

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
