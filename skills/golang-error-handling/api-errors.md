# API Errors Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Best Practices](#best-practices)
5. [Common Pitfalls](#common-pitfalls)
6. [Advanced Patterns](#advanced-patterns)
7. [Examples](#examples)
8. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for designing and implementing error responses in Go APIs. It covers HTTP REST error formatting, gRPC status codes, error serialization, mapping internal errors to appropriate API responses, and handling errors at service boundaries while protecting sensitive information.

**Key Capabilities:**
- Design consistent API error response formats
- Map internal errors to HTTP status codes
- Implement gRPC error handling with status codes
- Serialize errors to JSON/Protocol Buffers
- Protect sensitive internal details from API responses
- Create middleware for centralized error handling
- Implement problem details (RFC 7807/9457)
- Build error documentation for API consumers

---

## When to Use

Use API error patterns when:
- **REST API Development**: Building HTTP-based APIs that need consistent error responses
- **gRPC Services**: Implementing gRPC services with proper status codes and details
- **Error Translation**: Converting internal errors to client-appropriate responses
- **Error Serialization**: Formatting errors for JSON, XML, or other wire formats
- **Security Boundaries**: Ensuring internal errors don't leak to external clients
- **API Documentation**: Providing predictable error contracts for consumers

**Concrete Scenarios:**
- Return 404 Not Found with structured JSON when resource doesn't exist
- Map database constraint violations to 409 Conflict
- Return 429 Too Many Requests with retry-after header
- Convert validation errors to 400 Bad Request with field details
- Handle gRPC deadline exceeded with appropriate status code
- Log detailed error context while returning sanitized client response

---

## Core Concepts

### 1. HTTP Status Code Categories

HTTP status codes communicate error types to clients:

**4xx Client Errors:**
```go
// Client made a mistake - they should fix their request
http.StatusBadRequest          // 400 - Invalid request syntax/parameters
http.StatusUnauthorized        // 401 - Authentication required
http.StatusForbidden           // 403 - Authenticated but not authorized
http.StatusNotFound            // 404 - Resource doesn't exist
http.StatusMethodNotAllowed    // 405 - HTTP method not supported
http.StatusConflict            // 409 - Resource state conflict
http.StatusGone                // 410 - Resource permanently removed
http.StatusUnprocessableEntity // 422 - Semantic errors in request
http.StatusTooManyRequests     // 429 - Rate limit exceeded
```

**5xx Server Errors:**
```go
// Server had a problem - client may retry
http.StatusInternalServerError // 500 - Unexpected server error
http.StatusNotImplemented      // 501 - Feature not implemented
http.StatusBadGateway          // 502 - Upstream service error
http.StatusServiceUnavailable  // 503 - Service temporarily down
http.StatusGatewayTimeout      // 504 - Upstream timeout
```

### 2. Standard Error Response Format

Define a consistent error response structure:

```go
// APIError is the standard error response format
type APIError struct {
    // HTTP status code
    Status int `json:"-"`

    // Machine-readable error code
    Code string `json:"code"`

    // Human-readable message
    Message string `json:"message"`

    // Unique request identifier for support
    RequestID string `json:"request_id,omitempty"`

    // Additional error details
    Details map[string]interface{} `json:"details,omitempty"`

    // Timestamp of the error
    Timestamp time.Time `json:"timestamp,omitempty"`

    // Documentation link
    DocURL string `json:"doc_url,omitempty"`
}

// JSON output:
// {
//   "code": "VALIDATION_ERROR",
//   "message": "Request validation failed",
//   "request_id": "req_123abc",
//   "details": {
//     "email": "invalid email format",
//     "age": "must be positive"
//   },
//   "timestamp": "2025-01-15T10:30:00Z"
// }
```

### 3. Error Code Design

Design machine-readable error codes:

```go
// Error codes as constants
const (
    // General errors
    ErrCodeInternal         = "INTERNAL_ERROR"
    ErrCodeInvalidRequest   = "INVALID_REQUEST"
    ErrCodeValidation       = "VALIDATION_ERROR"

    // Authentication/Authorization
    ErrCodeUnauthorized     = "UNAUTHORIZED"
    ErrCodeForbidden        = "FORBIDDEN"
    ErrCodeTokenExpired     = "TOKEN_EXPIRED"
    ErrCodeInvalidToken     = "INVALID_TOKEN"

    // Resource errors
    ErrCodeNotFound         = "NOT_FOUND"
    ErrCodeAlreadyExists    = "ALREADY_EXISTS"
    ErrCodeConflict         = "CONFLICT"
    ErrCodeGone             = "GONE"

    // Rate limiting
    ErrCodeRateLimited      = "RATE_LIMITED"
    ErrCodeQuotaExceeded    = "QUOTA_EXCEEDED"

    // External service errors
    ErrCodeUpstreamError    = "UPSTREAM_ERROR"
    ErrCodeTimeout          = "TIMEOUT"
)
```

### 4. gRPC Status Codes

gRPC uses a different status code system:

```go
import (
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// gRPC status codes
codes.OK                 // 0  - Success
codes.Canceled           // 1  - Operation canceled
codes.Unknown            // 2  - Unknown error
codes.InvalidArgument    // 3  - Bad request parameters
codes.DeadlineExceeded   // 4  - Timeout
codes.NotFound           // 5  - Resource not found
codes.AlreadyExists      // 6  - Resource already exists
codes.PermissionDenied   // 7  - Not authorized
codes.ResourceExhausted  // 8  - Rate limited/quota exceeded
codes.FailedPrecondition // 9  - Operation rejected due to state
codes.Aborted            // 10 - Conflict/retry needed
codes.OutOfRange         // 11 - Value out of valid range
codes.Unimplemented      // 12 - Not implemented
codes.Internal           // 13 - Internal server error
codes.Unavailable        // 14 - Service unavailable
codes.DataLoss           // 15 - Data loss/corruption
codes.Unauthenticated    // 16 - No valid credentials

// Creating gRPC errors
err := status.Error(codes.NotFound, "user not found")
err := status.Errorf(codes.InvalidArgument, "invalid email: %s", email)

// With details
st := status.New(codes.InvalidArgument, "validation failed")
st, _ = st.WithDetails(&errdetails.BadRequest{
    FieldViolations: []*errdetails.BadRequest_FieldViolation{
        {Field: "email", Description: "invalid format"},
    },
})
err := st.Err()
```

### 5. HTTP to gRPC Status Mapping

Map between HTTP and gRPC status codes:

```go
func HTTPToGRPCCode(httpStatus int) codes.Code {
    switch httpStatus {
    case http.StatusOK:
        return codes.OK
    case http.StatusBadRequest:
        return codes.InvalidArgument
    case http.StatusUnauthorized:
        return codes.Unauthenticated
    case http.StatusForbidden:
        return codes.PermissionDenied
    case http.StatusNotFound:
        return codes.NotFound
    case http.StatusConflict:
        return codes.AlreadyExists
    case http.StatusTooManyRequests:
        return codes.ResourceExhausted
    case http.StatusInternalServerError:
        return codes.Internal
    case http.StatusNotImplemented:
        return codes.Unimplemented
    case http.StatusServiceUnavailable:
        return codes.Unavailable
    case http.StatusGatewayTimeout:
        return codes.DeadlineExceeded
    default:
        return codes.Unknown
    }
}

func GRPCToHTTPStatus(code codes.Code) int {
    switch code {
    case codes.OK:
        return http.StatusOK
    case codes.InvalidArgument:
        return http.StatusBadRequest
    case codes.Unauthenticated:
        return http.StatusUnauthorized
    case codes.PermissionDenied:
        return http.StatusForbidden
    case codes.NotFound:
        return http.StatusNotFound
    case codes.AlreadyExists:
        return http.StatusConflict
    case codes.ResourceExhausted:
        return http.StatusTooManyRequests
    case codes.Unimplemented:
        return http.StatusNotImplemented
    case codes.Internal:
        return http.StatusInternalServerError
    case codes.Unavailable:
        return http.StatusServiceUnavailable
    case codes.DeadlineExceeded:
        return http.StatusGatewayTimeout
    default:
        return http.StatusInternalServerError
    }
}
```

### 6. Problem Details (RFC 9457)

Implement RFC 9457 Problem Details for HTTP APIs:

```go
// ProblemDetails implements RFC 9457
type ProblemDetails struct {
    // A URI reference that identifies the problem type
    Type string `json:"type"`

    // A short summary of the problem type
    Title string `json:"title"`

    // The HTTP status code
    Status int `json:"status"`

    // Human-readable explanation specific to this occurrence
    Detail string `json:"detail,omitempty"`

    // URI reference for the specific occurrence
    Instance string `json:"instance,omitempty"`

    // Extension members for additional context
    Extensions map[string]interface{} `json:"-"`
}

// JSON output with custom marshaling for extensions
func (p ProblemDetails) MarshalJSON() ([]byte, error) {
    type Alias ProblemDetails
    aux := struct {
        Alias
    }{Alias: Alias(p)}

    data, err := json.Marshal(aux)
    if err != nil {
        return nil, err
    }

    if len(p.Extensions) == 0 {
        return data, nil
    }

    // Merge extensions into output
    var m map[string]interface{}
    json.Unmarshal(data, &m)
    for k, v := range p.Extensions {
        m[k] = v
    }

    return json.Marshal(m)
}

// Example response:
// {
//   "type": "https://api.example.com/errors/validation",
//   "title": "Validation Error",
//   "status": 400,
//   "detail": "The request body contains invalid fields",
//   "instance": "/users/123",
//   "invalid_fields": ["email", "phone"]
// }
```

---

## Best Practices

### 1. Never Expose Internal Errors

Keep internal details out of API responses:

```go
// BAD: Exposes internal details
func handleError(w http.ResponseWriter, err error) {
    // Leaks: database schema, file paths, internal logic
    http.Error(w, err.Error(), http.StatusInternalServerError)
}

// GOOD: Log internal, return sanitized
func handleError(w http.ResponseWriter, r *http.Request, err error) {
    requestID := getRequestID(r)

    // Log full details internally
    log.Printf("[%s] internal error: %+v", requestID, err)

    // Return safe response
    response := APIError{
        Status:    http.StatusInternalServerError,
        Code:      ErrCodeInternal,
        Message:   "An unexpected error occurred",
        RequestID: requestID,
    }
    writeJSON(w, response.Status, response)
}
```

### 2. Use Consistent Error Format

All errors should follow the same structure:

```go
// ErrorResponse writes a consistent error response
func ErrorResponse(w http.ResponseWriter, status int, code, message string) {
    response := APIError{
        Status:    status,
        Code:      code,
        Message:   message,
        Timestamp: time.Now().UTC(),
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": response,
    })
}

// All error responses look the same:
// {
//   "error": {
//     "code": "NOT_FOUND",
//     "message": "User not found",
//     "timestamp": "2025-01-15T10:30:00Z"
//   }
// }
```

### 3. Include Request IDs

Add request IDs for debugging and support:

```go
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = generateRequestID()
        }

        // Add to response headers
        w.Header().Set("X-Request-ID", requestID)

        // Store in context
        ctx := context.WithValue(r.Context(), requestIDKey, requestID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func handleError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
    requestID := r.Context().Value(requestIDKey).(string)

    response := APIError{
        Status:    status,
        Code:      code,
        Message:   message,
        RequestID: requestID,
    }

    writeJSON(w, status, map[string]interface{}{"error": response})
}
```

### 4. Provide Actionable Error Messages

Error messages should help clients fix the issue:

```go
// BAD: Vague messages
"Error occurred"
"Invalid input"
"Operation failed"

// GOOD: Actionable messages
"Email address is required"
"Password must be at least 8 characters"
"User with email john@example.com already exists"
"API rate limit exceeded. Retry after 60 seconds."
```

### 5. Map Domain Errors to API Errors

Create a centralized mapping layer:

```go
// ErrorMapper converts domain errors to API errors
type ErrorMapper struct {
    logger *log.Logger
}

func (m *ErrorMapper) ToAPIError(err error, requestID string) APIError {
    // Check domain errors first
    switch {
    case errors.Is(err, user.ErrNotFound):
        return APIError{
            Status:    http.StatusNotFound,
            Code:      ErrCodeNotFound,
            Message:   "User not found",
            RequestID: requestID,
        }

    case errors.Is(err, user.ErrAlreadyExists):
        return APIError{
            Status:    http.StatusConflict,
            Code:      ErrCodeAlreadyExists,
            Message:   "User with this email already exists",
            RequestID: requestID,
        }

    case errors.Is(err, auth.ErrInvalidCredentials):
        return APIError{
            Status:    http.StatusUnauthorized,
            Code:      ErrCodeUnauthorized,
            Message:   "Invalid email or password",
            RequestID: requestID,
        }

    case errors.Is(err, context.DeadlineExceeded):
        return APIError{
            Status:    http.StatusGatewayTimeout,
            Code:      ErrCodeTimeout,
            Message:   "Request timed out",
            RequestID: requestID,
        }
    }

    // Check error types
    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        return APIError{
            Status:    http.StatusBadRequest,
            Code:      ErrCodeValidation,
            Message:   "Validation failed",
            RequestID: requestID,
            Details:   validationErr.Fields(),
        }
    }

    // Default: internal error
    m.logger.Printf("[%s] unmapped error: %v", requestID, err)
    return APIError{
        Status:    http.StatusInternalServerError,
        Code:      ErrCodeInternal,
        Message:   "An unexpected error occurred",
        RequestID: requestID,
    }
}
```

### 6. Add Rate Limit Headers

Include rate limit information in headers:

```go
func handleRateLimitError(w http.ResponseWriter, limit, remaining int, resetTime time.Time) {
    // Standard rate limit headers
    w.Header().Set("X-RateLimit-Limit", strconv.Itoa(limit))
    w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))
    w.Header().Set("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))
    w.Header().Set("Retry-After", strconv.Itoa(int(time.Until(resetTime).Seconds())))

    response := APIError{
        Status:  http.StatusTooManyRequests,
        Code:    ErrCodeRateLimited,
        Message: "Rate limit exceeded",
        Details: map[string]interface{}{
            "limit":      limit,
            "remaining":  remaining,
            "reset_time": resetTime.Unix(),
        },
    }

    writeJSON(w, response.Status, map[string]interface{}{"error": response})
}
```

### 7. Document Error Responses

Include error schemas in API documentation:

```go
// OpenAPI/Swagger annotations
// @Summary Get user by ID
// @Description Retrieves a user by their unique identifier
// @Tags users
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} User
// @Failure 400 {object} APIError "Invalid ID format"
// @Failure 401 {object} APIError "Authentication required"
// @Failure 403 {object} APIError "Insufficient permissions"
// @Failure 404 {object} APIError "User not found"
// @Failure 500 {object} APIError "Internal server error"
// @Router /users/{id} [get]
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    // ...
}
```

### 8. Use Centralized Error Handling

Create middleware for consistent error handling:

```go
// ErrorHandlerMiddleware centralizes error handling
type ErrorHandlerMiddleware struct {
    mapper *ErrorMapper
    logger *log.Logger
}

func (m *ErrorHandlerMiddleware) Wrap(handler func(w http.ResponseWriter, r *http.Request) error) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        err := handler(w, r)
        if err == nil {
            return
        }

        requestID := getRequestID(r)
        apiErr := m.mapper.ToAPIError(err, requestID)

        // Log error
        m.logger.Printf("[%s] %s %s: %v", requestID, r.Method, r.URL.Path, err)

        // Write response
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(apiErr.Status)
        json.NewEncoder(w).Encode(map[string]interface{}{"error": apiErr})
    }
}

// Usage
mux.HandleFunc("/users/{id}", errHandler.Wrap(userHandler.GetUser))
```

---

## Common Pitfalls

### 1. Leaking Stack Traces

**Problem:**
```go
func handleError(w http.ResponseWriter, err error) {
    // Exposes internal code structure
    http.Error(w, fmt.Sprintf("%+v", err), http.StatusInternalServerError)
}
```

**Solution:**
```go
func handleError(w http.ResponseWriter, r *http.Request, err error) {
    requestID := getRequestID(r)

    // Log full trace internally
    log.Printf("[%s] error: %+v", requestID, err)

    // Return safe response
    writeAPIError(w, http.StatusInternalServerError,
        ErrCodeInternal, "An error occurred")
}
```

### 2. Inconsistent Error Formats

**Problem:**
```go
// Endpoint 1
w.Write([]byte(`{"error": "not found"}`))

// Endpoint 2
w.Write([]byte(`{"message": "Not Found", "status": 404}`))

// Endpoint 3
w.Write([]byte(`{"errors": [{"code": "E001"}]}`))
```

**Solution:**
```go
// Single function for all error responses
func writeError(w http.ResponseWriter, status int, code, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": map[string]interface{}{
            "code":    code,
            "message": message,
        },
    })
}
```

### 3. Wrong Status Codes

**Problem:**
```go
// Using 200 for errors
if err != nil {
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": false,
        "error":   err.Error(),
    })
    return  // Status 200!
}

// Using 500 for client errors
if user == nil {
    http.Error(w, "User not found", http.StatusInternalServerError)  // Should be 404
}
```

**Solution:**
```go
// Use appropriate status codes
if err != nil {
    if errors.Is(err, ErrNotFound) {
        writeError(w, http.StatusNotFound, "NOT_FOUND", "User not found")
        return
    }
    if errors.Is(err, ErrValidation) {
        writeError(w, http.StatusBadRequest, "VALIDATION", "Invalid input")
        return
    }
    writeError(w, http.StatusInternalServerError, "INTERNAL", "Server error")
    return
}
```

### 4. Missing Error Documentation

**Problem:**
```go
// No documentation of possible errors
func GetUser(id string) (*User, error)

// Caller has no idea what errors to expect
user, err := service.GetUser(id)
if err != nil {
    // What errors can occur? What status codes?
}
```

**Solution:**
```go
// GetUser retrieves a user by ID.
//
// Errors:
//   - Returns ErrNotFound (404) if user doesn't exist
//   - Returns ErrForbidden (403) if caller lacks permission
//   - Returns ErrInvalidID (400) if ID format is invalid
func GetUser(id string) (*User, error)

// Handler knows exactly what to expect
user, err := service.GetUser(id)
if err != nil {
    switch {
    case errors.Is(err, ErrNotFound):
        writeError(w, http.StatusNotFound, ...)
    case errors.Is(err, ErrForbidden):
        writeError(w, http.StatusForbidden, ...)
    // ...
    }
}
```

### 5. Revealing Authentication Details

**Problem:**
```go
if user == nil {
    writeError(w, 401, "INVALID_EMAIL", "No user found with this email")
}
if !checkPassword(user, password) {
    writeError(w, 401, "INVALID_PASSWORD", "Incorrect password")
}
// Attacker can enumerate valid emails!
```

**Solution:**
```go
// Same error for both cases
if user == nil || !checkPassword(user, password) {
    writeError(w, http.StatusUnauthorized,
        "INVALID_CREDENTIALS", "Invalid email or password")
    return
}
```

### 6. No Request ID Correlation

**Problem:**
```go
// Error with no way to trace
{
    "error": {
        "code": "INTERNAL_ERROR",
        "message": "Something went wrong"
    }
}
// User reports issue - how do you find the logs?
```

**Solution:**
```go
{
    "error": {
        "code": "INTERNAL_ERROR",
        "message": "Something went wrong",
        "request_id": "req_abc123xyz"  // Can correlate with logs
    }
}

// In logs:
// [req_abc123xyz] user_service.go:45: database connection failed: timeout
```

### 7. Ignoring Content Negotiation

**Problem:**
```go
// Always returns JSON even for non-JSON clients
func handleError(w http.ResponseWriter, err error) {
    json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
}
```

**Solution:**
```go
func handleError(w http.ResponseWriter, r *http.Request, apiErr APIError) {
    accept := r.Header.Get("Accept")

    switch {
    case strings.Contains(accept, "application/json"):
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(apiErr)

    case strings.Contains(accept, "application/xml"):
        w.Header().Set("Content-Type", "application/xml")
        xml.NewEncoder(w).Encode(apiErr)

    default:
        // Default to JSON
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(apiErr)
    }
}
```

---

## Advanced Patterns

### 1. Structured API Error Type

Complete API error implementation:

```go
package apierr

import (
    "encoding/json"
    "net/http"
    "time"
)

// Error represents a structured API error
type Error struct {
    // HTTP status code
    Status int `json:"-"`

    // Machine-readable error code
    Code string `json:"code"`

    // Human-readable message
    Message string `json:"message"`

    // Request ID for tracing
    RequestID string `json:"request_id,omitempty"`

    // Detailed field-level errors
    Details []FieldError `json:"details,omitempty"`

    // Retry guidance
    RetryAfter int `json:"retry_after,omitempty"`

    // Documentation URL
    HelpURL string `json:"help_url,omitempty"`

    // Timestamp
    Timestamp time.Time `json:"timestamp"`

    // Internal cause (not serialized)
    cause error
}

type FieldError struct {
    Field   string `json:"field"`
    Code    string `json:"code"`
    Message string `json:"message"`
}

// Error implements the error interface
func (e *Error) Error() string {
    return e.Message
}

// Unwrap returns the underlying cause
func (e *Error) Unwrap() error {
    return e.cause
}

// Write sends the error response
func (e *Error) Write(w http.ResponseWriter) {
    if e.Timestamp.IsZero() {
        e.Timestamp = time.Now().UTC()
    }

    w.Header().Set("Content-Type", "application/json")
    if e.RetryAfter > 0 {
        w.Header().Set("Retry-After", strconv.Itoa(e.RetryAfter))
    }
    w.WriteHeader(e.Status)

    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": e,
    })
}

// WithCause adds internal cause (not exposed to client)
func (e *Error) WithCause(cause error) *Error {
    e.cause = cause
    return e
}

// WithDetails adds field-level errors
func (e *Error) WithDetails(details ...FieldError) *Error {
    e.Details = append(e.Details, details...)
    return e
}

// WithRequestID adds request ID
func (e *Error) WithRequestID(id string) *Error {
    e.RequestID = id
    return e
}

// Common error constructors
func BadRequest(message string) *Error {
    return &Error{
        Status:  http.StatusBadRequest,
        Code:    "BAD_REQUEST",
        Message: message,
    }
}

func NotFound(resource string) *Error {
    return &Error{
        Status:  http.StatusNotFound,
        Code:    "NOT_FOUND",
        Message: resource + " not found",
    }
}

func Unauthorized(message string) *Error {
    if message == "" {
        message = "Authentication required"
    }
    return &Error{
        Status:  http.StatusUnauthorized,
        Code:    "UNAUTHORIZED",
        Message: message,
    }
}

func Forbidden(message string) *Error {
    if message == "" {
        message = "Access denied"
    }
    return &Error{
        Status:  http.StatusForbidden,
        Code:    "FORBIDDEN",
        Message: message,
    }
}

func Conflict(message string) *Error {
    return &Error{
        Status:  http.StatusConflict,
        Code:    "CONFLICT",
        Message: message,
    }
}

func RateLimited(retryAfter int) *Error {
    return &Error{
        Status:     http.StatusTooManyRequests,
        Code:       "RATE_LIMITED",
        Message:    "Too many requests",
        RetryAfter: retryAfter,
    }
}

func Internal(cause error) *Error {
    return &Error{
        Status:  http.StatusInternalServerError,
        Code:    "INTERNAL_ERROR",
        Message: "An unexpected error occurred",
        cause:   cause,
    }
}

func Validation(details ...FieldError) *Error {
    return &Error{
        Status:  http.StatusBadRequest,
        Code:    "VALIDATION_ERROR",
        Message: "Validation failed",
        Details: details,
    }
}
```

### 2. gRPC Error Interceptor

Centralized gRPC error handling:

```go
package middleware

import (
    "context"
    "log"

    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// ErrorInterceptor converts domain errors to gRPC status errors
func ErrorInterceptor(logger *log.Logger) grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context,
        req interface{},
        info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler,
    ) (interface{}, error) {
        resp, err := handler(ctx, req)
        if err == nil {
            return resp, nil
        }

        // Already a gRPC status error
        if _, ok := status.FromError(err); ok {
            return nil, err
        }

        // Map domain errors to gRPC status
        grpcErr := mapToGRPCError(err)

        // Log internal errors
        st, _ := status.FromError(grpcErr)
        if st.Code() == codes.Internal {
            logger.Printf("[%s] internal error: %v", info.FullMethod, err)
        }

        return nil, grpcErr
    }
}

func mapToGRPCError(err error) error {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        return status.Error(codes.NotFound, "resource not found")

    case errors.Is(err, domain.ErrAlreadyExists):
        return status.Error(codes.AlreadyExists, "resource already exists")

    case errors.Is(err, domain.ErrUnauthorized):
        return status.Error(codes.Unauthenticated, "authentication required")

    case errors.Is(err, domain.ErrForbidden):
        return status.Error(codes.PermissionDenied, "permission denied")

    case errors.Is(err, context.DeadlineExceeded):
        return status.Error(codes.DeadlineExceeded, "request timed out")

    case errors.Is(err, context.Canceled):
        return status.Error(codes.Canceled, "request canceled")
    }

    // Check for validation errors
    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        st := status.New(codes.InvalidArgument, "validation failed")
        st, _ = st.WithDetails(&errdetails.BadRequest{
            FieldViolations: validationErr.ToFieldViolations(),
        })
        return st.Err()
    }

    // Default to internal error
    return status.Error(codes.Internal, "internal error")
}
```

### 3. Error Handler Factory

Create handlers with built-in error handling:

```go
package handler

import (
    "encoding/json"
    "net/http"
)

// HandlerFunc is a handler that returns an error
type HandlerFunc func(w http.ResponseWriter, r *http.Request) error

// ErrorHandler wraps handlers with error handling
type ErrorHandler struct {
    mapper  *ErrorMapper
    logger  *log.Logger
}

func NewErrorHandler(mapper *ErrorMapper, logger *log.Logger) *ErrorHandler {
    return &ErrorHandler{mapper: mapper, logger: logger}
}

// Wrap converts an error-returning handler to http.HandlerFunc
func (h *ErrorHandler) Wrap(fn HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        err := fn(w, r)
        if err == nil {
            return
        }

        requestID := getRequestID(r)
        apiErr := h.mapper.ToAPIError(err, requestID)

        // Log errors (with more detail for server errors)
        if apiErr.Status >= 500 {
            h.logger.Printf("[%s] %s %s: %+v",
                requestID, r.Method, r.URL.Path, err)
        } else {
            h.logger.Printf("[%s] %s %s: %v",
                requestID, r.Method, r.URL.Path, err)
        }

        // Write error response
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(apiErr.Status)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "error": apiErr,
        })
    }
}

// Usage
func main() {
    errHandler := NewErrorHandler(mapper, logger)

    mux := http.NewServeMux()
    mux.HandleFunc("/users", errHandler.Wrap(userHandler.ListUsers))
    mux.HandleFunc("/users/{id}", errHandler.Wrap(userHandler.GetUser))
}

// Handler returns error instead of writing it
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) error {
    userID := chi.URLParam(r, "id")

    user, err := h.service.GetUser(r.Context(), userID)
    if err != nil {
        return err  // Error handler deals with it
    }

    return json.NewEncoder(w).Encode(user)
}
```

### 4. Validation Error Builder

Build detailed validation errors:

```go
package validation

import (
    "net/http"
)

type ValidationError struct {
    fields []FieldError
}

type FieldError struct {
    Field   string `json:"field"`
    Code    string `json:"code"`
    Message string `json:"message"`
    Value   interface{} `json:"-"`
}

func New() *ValidationError {
    return &ValidationError{}
}

func (v *ValidationError) Add(field, code, message string) *ValidationError {
    v.fields = append(v.fields, FieldError{
        Field:   field,
        Code:    code,
        Message: message,
    })
    return v
}

func (v *ValidationError) AddWithValue(field, code, message string, value interface{}) *ValidationError {
    v.fields = append(v.fields, FieldError{
        Field:   field,
        Code:    code,
        Message: message,
        Value:   value,
    })
    return v
}

func (v *ValidationError) Required(field string) *ValidationError {
    return v.Add(field, "required", field+" is required")
}

func (v *ValidationError) Invalid(field, message string) *ValidationError {
    return v.Add(field, "invalid", message)
}

func (v *ValidationError) MinLength(field string, min int) *ValidationError {
    return v.Add(field, "min_length",
        fmt.Sprintf("%s must be at least %d characters", field, min))
}

func (v *ValidationError) MaxLength(field string, max int) *ValidationError {
    return v.Add(field, "max_length",
        fmt.Sprintf("%s must be at most %d characters", field, max))
}

func (v *ValidationError) HasErrors() bool {
    return len(v.fields) > 0
}

func (v *ValidationError) Error() string {
    if len(v.fields) == 0 {
        return "validation failed"
    }
    return fmt.Sprintf("validation failed: %d errors", len(v.fields))
}

func (v *ValidationError) Fields() []FieldError {
    return v.fields
}

func (v *ValidationError) ToAPIError() *apierr.Error {
    return apierr.Validation(v.fields...)
}

// Err returns nil if no errors, otherwise the ValidationError
func (v *ValidationError) Err() error {
    if v.HasErrors() {
        return v
    }
    return nil
}

// Usage
func validateCreateUser(req CreateUserRequest) error {
    v := validation.New()

    if req.Email == "" {
        v.Required("email")
    } else if !isValidEmail(req.Email) {
        v.Invalid("email", "invalid email format")
    }

    if req.Password == "" {
        v.Required("password")
    } else if len(req.Password) < 8 {
        v.MinLength("password", 8)
    }

    if req.Name == "" {
        v.Required("name")
    }

    return v.Err()
}
```

### 5. Error Middleware Chain

Build composable error handling:

```go
package middleware

// ErrorMiddleware processes errors before they're written
type ErrorMiddleware func(next ErrorHandler) ErrorHandler

// ErrorHandler handles errors from handlers
type ErrorHandler func(error, http.ResponseWriter, *http.Request)

// Chain combines multiple error middlewares
func Chain(middlewares ...ErrorMiddleware) ErrorMiddleware {
    return func(final ErrorHandler) ErrorHandler {
        for i := len(middlewares) - 1; i >= 0; i-- {
            final = middlewares[i](final)
        }
        return final
    }
}

// LoggingMiddleware logs errors
func LoggingMiddleware(logger *log.Logger) ErrorMiddleware {
    return func(next ErrorHandler) ErrorHandler {
        return func(err error, w http.ResponseWriter, r *http.Request) {
            requestID := getRequestID(r)
            logger.Printf("[%s] %s %s: %v",
                requestID, r.Method, r.URL.Path, err)
            next(err, w, r)
        }
    }
}

// MetricsMiddleware records error metrics
func MetricsMiddleware(metrics *Metrics) ErrorMiddleware {
    return func(next ErrorHandler) ErrorHandler {
        return func(err error, w http.ResponseWriter, r *http.Request) {
            // Record error type
            var apiErr *apierr.Error
            if errors.As(err, &apiErr) {
                metrics.RecordError(apiErr.Code, apiErr.Status)
            } else {
                metrics.RecordError("unknown", 500)
            }
            next(err, w, r)
        }
    }
}

// RecoveryMiddleware handles panics
func RecoveryMiddleware(logger *log.Logger) ErrorMiddleware {
    return func(next ErrorHandler) ErrorHandler {
        return func(err error, w http.ResponseWriter, r *http.Request) {
            defer func() {
                if rec := recover(); rec != nil {
                    logger.Printf("panic recovered: %v", rec)
                    next(apierr.Internal(fmt.Errorf("panic: %v", rec)), w, r)
                }
            }()
            next(err, w, r)
        }
    }
}

// WriteResponse is the final handler that writes the error
func WriteResponse(err error, w http.ResponseWriter, r *http.Request) {
    var apiErr *apierr.Error
    if !errors.As(err, &apiErr) {
        apiErr = apierr.Internal(err)
    }

    apiErr.RequestID = getRequestID(r)
    apiErr.Write(w)
}

// Usage
errorHandler := Chain(
    RecoveryMiddleware(logger),
    LoggingMiddleware(logger),
    MetricsMiddleware(metrics),
)(WriteResponse)
```

---

## Examples

### Example 1: Complete REST API Error Handling

```go
package main

import (
    "encoding/json"
    "errors"
    "log"
    "net/http"
    "time"

    "github.com/go-chi/chi/v5"
)

// API Error types
type APIError struct {
    Status    int                    `json:"-"`
    Code      string                 `json:"code"`
    Message   string                 `json:"message"`
    RequestID string                 `json:"request_id,omitempty"`
    Details   map[string]interface{} `json:"details,omitempty"`
    Timestamp time.Time              `json:"timestamp"`
}

func (e *APIError) Write(w http.ResponseWriter, requestID string) {
    e.RequestID = requestID
    e.Timestamp = time.Now().UTC()

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(e.Status)
    json.NewEncoder(w).Encode(map[string]interface{}{"error": e})
}

// Domain errors
var (
    ErrUserNotFound = errors.New("user not found")
    ErrUserExists   = errors.New("user already exists")
    ErrInvalidInput = errors.New("invalid input")
)

// Error mapper
func mapError(err error) *APIError {
    switch {
    case errors.Is(err, ErrUserNotFound):
        return &APIError{
            Status:  http.StatusNotFound,
            Code:    "USER_NOT_FOUND",
            Message: "The requested user was not found",
        }
    case errors.Is(err, ErrUserExists):
        return &APIError{
            Status:  http.StatusConflict,
            Code:    "USER_EXISTS",
            Message: "A user with this email already exists",
        }
    case errors.Is(err, ErrInvalidInput):
        return &APIError{
            Status:  http.StatusBadRequest,
            Code:    "INVALID_INPUT",
            Message: "The request contains invalid data",
        }
    default:
        return &APIError{
            Status:  http.StatusInternalServerError,
            Code:    "INTERNAL_ERROR",
            Message: "An unexpected error occurred",
        }
    }
}

// Middleware
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = generateID()
        }
        w.Header().Set("X-Request-ID", requestID)
        ctx := context.WithValue(r.Context(), "request_id", requestID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func getRequestID(r *http.Request) string {
    if id, ok := r.Context().Value("request_id").(string); ok {
        return id
    }
    return ""
}

// Handler wrapper
type HandlerFunc func(w http.ResponseWriter, r *http.Request) error

func Wrap(fn HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        err := fn(w, r)
        if err == nil {
            return
        }

        requestID := getRequestID(r)
        apiErr := mapError(err)

        // Log internal errors
        if apiErr.Status >= 500 {
            log.Printf("[%s] internal error: %+v", requestID, err)
        }

        apiErr.Write(w, requestID)
    }
}

// Handlers
type UserHandler struct {
    service *UserService
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) error {
    userID := chi.URLParam(r, "id")

    user, err := h.service.GetUser(r.Context(), userID)
    if err != nil {
        return err
    }

    w.Header().Set("Content-Type", "application/json")
    return json.NewEncoder(w).Encode(user)
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) error {
    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        return ErrInvalidInput
    }

    user, err := h.service.CreateUser(r.Context(), req)
    if err != nil {
        return err
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    return json.NewEncoder(w).Encode(user)
}

// Main
func main() {
    r := chi.NewRouter()
    r.Use(RequestIDMiddleware)

    userHandler := &UserHandler{service: NewUserService()}

    r.Get("/users/{id}", Wrap(userHandler.GetUser))
    r.Post("/users", Wrap(userHandler.CreateUser))

    log.Println("Server starting on :8080")
    http.ListenAndServe(":8080", r)
}
```

### Example 2: gRPC Service Error Handling

```go
package main

import (
    "context"
    "errors"

    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/genproto/googleapis/rpc/errdetails"

    pb "myapp/proto/user"
)

// Domain errors
var (
    ErrNotFound     = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrInvalidInput = errors.New("invalid input")
)

// UserServer implements the gRPC service
type UserServer struct {
    pb.UnimplementedUserServiceServer
    service *UserService
}

func (s *UserServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    if req.Id == "" {
        return nil, status.Error(codes.InvalidArgument, "id is required")
    }

    user, err := s.service.GetUser(ctx, req.Id)
    if err != nil {
        return nil, toGRPCError(err)
    }

    return userToProto(user), nil
}

func (s *UserServer) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.User, error) {
    // Validate request
    if violations := validateCreateUser(req); len(violations) > 0 {
        st := status.New(codes.InvalidArgument, "validation failed")
        st, _ = st.WithDetails(&errdetails.BadRequest{
            FieldViolations: violations,
        })
        return nil, st.Err()
    }

    user, err := s.service.CreateUser(ctx, protoToCreateRequest(req))
    if err != nil {
        return nil, toGRPCError(err)
    }

    return userToProto(user), nil
}

func validateCreateUser(req *pb.CreateUserRequest) []*errdetails.BadRequest_FieldViolation {
    var violations []*errdetails.BadRequest_FieldViolation

    if req.Email == "" {
        violations = append(violations, &errdetails.BadRequest_FieldViolation{
            Field:       "email",
            Description: "email is required",
        })
    }

    if req.Name == "" {
        violations = append(violations, &errdetails.BadRequest_FieldViolation{
            Field:       "name",
            Description: "name is required",
        })
    }

    return violations
}

func toGRPCError(err error) error {
    switch {
    case errors.Is(err, ErrNotFound):
        return status.Error(codes.NotFound, "resource not found")
    case errors.Is(err, ErrAlreadyExists):
        return status.Error(codes.AlreadyExists, "resource already exists")
    case errors.Is(err, context.DeadlineExceeded):
        return status.Error(codes.DeadlineExceeded, "request timed out")
    case errors.Is(err, context.Canceled):
        return status.Error(codes.Canceled, "request canceled")
    default:
        // Log internal error, return generic message
        log.Printf("internal error: %v", err)
        return status.Error(codes.Internal, "internal error")
    }
}

// Error interceptor for all RPCs
func ErrorInterceptor() grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context,
        req interface{},
        info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler,
    ) (interface{}, error) {
        resp, err := handler(ctx, req)
        if err != nil {
            // Already a gRPC status
            if _, ok := status.FromError(err); ok {
                return nil, err
            }
            // Convert other errors
            return nil, toGRPCError(err)
        }
        return resp, nil
    }
}

func main() {
    server := grpc.NewServer(
        grpc.UnaryInterceptor(ErrorInterceptor()),
    )

    pb.RegisterUserServiceServer(server, &UserServer{
        service: NewUserService(),
    })

    lis, _ := net.Listen("tcp", ":50051")
    server.Serve(lis)
}
```

### Example 3: Validation with Detailed Errors

```go
package validation

import (
    "encoding/json"
    "net/http"
    "regexp"
)

type ValidationResult struct {
    errors []FieldError
}

type FieldError struct {
    Field   string `json:"field"`
    Code    string `json:"code"`
    Message string `json:"message"`
}

func (r *ValidationResult) AddError(field, code, message string) {
    r.errors = append(r.errors, FieldError{
        Field:   field,
        Code:    code,
        Message: message,
    })
}

func (r *ValidationResult) HasErrors() bool {
    return len(r.errors) > 0
}

func (r *ValidationResult) WriteResponse(w http.ResponseWriter, requestID string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusBadRequest)

    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": map[string]interface{}{
            "code":       "VALIDATION_ERROR",
            "message":    "Request validation failed",
            "request_id": requestID,
            "details":    r.errors,
        },
    })
}

// Validator with fluent API
type Validator struct {
    result *ValidationResult
}

func NewValidator() *Validator {
    return &Validator{result: &ValidationResult{}}
}

func (v *Validator) Required(field string, value string) *Validator {
    if value == "" {
        v.result.AddError(field, "required", field+" is required")
    }
    return v
}

func (v *Validator) Email(field string, value string) *Validator {
    if value == "" {
        return v
    }
    emailRegex := regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
    if !emailRegex.MatchString(value) {
        v.result.AddError(field, "invalid_email", "invalid email format")
    }
    return v
}

func (v *Validator) MinLength(field string, value string, min int) *Validator {
    if len(value) < min {
        v.result.AddError(field, "min_length",
            fmt.Sprintf("%s must be at least %d characters", field, min))
    }
    return v
}

func (v *Validator) MaxLength(field string, value string, max int) *Validator {
    if len(value) > max {
        v.result.AddError(field, "max_length",
            fmt.Sprintf("%s must be at most %d characters", field, max))
    }
    return v
}

func (v *Validator) Range(field string, value int, min, max int) *Validator {
    if value < min || value > max {
        v.result.AddError(field, "out_of_range",
            fmt.Sprintf("%s must be between %d and %d", field, min, max))
    }
    return v
}

func (v *Validator) Result() *ValidationResult {
    return v.result
}

// Usage in handler
func handleCreateUser(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    json.NewDecoder(r.Body).Decode(&req)

    validation := NewValidator().
        Required("email", req.Email).
        Email("email", req.Email).
        Required("password", req.Password).
        MinLength("password", req.Password, 8).
        Required("name", req.Name).
        MaxLength("name", req.Name, 100).
        Range("age", req.Age, 13, 120).
        Result()

    if validation.HasErrors() {
        validation.WriteResponse(w, getRequestID(r))
        return
    }

    // Continue with valid request...
}

// Example error response:
// {
//   "error": {
//     "code": "VALIDATION_ERROR",
//     "message": "Request validation failed",
//     "request_id": "req_abc123",
//     "details": [
//       {"field": "email", "code": "invalid_email", "message": "invalid email format"},
//       {"field": "password", "code": "min_length", "message": "password must be at least 8 characters"},
//       {"field": "age", "code": "out_of_range", "message": "age must be between 13 and 120"}
//     ]
//   }
// }
```

---

## Quick Reference

### HTTP Status Codes

```go
// Client errors (4xx)
http.StatusBadRequest           // 400
http.StatusUnauthorized         // 401
http.StatusForbidden            // 403
http.StatusNotFound             // 404
http.StatusMethodNotAllowed     // 405
http.StatusConflict             // 409
http.StatusUnprocessableEntity  // 422
http.StatusTooManyRequests      // 429

// Server errors (5xx)
http.StatusInternalServerError  // 500
http.StatusBadGateway           // 502
http.StatusServiceUnavailable   // 503
http.StatusGatewayTimeout       // 504
```

### gRPC Status Codes

```go
import "google.golang.org/grpc/codes"

codes.InvalidArgument    // Bad request
codes.Unauthenticated    // No auth
codes.PermissionDenied   // Forbidden
codes.NotFound           // Not found
codes.AlreadyExists      // Conflict
codes.ResourceExhausted  // Rate limited
codes.Internal           // Server error
codes.Unavailable        // Service down
codes.DeadlineExceeded   // Timeout
```

### Standard Error Response

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "request_id": "req_abc123",
    "details": {},
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

### Common Error Mappings

```go
// Domain error -> HTTP status
errors.Is(err, ErrNotFound)      -> 404
errors.Is(err, ErrAlreadyExists) -> 409
errors.Is(err, ErrUnauthorized)  -> 401
errors.Is(err, ErrForbidden)     -> 403
errors.Is(err, ErrValidation)    -> 400
errors.Is(err, ErrRateLimit)     -> 429
context.DeadlineExceeded         -> 504
default                          -> 500
```

### Write Error Response

```go
func writeError(w http.ResponseWriter, status int, code, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": map[string]interface{}{
            "code":    code,
            "message": message,
        },
    })
}
```

### gRPC Error Creation

```go
import (
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// Simple error
err := status.Error(codes.NotFound, "user not found")

// With details
st := status.New(codes.InvalidArgument, "validation failed")
st, _ = st.WithDetails(&errdetails.BadRequest{...})
err := st.Err()
```

---

**For More Information:**
- HTTP Status Codes: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
- gRPC Status Codes: https://grpc.io/docs/guides/status-codes/
- RFC 9457 Problem Details: https://www.rfc-editor.org/rfc/rfc9457.html
- Google API Error Model: https://cloud.google.com/apis/design/errors
