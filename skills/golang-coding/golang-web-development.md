# Golang Web Development Sub-Skill

**Last Updated**: 2025-11-02 (Research Date)
**Framework Versions**: Gin v1.9+, Echo v4.x, Fiber v2.x (Current as of 2024-2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Framework Selection Guide](#framework-selection-guide)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)
7. [Tools and Libraries](#tools-and-libraries)
8. [Examples](#examples)
9. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for building modern web applications and RESTful APIs in Go using contemporary frameworks and best practices. It covers the full web development lifecycle from routing and middleware to database integration, authentication, and deployment.

**Key Capabilities:**
- Build high-performance RESTful APIs with proper HTTP semantics
- Implement robust middleware for logging, authentication, and error handling
- Integrate with relational and NoSQL databases using modern ORMs and drivers
- Handle authentication and authorization (JWT, OAuth2, session-based)
- Serve static files and render HTML templates
- Implement WebSocket connections for real-time communication
- Handle CORS, rate limiting, and security best practices
- Deploy Go web applications to production (Docker, Kubernetes)

---

## When to Use

Use this sub-skill when:
- **Building REST APIs**: Creating HTTP APIs for mobile apps, SPAs, or microservices
- **Developing Web Applications**: Building server-side rendered web applications
- **Microservices Architecture**: Implementing individual services in a distributed system
- **Real-Time Applications**: Building chat systems, live notifications, or collaborative tools
- **API Gateways**: Creating routing layers or API aggregation services
- **Backend Services**: Building authentication servers, file upload services, or data processing APIs

**Concrete Scenarios:**
- Creating a user authentication API with JWT tokens, email verification, and password reset
- Building an e-commerce REST API with product catalog, shopping cart, and order processing
- Developing a real-time chat application with WebSocket connections and message persistence
- Implementing a file upload service with multipart form handling and cloud storage integration
- Creating a microservice that processes payment transactions with external payment gateway integration

---

## Core Concepts

### 1. RESTful API Design Principles

**Resource-Based Architecture:**
- Resources identified by URIs (e.g., `/users`, `/users/123`, `/users/123/orders`)
- Use nouns for resources, not verbs (`/users` not `/getUsers`)
- Collections vs individual resources: `/users` vs `/users/123`

**HTTP Methods (Verbs):**
- `GET`: Retrieve resource(s) - idempotent, safe, cacheable
- `POST`: Create new resource - not idempotent
- `PUT`: Update/replace entire resource - idempotent
- `PATCH`: Partially update resource - not necessarily idempotent
- `DELETE`: Remove resource - idempotent

**HTTP Status Codes:**
- `2xx` Success: 200 (OK), 201 (Created), 204 (No Content)
- `3xx` Redirection: 301 (Moved Permanently), 304 (Not Modified)
- `4xx` Client Errors: 400 (Bad Request), 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 422 (Unprocessable Entity)
- `5xx` Server Errors: 500 (Internal Server Error), 503 (Service Unavailable)

**Stateless Communication:**
- Each request contains all information needed (no server-side session state in strict REST)
- Authentication via tokens in headers (Authorization: Bearer <token>)
- Client maintains application state

### 2. Routing and Handlers

**Handler Function Signature:**
```go
// Standard library
func(w http.ResponseWriter, r *http.Request)

// Framework-specific (e.g., Gin)
func(c *gin.Context)

// Echo
func(c echo.Context) error
```

**Route Parameters:**
- Path parameters: `/users/:id` - dynamic segments
- Query parameters: `/users?page=2&limit=10` - filtering/pagination
- Request body: JSON/XML payloads for POST/PUT/PATCH

**Route Groups:**
Organize related routes with common prefixes and middleware:
```go
api := router.Group("/api/v1")
{
    api.GET("/users", listUsers)
    api.POST("/users", createUser)
}
```

### 3. Middleware Pattern

Middleware are functions that execute before/after handlers, providing cross-cutting concerns:

**Common Middleware Types:**
- **Logging**: Request/response logging, access logs
- **Authentication**: Token validation, session checks
- **Authorization**: Permission checks, role-based access
- **CORS**: Cross-Origin Resource Sharing headers
- **Rate Limiting**: Request throttling, DDoS protection
- **Error Recovery**: Panic recovery, error handling
- **Request ID**: Correlation IDs for distributed tracing
- **Compression**: Gzip response compression
- **Request Validation**: Input sanitization, schema validation

**Middleware Execution Order:**
```
Request → Middleware 1 → Middleware 2 → Handler → Middleware 2 → Middleware 1 → Response
```

### 4. Data Serialization

**JSON (Primary):**
```go
// Encoding
json.Marshal(data)
c.JSON(200, data)  // Framework helpers

// Decoding
json.Unmarshal(body, &data)
c.ShouldBindJSON(&data)  // Framework helpers with validation
```

**Struct Tags for JSON:**
```go
type User struct {
    ID        int       `json:"id"`
    Email     string    `json:"email" binding:"required,email"`
    Password  string    `json:"-"`  // Never serialize
    CreatedAt time.Time `json:"created_at"`
}
```

### 5. Error Handling

**Consistent Error Response Structure:**
```go
type ErrorResponse struct {
    Error   string            `json:"error"`
    Message string            `json:"message"`
    Code    int               `json:"code"`
    Details map[string]string `json:"details,omitempty"`
}
```

**Error Handling Strategies:**
- Custom error types with HTTP status codes
- Centralized error handling middleware
- Structured error responses with actionable messages
- Logging errors with context (request ID, user, operation)

### 6. Database Integration

**Connection Patterns:**
- Connection pooling (configure `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`)
- Health checks via `Ping()`
- Context-aware queries for timeouts and cancellation
- Transaction management with proper rollback

**ORMs vs Raw SQL:**
- **GORM**: Feature-rich ORM with migrations, associations, hooks
- **sqlx**: Thin layer over database/sql with better scanning
- **pgx**: High-performance PostgreSQL driver
- **database/sql**: Standard library for raw SQL

### 7. Authentication and Authorization

**JWT (JSON Web Tokens):**
- Stateless authentication
- Token structure: Header.Payload.Signature
- Claims: user ID, roles, expiration
- Refresh token pattern for long-lived sessions

**OAuth2:**
- Delegated authorization
- Common flows: Authorization Code, Client Credentials
- Libraries: `golang.org/x/oauth2`

**Session-Based:**
- Server-side session storage (Redis, database)
- Session cookie with secure flags (HttpOnly, Secure, SameSite)

### 8. Security Best Practices

**Input Validation:**
- Validate and sanitize all user input
- Use binding/validation libraries (validator package)
- Whitelist validation over blacklist

**HTTPS/TLS:**
- Always use TLS in production
- Proper certificate management
- HSTS headers

**CORS Configuration:**
- Restrict allowed origins (never `*` in production with credentials)
- Limit allowed methods and headers
- Configure credentials properly

**SQL Injection Prevention:**
- Use parameterized queries (never string concatenation)
- ORMs provide protection by default

**XSS Prevention:**
- Escape output in templates
- Set Content-Security-Policy headers

---

## Framework Selection Guide

### Framework Comparison (2024)

| Feature | Gin | Echo | Fiber |
|---------|-----|------|-------|
| **Performance** | Very High | Very High | Extremely High |
| **Ease of Use** | Easiest | Medium | Easy (Express-like) |
| **Documentation** | Excellent | Excellent | Good |
| **Community** | Largest | Large | Growing |
| **Middleware** | Rich ecosystem | Rich ecosystem | Rich ecosystem |
| **Learning Curve** | Gentle | Gentle | Gentle (if know Express) |
| **HTTP Server** | net/http | net/http | FastHTTP |
| **Best For** | General web apps | Extensible apps | Ultra-high performance |

### Decision Matrix

**Choose Gin if:**
- You want the easiest learning curve and best documentation
- You need broad community support and many examples
- You're building standard REST APIs or web applications
- You value maturity and stability
- **Most popular choice - safe default for most projects**

**Choose Echo if:**
- You need maximum extensibility and customization
- You want rich built-in features (validation, data binding)
- You're building complex applications with many components
- You prefer a more structured framework

**Choose Fiber if:**
- Performance is the absolute top priority
- You're migrating from Express.js (Node.js) and want similar API
- You're building high-throughput microservices
- You need ultra-low latency responses
- **Note**: Uses FastHTTP instead of net/http (different ecosystem)

### Real-World Performance (2024)

Based on 2024 benchmarks:
- **Fiber**: ~36,000 req/sec, 2.8ms median latency
- **Gin**: ~34,000 req/sec, 3.0ms median latency
- **Echo**: ~34,000 req/sec, 3.0ms median latency

**Performance differences are negligible for most applications.** Choose based on developer experience and ecosystem fit.

---

## Best Practices

### 1. Project Structure

**Standard Go Web Project Layout:**
```
myapp/
├── cmd/
│   └── api/
│       └── main.go              # Application entry point
├── internal/
│   ├── handlers/                # HTTP handlers
│   │   ├── users.go
│   │   └── auth.go
│   ├── middleware/              # Custom middleware
│   │   ├── auth.go
│   │   └── logging.go
│   ├── models/                  # Data models
│   │   └── user.go
│   ├── repository/              # Data access layer
│   │   ├── user_repository.go
│   │   └── postgres.go
│   ├── services/                # Business logic
│   │   └── user_service.go
│   └── config/                  # Configuration
│       └── config.go
├── pkg/                         # Public libraries (if any)
├── migrations/                  # Database migrations
├── static/                      # Static assets
├── templates/                   # HTML templates
├── go.mod
├── go.sum
├── Dockerfile
└── README.md
```

**Layer Separation (Clean Architecture):**
```
Handler → Service → Repository → Database
         ↓
    Models/DTOs
```

### 2. Dependency Injection

**Constructor-Based Injection:**
```go
type UserHandler struct {
    userService *UserService
    logger      *log.Logger
}

func NewUserHandler(userService *UserService, logger *log.Logger) *UserHandler {
    return &UserHandler{
        userService: userService,
        logger:      logger,
    }
}

func (h *UserHandler) GetUser(c *gin.Context) {
    // Handler logic with injected dependencies
}
```

**Benefits:**
- Testability (easy to mock dependencies)
- Loose coupling
- Clear dependencies
- Thread-safe (no global state)

### 3. Configuration Management

**Environment-Based Configuration:**
```go
type Config struct {
    ServerPort     string `env:"SERVER_PORT" envDefault:"8080"`
    DatabaseURL    string `env:"DATABASE_URL,required"`
    JWTSecret      string `env:"JWT_SECRET,required"`
    LogLevel       string `env:"LOG_LEVEL" envDefault:"info"`
    AllowedOrigins string `env:"ALLOWED_ORIGINS" envDefault:"*"`
}

// Use libraries like envconfig, viper, or cleanenv
func LoadConfig() (*Config, error) {
    var cfg Config
    if err := env.Parse(&cfg); err != nil {
        return nil, err
    }
    return &cfg, nil
}
```

**Never hardcode:**
- Database credentials
- API keys and secrets
- Environment-specific URLs
- Feature flags

### 4. Request Validation

**Use Binding and Validation Tags:**
```go
type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=8,max=72"`
    Name     string `json:"name" binding:"required,min=2,max=100"`
    Age      int    `json:"age" binding:"gte=0,lte=130"`
}

func (h *UserHandler) CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    // Proceed with validated data
}
```

**Validator Package (github.com/go-playground/validator):**
- `required`, `omitempty`
- `email`, `url`, `uuid`
- `min`, `max`, `len`, `eq`, `ne`, `gt`, `gte`, `lt`, `lte`
- `alphanum`, `numeric`, `alpha`
- Custom validators

### 5. Response Formatting

**Consistent Response Structure:**
```go
type SuccessResponse struct {
    Data    interface{} `json:"data"`
    Message string      `json:"message,omitempty"`
}

type ErrorResponse struct {
    Error   string                 `json:"error"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

// Helper functions
func respondSuccess(c *gin.Context, status int, data interface{}, message string) {
    c.JSON(status, SuccessResponse{Data: data, Message: message})
}

func respondError(c *gin.Context, status int, err error, message string) {
    c.JSON(status, ErrorResponse{
        Error:   err.Error(),
        Message: message,
    })
}
```

### 6. Database Best Practices

**Context-Aware Queries:**
```go
func (r *UserRepository) GetByID(ctx context.Context, id int) (*User, error) {
    var user User
    err := r.db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id).Scan(&user)
    if err == sql.ErrNoRows {
        return nil, ErrUserNotFound
    }
    return &user, err
}
```

**Transaction Management:**
```go
func (s *UserService) CreateUserWithProfile(ctx context.Context, user *User, profile *Profile) error {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()  // Rollback if not committed

    if err := s.repo.CreateUser(ctx, tx, user); err != nil {
        return err
    }

    if err := s.repo.CreateProfile(ctx, tx, profile); err != nil {
        return err
    }

    return tx.Commit()
}
```

**Connection Pooling:**
```go
db.SetMaxOpenConns(25)                 // Maximum open connections
db.SetMaxIdleConns(5)                  // Maximum idle connections
db.SetConnMaxLifetime(5 * time.Minute) // Connection lifetime
```

### 7. Middleware Implementation

**Custom Logging Middleware:**
```go
func LoggingMiddleware(logger *log.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        method := c.Request.Method

        c.Next()  // Process request

        latency := time.Since(start)
        status := c.Writer.Status()

        logger.Printf("%s %s %d %v", method, path, status, latency)
    }
}

// Usage
router.Use(LoggingMiddleware(logger))
```

**Authentication Middleware:**
```go
func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(401, gin.H{"error": "missing authorization header"})
            c.Abort()
            return
        }

        token := strings.TrimPrefix(authHeader, "Bearer ")
        claims, err := validateJWT(token, jwtSecret)
        if err != nil {
            c.JSON(401, gin.H{"error": "invalid token"})
            c.Abort()
            return
        }

        c.Set("user_id", claims.UserID)
        c.Next()
    }
}

// Apply to protected routes
authorized := router.Group("/api")
authorized.Use(AuthMiddleware(jwtSecret))
{
    authorized.GET("/profile", getProfile)
}
```

### 8. Error Handling

**Centralized Error Handler:**
```go
func ErrorHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()

        if len(c.Errors) > 0 {
            err := c.Errors.Last()

            switch e := err.Err.(type) {
            case *ValidationError:
                c.JSON(400, ErrorResponse{Error: "validation_error", Message: e.Error()})
            case *NotFoundError:
                c.JSON(404, ErrorResponse{Error: "not_found", Message: e.Error()})
            case *UnauthorizedError:
                c.JSON(401, ErrorResponse{Error: "unauthorized", Message: e.Error()})
            default:
                c.JSON(500, ErrorResponse{Error: "internal_error", Message: "An unexpected error occurred"})
            }
        }
    }
}
```

**Custom Error Types:**
```go
type AppError struct {
    Code    int
    Message string
    Err     error
}

func (e *AppError) Error() string {
    return e.Message
}

func NewNotFoundError(resource string) *AppError {
    return &AppError{
        Code:    404,
        Message: fmt.Sprintf("%s not found", resource),
    }
}
```

### 9. Graceful Shutdown

**Handle OS Signals:**
```go
func main() {
    router := setupRouter()

    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("listen: %s\n", err)
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    log.Println("Shutting down server...")

    // Graceful shutdown with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}
```

### 10. API Versioning

**URI-Based Versioning:**
```go
v1 := router.Group("/api/v1")
{
    v1.GET("/users", getUsersV1)
}

v2 := router.Group("/api/v2")
{
    v2.GET("/users", getUsersV2)
}
```

**Header-Based Versioning:**
```go
func VersionMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        version := c.GetHeader("API-Version")
        c.Set("api_version", version)
        c.Next()
    }
}
```

---

## Common Pitfalls

### 1. Not Using Context for Request Cancellation

**Problem:**
```go
func (h *Handler) SlowOperation(c *gin.Context) {
    // Long-running operation without context
    result := heavyDatabaseQuery()  // Client disconnected, still running!
    c.JSON(200, result)
}
```

**Impact**: Wasted resources, database connections not released, memory leaks.

**Solution:**
```go
func (h *Handler) SlowOperation(c *gin.Context) {
    ctx := c.Request.Context()
    result, err := heavyDatabaseQueryWithContext(ctx)
    if err != nil {
        if ctx.Err() == context.Canceled {
            return  // Client disconnected
        }
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, result)
}
```

### 2. Storing Sensitive Data in Logs

**Problem:**
```go
log.Printf("User login: %+v", loginRequest)  // Contains password!
```

**Impact**: Security breach, credentials exposed in logs.

**Solution:**
```go
// Use structured logging with field control
log.Printf("User login attempt: email=%s", loginRequest.Email)

// Or implement custom String() method
func (r LoginRequest) String() string {
    return fmt.Sprintf("LoginRequest{Email: %s}", r.Email)  // No password
}
```

### 3. Not Setting Proper HTTP Status Codes

**Problem:**
```go
func (h *Handler) GetUser(c *gin.Context) {
    user, err := h.service.GetUser(id)
    if err != nil {
        c.JSON(200, gin.H{"error": err.Error()})  // Wrong! Should be 4xx/5xx
        return
    }
}
```

**Impact**: Clients can't distinguish between success and failure. Poor API design.

**Solution:**
```go
func (h *Handler) GetUser(c *gin.Context) {
    user, err := h.service.GetUser(id)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            c.JSON(404, gin.H{"error": "user not found"})
        } else {
            c.JSON(500, gin.H{"error": "internal server error"})
        }
        return
    }
    c.JSON(200, user)
}
```

### 4. Returning Database Entities Directly

**Problem:**
```go
type User struct {
    ID           int
    Email        string
    PasswordHash string  // Exposed in JSON!
    Salt         string  // Exposed!
}

func (h *Handler) GetUser(c *gin.Context) {
    user, _ := h.repo.GetUser(id)
    c.JSON(200, user)  // Returns password hash!
}
```

**Impact**: Security vulnerability, internal implementation exposed.

**Solution:**
```go
type UserResponse struct {
    ID    int    `json:"id"`
    Email string `json:"email"`
    Name  string `json:"name"`
}

func (h *Handler) GetUser(c *gin.Context) {
    user, err := h.repo.GetUser(id)
    if err != nil {
        c.JSON(404, gin.H{"error": "not found"})
        return
    }

    response := UserResponse{
        ID:    user.ID,
        Email: user.Email,
        Name:  user.Name,
    }
    c.JSON(200, response)
}
```

### 5. Not Validating User Input

**Problem:**
```go
func (h *Handler) CreateUser(c *gin.Context) {
    var user User
    c.BindJSON(&user)  // No validation!
    h.service.CreateUser(&user)  // SQL injection possible
}
```

**Impact**: Security vulnerabilities, data corruption, crashes.

**Solution:**
```go
type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=8"`
}

func (h *Handler) CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    // Proceed with validated data
}
```

### 6. Not Handling Database Connection Errors

**Problem:**
```go
db, _ := sql.Open("postgres", connStr)  // Ignores error!
defer db.Close()
```

**Impact**: Application crashes or hangs when database is unavailable.

**Solution:**
```go
db, err := sql.Open("postgres", connStr)
if err != nil {
    log.Fatalf("Failed to open database: %v", err)
}
defer db.Close()

// Test connection
if err := db.Ping(); err != nil {
    log.Fatalf("Failed to connect to database: %v", err)
}
```

### 7. Not Using CORS Properly

**Problem:**
```go
// Allowing all origins with credentials
router.Use(cors.New(cors.Config{
    AllowOrigins:     []string{"*"},
    AllowCredentials: true,  // Security issue!
}))
```

**Impact**: CORS doesn't work, or security vulnerability.

**Solution:**
```go
router.Use(cors.New(cors.Config{
    AllowOrigins:     []string{"https://yourdomain.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
    AllowHeaders:     []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
    MaxAge:           12 * time.Hour,
}))
```

### 8. Blocking on Channel Operations in Handlers

**Problem:**
```go
func (h *Handler) Process(c *gin.Context) {
    result := <-h.resultChan  // Blocks forever if no sender!
    c.JSON(200, result)
}
```

**Impact**: Handler hangs, server becomes unresponsive.

**Solution:**
```go
func (h *Handler) Process(c *gin.Context) {
    ctx := c.Request.Context()
    select {
    case result := <-h.resultChan:
        c.JSON(200, result)
    case <-ctx.Done():
        c.JSON(500, gin.H{"error": "request timeout"})
    case <-time.After(5 * time.Second):
        c.JSON(500, gin.H{"error": "operation timeout"})
    }
}
```

---

## Tools and Libraries

### Web Frameworks (2024-2025)

1. **Gin** - `github.com/gin-gonic/gin`
   - Most popular, excellent documentation
   - Fastest among net/http-based frameworks
   - Rich middleware ecosystem

2. **Echo** - `github.com/labstack/echo/v4`
   - Highly extensible
   - Built-in data binding and validation
   - Excellent middleware support

3. **Fiber** - `github.com/gofiber/fiber/v2`
   - Express.js-inspired API
   - Built on FastHTTP (not net/http)
   - Highest raw performance

4. **Chi** - `github.com/go-chi/chi/v5`
   - Lightweight, idiomatic
   - Pure net/http compatibility
   - Excellent routing with middleware

### Database Libraries

5. **GORM** - `gorm.io/gorm`
   - Full-featured ORM
   - Auto-migrations, associations
   - Hooks and plugins

6. **sqlx** - `github.com/jmoiron/sqlx`
   - Extension of database/sql
   - Named parameters, struct scanning
   - Minimal overhead

7. **pgx** - `github.com/jackc/pgx/v5`
   - Native PostgreSQL driver
   - High performance
   - Rich feature set

8. **go-redis** - `github.com/redis/go-redis/v9`
   - Redis client with context support
   - Cluster and sentinel support
   - Pipeline and pub/sub

### Validation

9. **validator** - `github.com/go-playground/validator/v10`
   - Struct field validation
   - Custom validators
   - Cross-field validation

### Authentication

10. **jwt-go** - `github.com/golang-jwt/jwt/v5`
    - JWT implementation
    - Multiple signing methods
    - Claims validation

11. **oauth2** - `golang.org/x/oauth2`
    - OAuth2 client
    - Multiple provider support
    - Token management

### Middleware

12. **cors** - `github.com/gin-contrib/cors`
    - CORS middleware for Gin
    - Configurable origins, methods, headers

13. **rate** - `golang.org/x/time/rate`
    - Rate limiting
    - Token bucket algorithm
    - Configurable limits

### Configuration

14. **viper** - `github.com/spf13/viper`
    - Configuration management
    - Multiple formats (JSON, YAML, ENV)
    - Live reloading

15. **envconfig** - `github.com/kelseyhightower/envconfig`
    - Environment variable parsing
    - Struct tag-based configuration
    - Simple and lightweight

### Logging

16. **zap** - `go.uber.org/zap`
    - High-performance structured logging
    - Leveled logging
    - JSON output

17. **logrus** - `github.com/sirupsen/logrus`
    - Structured logger
    - Hook system
    - Multiple output formats

### Testing

18. **httptest** - `net/http/httptest` (stdlib)
    - HTTP handler testing
    - Mock servers
    - Response recording

### Documentation

19. **swag** - `github.com/swaggo/swag`
    - Swagger documentation generation
    - Annotation-based
    - Interactive API docs

---

## Examples

### Example 1: Basic REST API with Gin

```go
package main

import (
    "github.com/gin-gonic/gin"
    "net/http"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

var users = []User{
    {ID: 1, Name: "Alice", Email: "alice@example.com"},
    {ID: 2, Name: "Bob", Email: "bob@example.com"},
}

func main() {
    router := gin.Default()

    // Routes
    router.GET("/users", listUsers)
    router.GET("/users/:id", getUser)
    router.POST("/users", createUser)
    router.PUT("/users/:id", updateUser)
    router.DELETE("/users/:id", deleteUser)

    router.Run(":8080")
}

func listUsers(c *gin.Context) {
    c.JSON(http.StatusOK, users)
}

func getUser(c *gin.Context) {
    id := c.Param("id")
    for _, user := range users {
        if fmt.Sprint(user.ID) == id {
            c.JSON(http.StatusOK, user)
            return
        }
    }
    c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
}

type CreateUserRequest struct {
    Name  string `json:"name" binding:"required,min=2"`
    Email string `json:"email" binding:"required,email"`
}

func createUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    newUser := User{
        ID:    len(users) + 1,
        Name:  req.Name,
        Email: req.Email,
    }
    users = append(users, newUser)

    c.JSON(http.StatusCreated, newUser)
}

func updateUser(c *gin.Context) {
    id := c.Param("id")
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    for i, user := range users {
        if fmt.Sprint(user.ID) == id {
            users[i].Name = req.Name
            users[i].Email = req.Email
            c.JSON(http.StatusOK, users[i])
            return
        }
    }
    c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
}

func deleteUser(c *gin.Context) {
    id := c.Param("id")
    for i, user := range users {
        if fmt.Sprint(user.ID) == id {
            users = append(users[:i], users[i+1:]...)
            c.JSON(http.StatusNoContent, nil)
            return
        }
    }
    c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
}
```

### Example 2: Authentication with JWT

```go
package main

import (
    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
    "time"
)

var jwtSecret = []byte("your-secret-key")

type Claims struct {
    UserID int `json:"user_id"`
    jwt.RegisteredClaims
}

type LoginRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required"`
}

func main() {
    router := gin.Default()

    // Public routes
    router.POST("/login", login)
    router.POST("/register", register)

    // Protected routes
    authorized := router.Group("/")
    authorized.Use(AuthMiddleware())
    {
        authorized.GET("/profile", getProfile)
        authorized.PUT("/profile", updateProfile)
    }

    router.Run(":8080")
}

func login(c *gin.Context) {
    var req LoginRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    // Verify credentials (simplified - use bcrypt in production)
    userID, valid := verifyCredentials(req.Email, req.Password)
    if !valid {
        c.JSON(401, gin.H{"error": "invalid credentials"})
        return
    }

    // Generate JWT
    token, err := generateJWT(userID)
    if err != nil {
        c.JSON(500, gin.H{"error": "failed to generate token"})
        return
    }

    c.JSON(200, gin.H{"token": token})
}

func generateJWT(userID int) (string, error) {
    claims := Claims{
        UserID: userID,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(jwtSecret)
}

func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        tokenString := c.GetHeader("Authorization")
        if tokenString == "" {
            c.JSON(401, gin.H{"error": "missing authorization header"})
            c.Abort()
            return
        }

        // Remove "Bearer " prefix
        if len(tokenString) > 7 && tokenString[:7] == "Bearer " {
            tokenString = tokenString[7:]
        }

        claims := &Claims{}
        token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
            return jwtSecret, nil
        })

        if err != nil || !token.Valid {
            c.JSON(401, gin.H{"error": "invalid token"})
            c.Abort()
            return
        }

        // Store user ID in context
        c.Set("user_id", claims.UserID)
        c.Next()
    }
}

func getProfile(c *gin.Context) {
    userID := c.GetInt("user_id")
    user := getUserByID(userID)
    c.JSON(200, user)
}
```

### Example 3: Database Integration with GORM

```go
package main

import (
    "github.com/gin-gonic/gin"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "log"
)

type User struct {
    gorm.Model
    Email    string `gorm:"uniqueIndex;not null"`
    Name     string `gorm:"not null"`
    Password string `gorm:"not null" json:"-"`  // Never expose in JSON
}

type UserResponse struct {
    ID    uint   `json:"id"`
    Email string `json:"email"`
    Name  string `json:"name"`
}

type UserHandler struct {
    db *gorm.DB
}

func main() {
    // Connect to database
    dsn := "host=localhost user=postgres password=secret dbname=myapp port=5432 sslmode=disable"
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }

    // Auto-migrate schema
    db.AutoMigrate(&User{})

    // Setup handler
    handler := &UserHandler{db: db}

    // Setup router
    router := gin.Default()
    router.GET("/users", handler.ListUsers)
    router.GET("/users/:id", handler.GetUser)
    router.POST("/users", handler.CreateUser)
    router.PUT("/users/:id", handler.UpdateUser)
    router.DELETE("/users/:id", handler.DeleteUser)

    router.Run(":8080")
}

func (h *UserHandler) ListUsers(c *gin.Context) {
    var users []User
    result := h.db.Find(&users)
    if result.Error != nil {
        c.JSON(500, gin.H{"error": result.Error.Error()})
        return
    }

    // Convert to response DTOs
    responses := make([]UserResponse, len(users))
    for i, user := range users {
        responses[i] = UserResponse{
            ID:    user.ID,
            Email: user.Email,
            Name:  user.Name,
        }
    }

    c.JSON(200, responses)
}

func (h *UserHandler) GetUser(c *gin.Context) {
    id := c.Param("id")
    var user User

    result := h.db.First(&user, id)
    if result.Error != nil {
        if result.Error == gorm.ErrRecordNotFound {
            c.JSON(404, gin.H{"error": "user not found"})
        } else {
            c.JSON(500, gin.H{"error": result.Error.Error()})
        }
        return
    }

    c.JSON(200, UserResponse{
        ID:    user.ID,
        Email: user.Email,
        Name:  user.Name,
    })
}

type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Name     string `json:"name" binding:"required,min=2"`
    Password string `json:"password" binding:"required,min=8"`
}

func (h *UserHandler) CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    // Hash password (use bcrypt in production)
    hashedPassword := hashPassword(req.Password)

    user := User{
        Email:    req.Email,
        Name:     req.Name,
        Password: hashedPassword,
    }

    result := h.db.Create(&user)
    if result.Error != nil {
        c.JSON(400, gin.H{"error": "failed to create user"})
        return
    }

    c.JSON(201, UserResponse{
        ID:    user.ID,
        Email: user.Email,
        Name:  user.Name,
    })
}

func (h *UserHandler) UpdateUser(c *gin.Context) {
    id := c.Param("id")

    var user User
    if result := h.db.First(&user, id); result.Error != nil {
        c.JSON(404, gin.H{"error": "user not found"})
        return
    }

    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    user.Email = req.Email
    user.Name = req.Name
    if req.Password != "" {
        user.Password = hashPassword(req.Password)
    }

    h.db.Save(&user)

    c.JSON(200, UserResponse{
        ID:    user.ID,
        Email: user.Email,
        Name:  user.Name,
    })
}

func (h *UserHandler) DeleteUser(c *gin.Context) {
    id := c.Param("id")

    result := h.db.Delete(&User{}, id)
    if result.Error != nil {
        c.JSON(500, gin.H{"error": result.Error.Error()})
        return
    }

    if result.RowsAffected == 0 {
        c.JSON(404, gin.H{"error": "user not found"})
        return
    }

    c.JSON(204, nil)
}
```

### Example 4: Middleware Chain

```go
package main

import (
    "github.com/gin-gonic/gin"
    "log"
    "time"
)

func main() {
    router := gin.New()  // Create router without default middleware

    // Global middleware
    router.Use(RequestIDMiddleware())
    router.Use(LoggingMiddleware())
    router.Use(RecoveryMiddleware())
    router.Use(CORSMiddleware())

    // Rate limited group
    api := router.Group("/api")
    api.Use(RateLimitMiddleware(100, time.Minute))
    {
        // Public endpoints
        api.POST("/login", login)

        // Authenticated endpoints
        authenticated := api.Group("/")
        authenticated.Use(AuthMiddleware())
        {
            authenticated.GET("/profile", getProfile)

            // Admin-only endpoints
            admin := authenticated.Group("/admin")
            admin.Use(AdminOnlyMiddleware())
            {
                admin.GET("/users", listAllUsers)
                admin.DELETE("/users/:id", deleteUser)
            }
        }
    }

    router.Run(":8080")
}

func RequestIDMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        requestID := generateRequestID()
        c.Set("request_id", requestID)
        c.Header("X-Request-ID", requestID)
        c.Next()
    }
}

func LoggingMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        method := c.Request.Method
        requestID := c.GetString("request_id")

        c.Next()

        latency := time.Since(start)
        status := c.Writer.Status()

        log.Printf("[%s] %s %s %d %v", requestID, method, path, status, latency)
    }
}

func RecoveryMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if err := recover(); err != nil {
                log.Printf("Panic recovered: %v", err)
                c.JSON(500, gin.H{"error": "internal server error"})
                c.Abort()
            }
        }()
        c.Next()
    }
}

func CORSMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("Access-Control-Allow-Origin", "https://yourdomain.com")
        c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
        c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        c.Header("Access-Control-Max-Age", "86400")

        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }

        c.Next()
    }
}

func RateLimitMiddleware(requests int, duration time.Duration) gin.HandlerFunc {
    // Implement rate limiting logic (use golang.org/x/time/rate)
    return func(c *gin.Context) {
        // Check rate limit
        // If exceeded: c.JSON(429, gin.H{"error": "rate limit exceeded"})
        c.Next()
    }
}

func AdminOnlyMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        userRole := c.GetString("user_role")
        if userRole != "admin" {
            c.JSON(403, gin.H{"error": "admin access required"})
            c.Abort()
            return
        }
        c.Next()
    }
}
```

### Example 5: Graceful Shutdown and Health Checks

```go
package main

import (
    "context"
    "github.com/gin-gonic/gin"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    router := setupRouter()

    srv := &http.Server{
        Addr:         ":8080",
        Handler:      router,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    // Start server in goroutine
    go func() {
        log.Println("Server starting on :8080")
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server failed: %v", err)
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    // Graceful shutdown with 5 second timeout
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited gracefully")
}

func setupRouter() *gin.Engine {
    router := gin.Default()

    // Health check endpoints
    router.GET("/health", healthCheck)
    router.GET("/ready", readinessCheck)

    // Application routes
    router.GET("/api/users", listUsers)

    return router
}

func healthCheck(c *gin.Context) {
    c.JSON(200, gin.H{
        "status": "ok",
        "timestamp": time.Now().Unix(),
    })
}

func readinessCheck(c *gin.Context) {
    // Check database connectivity
    if err := checkDatabase(); err != nil {
        c.JSON(503, gin.H{
            "status": "not ready",
            "reason": "database unavailable",
        })
        return
    }

    // Check other dependencies (Redis, external APIs, etc.)

    c.JSON(200, gin.H{
        "status": "ready",
    })
}
```

---

## Quick Reference

### Gin Framework

**Installation:**
```bash
go get github.com/gin-gonic/gin
```

**Basic Setup:**
```go
router := gin.Default()  // With default middleware
router := gin.New()      // Without middleware

router.GET("/path", handler)
router.POST("/path", handler)
router.PUT("/path", handler)
router.DELETE("/path", handler)
router.PATCH("/path", handler)

router.Run(":8080")
```

**Handler Functions:**
```go
func handler(c *gin.Context) {
    // Get path parameter
    id := c.Param("id")

    // Get query parameter
    name := c.Query("name")

    // Bind JSON body
    var data MyStruct
    c.ShouldBindJSON(&data)

    // Return JSON
    c.JSON(200, data)

    // Return error
    c.JSON(400, gin.H{"error": "message"})

    // Get context
    ctx := c.Request.Context()

    // Store in context
    c.Set("key", value)
    value := c.GetString("key")
}
```

**Route Groups:**
```go
v1 := router.Group("/api/v1")
v1.Use(middleware)
{
    v1.GET("/users", getUsers)
    v1.POST("/users", createUser)
}
```

**Middleware:**
```go
func MyMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Before request
        c.Next()
        // After request
    }
}

router.Use(MyMiddleware())
```

### Common HTTP Status Codes

```go
200  http.StatusOK
201  http.StatusCreated
204  http.StatusNoContent
400  http.StatusBadRequest
401  http.StatusUnauthorized
403  http.StatusForbidden
404  http.StatusNotFound
422  http.StatusUnprocessableEntity
500  http.StatusInternalServerError
503  http.StatusServiceUnavailable
```

### Validation Tags

```go
type Request struct {
    Email    string `binding:"required,email"`
    Password string `binding:"required,min=8,max=72"`
    Age      int    `binding:"gte=0,lte=130"`
    Name     string `binding:"required,min=2,max=100"`
    URL      string `binding:"omitempty,url"`
}
```

**Common validators:**
- `required`, `omitempty`
- `email`, `url`, `uuid`
- `min`, `max`, `len`, `eq`, `ne`
- `gte`, `gt`, `lte`, `lt`
- `alphanum`, `numeric`, `alpha`

### Database Connection (GORM)

```go
import "gorm.io/gorm"
import "gorm.io/driver/postgres"

dsn := "host=localhost user=user password=pass dbname=db port=5432"
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})

db.AutoMigrate(&User{})
db.Create(&user)
db.First(&user, id)
db.Find(&users)
db.Save(&user)
db.Delete(&user, id)
```

### JWT Generation

```go
import "github.com/golang-jwt/jwt/v5"

claims := jwt.MapClaims{
    "user_id": userID,
    "exp":     time.Now().Add(24 * time.Hour).Unix(),
}
token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
tokenString, _ := token.SignedString([]byte("secret"))
```

### Environment Variables

```bash
export SERVER_PORT=8080
export DATABASE_URL=postgres://user:pass@localhost/db
export JWT_SECRET=your-secret-key
```

```go
import "os"

port := os.Getenv("SERVER_PORT")
if port == "" {
    port = "8080"  // default
}
```

---

**For More Information:**
- Gin Documentation: https://gin-gonic.com/docs/
- Echo Documentation: https://echo.labstack.com/
- Fiber Documentation: https://docs.gofiber.io/
- Go Web Examples: https://gowebexamples.com/
- GORM Documentation: https://gorm.io/docs/
