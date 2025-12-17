# Documentation Examples

This document provides comprehensive examples of code documentation across different scenarios.

## Example 1: Complex Algorithm Documentation

```python
def calculate_weighted_score(items: list[ScoredItem], weights: dict[str, float]) -> float:
    """Calculate weighted score using custom decay function.

    This uses exponential decay for older items to prioritize recent activity
    (business requirement: recent engagement weighted 3x higher than 30-day-old).

    The decay formula is: score * e^(-lambda * age_days)
    where lambda = 0.0366 (chosen to achieve 3x decay at 30 days)

    Args:
        items: List of scored items with timestamps
        weights: Category weights (must sum to 1.0)

    Returns:
        Weighted score between 0.0 and 100.0

    Raises:
        ValueError: If weights don't sum to 1.0 (within 0.01 tolerance)

    Example:
        >>> items = [ScoredItem(score=10, age_days=0, category="A")]
        >>> weights = {"A": 1.0}
        >>> calculate_weighted_score(items, weights)
        10.0
    """
    # Verify weights sum to 1.0 before expensive calculation
    # (prevents subtle bugs from incorrect weight configuration)
    weight_sum = sum(weights.values())
    if abs(weight_sum - 1.0) > 0.01:
        raise ValueError(f"Weights must sum to 1.0, got {weight_sum}")

    # Lambda chosen to achieve 3x decay at 30 days: e^(-0.0366 * 30) ≈ 0.333
    DECAY_LAMBDA = 0.0366

    total_score = 0.0
    for item in items:
        # Apply exponential decay based on age
        decay_factor = math.exp(-DECAY_LAMBDA * item.age_days)
        category_weight = weights.get(item.category, 0.0)

        # Weighted score: base_score * decay * category_weight
        total_score += item.score * decay_factor * category_weight

    # Normalize to 0-100 range for consistency with other scoring systems
    return min(100.0, max(0.0, total_score))
```

## Example 2: Behavioral Change Documentation

**Scenario**: Add rate limiting to API endpoint

### Inline Documentation

```go
// RateLimitMiddleware enforces per-user rate limits
//
// Limits: 100 requests per minute per user (configurable via RATE_LIMIT env var)
// Uses sliding window algorithm to prevent burst traffic patterns
//
// If rate limit exceeded, returns 429 Too Many Requests with Retry-After header
func RateLimitMiddleware(limit int) gin.HandlerFunc {
    // Use sliding window counter (more accurate than fixed window)
    // Prevents edge case where user makes 100 req at 00:00:59 and 100 at 00:01:00
    limiter := newSlidingWindowLimiter(limit, time.Minute)

    return func(c *gin.Context) {
        userID := c.GetString("user_id")

        if !limiter.Allow(userID) {
            // Calculate retry-after based on when oldest request expires
            retryAfter := limiter.RetryAfter(userID)
            c.Header("Retry-After", strconv.Itoa(int(retryAfter.Seconds())))
            c.JSON(429, gin.H{
                "error": "rate_limit_exceeded",
                "message": "Too many requests, please try again later",
            })
            c.Abort()
            return
        }

        c.Next()
    }
}
```

### External Documentation (docs/api.md)

```markdown
## Rate Limiting

All API endpoints are subject to rate limiting to ensure fair usage.

### Limits

- **Authenticated Users**: 100 requests per minute
- **Unauthenticated**: 20 requests per minute

### Rate Limit Headers

All responses include rate limit information:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

### Rate Limit Exceeded

When rate limit is exceeded, API returns:

**Status**: `429 Too Many Requests`

**Headers**:
- `Retry-After`: Seconds until rate limit resets

**Response**:
```json
{
  "error": "rate_limit_exceeded",
  "message": "Too many requests, please try again later"
}
```

### Configuration

Rate limits can be configured via environment variables:
- `RATE_LIMIT_AUTHENTICATED`: Requests per minute for authenticated users (default: 100)
- `RATE_LIMIT_ANONYMOUS`: Requests per minute for unauthenticated requests (default: 20)

### Implementation Notes

Rate limiting uses a sliding window algorithm to prevent burst traffic patterns.
Limits are enforced per user ID for authenticated requests, per IP for anonymous requests.
```

### Commit Message

```
Add rate limiting to prevent API abuse

Implement sliding window rate limiting with the following limits:
- Authenticated users: 100 req/min (configurable via RATE_LIMIT_AUTHENTICATED)
- Anonymous requests: 20 req/min (configurable via RATE_LIMIT_ANONYMOUS)

Returns 429 status with Retry-After header when limit exceeded.

This addresses production issue where single user consumed 40% of API
capacity during peak hours, causing degraded performance for all users.

Updated docs/api.md with rate limiting documentation.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Example 3: Workaround Documentation

```go
// HACK: Temporary workaround for third-party API inconsistency
//
// The vendor API sometimes returns null for created_at timestamps on newly
// created resources (race condition on their end). This breaks our sync logic.
//
// Workaround: If created_at is null, use current time. This is safe because:
// 1. Only affects display ordering (not critical)
// 2. Vendor confirmed they'll fix in v2 API (Q2 2025)
// 3. Alternative would be to fail sync entirely (worse UX)
//
// TODO(jsmith): Remove this workaround when migrating to vendor API v2
// Tracking: TICKET-1234
if resource.CreatedAt == nil {
    now := time.Now()
    resource.CreatedAt = &now
    logger.Warn("Null created_at timestamp from vendor API, using current time",
        "resource_id", resource.ID)
}
```

## Example 4: Configuration Documentation

### Code

```python
class DatabaseConfig:
    """Database connection configuration.

    Manages connection pooling and timeout settings for PostgreSQL.

    Attributes:
        host: Database server hostname
        port: Database server port (default: 5432)
        database: Database name
        user: Database username
        password: Database password
        pool_size: Connection pool size (default: 20)
        max_overflow: Maximum connections beyond pool_size (default: 10)
        pool_timeout: Seconds to wait for connection (default: 30)

    Environment Variables:
        DB_HOST: Database host (required)
        DB_PORT: Database port (default: 5432)
        DB_NAME: Database name (required)
        DB_USER: Database username (required)
        DB_PASSWORD: Database password (required)
        DB_POOL_SIZE: Pool size (default: 20)
        DB_MAX_OVERFLOW: Max overflow connections (default: 10)
        DB_POOL_TIMEOUT: Connection timeout seconds (default: 30)
    """

    def __init__(self):
        self.host = os.environ["DB_HOST"]
        self.port = int(os.environ.get("DB_PORT", "5432"))
        self.database = os.environ["DB_NAME"]
        self.user = os.environ["DB_USER"]
        self.password = os.environ["DB_PASSWORD"]

        # Pool settings tuned for typical web application load
        # 20 connections handle ~200 req/sec with 100ms avg query time
        self.pool_size = int(os.environ.get("DB_POOL_SIZE", "20"))

        # Max overflow allows bursts up to 30 total connections
        self.max_overflow = int(os.environ.get("DB_MAX_OVERFLOW", "10"))

        # 30s timeout prevents indefinite hangs during connection exhaustion
        self.pool_timeout = int(os.environ.get("DB_POOL_TIMEOUT", "30"))
```

### External Documentation (docs/configuration.md)

```markdown
## Database Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | Database server hostname | `localhost` or `db.example.com` |
| `DB_NAME` | Database name | `myapp_production` |
| `DB_USER` | Database username | `myapp_user` |
| `DB_PASSWORD` | Database password | `secure_password_here` |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PORT` | `5432` | Database server port |
| `DB_POOL_SIZE` | `20` | Connection pool size |
| `DB_MAX_OVERFLOW` | `10` | Max connections beyond pool size |
| `DB_POOL_TIMEOUT` | `30` | Connection wait timeout (seconds) |

### Connection Pooling

The application uses connection pooling to manage database connections efficiently:

- **Pool Size**: Maintains 20 persistent connections (configurable)
- **Max Overflow**: Allows up to 10 additional connections during bursts
- **Total Capacity**: 30 concurrent connections maximum
- **Timeout**: 30-second wait for available connection

**Performance Guidance**:
- Default settings handle ~200 requests/second with 100ms average query time
- Increase `DB_POOL_SIZE` for higher sustained load
- Increase `DB_MAX_OVERFLOW` for occasional traffic spikes
- Monitor connection pool metrics to tune appropriately

### Example Configuration

```bash
# Development
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=myapp_dev
export DB_USER=dev_user
export DB_PASSWORD=dev_password

# Production (higher pool size for production load)
export DB_HOST=db.prod.example.com
export DB_PORT=5432
export DB_NAME=myapp_production
export DB_USER=prod_user
export DB_PASSWORD=${SECURE_PASSWORD_FROM_VAULT}
export DB_POOL_SIZE=50
export DB_MAX_OVERFLOW=20
```
```

## Example 5: Error Handling Documentation

```go
// ProcessOrder validates and processes a customer order.
//
// This function performs multi-step order processing with transactional guarantees.
// Each step is validated before proceeding to maintain data consistency.
//
// Returns the processed order with generated ID and timestamps.
//
// Error handling strategy:
// - Validation errors: Return immediately without side effects
// - Database errors: Rollback transaction and return error
// - External API errors: Retry up to 3 times with exponential backoff
//
// Possible errors:
// - ErrInvalidOrder: Order validation failed (check error message for details)
// - ErrInsufficientInventory: Requested quantity not available
// - ErrPaymentFailed: Payment processing failed (may be retried)
// - ErrDatabaseError: Database operation failed (transaction rolled back)
//
// Example:
//   order, err := ProcessOrder(orderRequest)
//   if errors.Is(err, ErrInsufficientInventory) {
//       // Handle out of stock
//   }
func ProcessOrder(req OrderRequest) (*Order, error) {
    // Validate order before any database operations
    // (fail fast to avoid unnecessary work)
    if err := req.Validate(); err != nil {
        return nil, fmt.Errorf("invalid order: %w", ErrInvalidOrder)
    }

    // Begin transaction for atomicity
    // All-or-nothing: either complete order or no changes made
    tx, err := db.Begin()
    if err != nil {
        return nil, fmt.Errorf("failed to start transaction: %w", err)
    }
    defer tx.Rollback() // Rollback if not committed

    // Reserve inventory with pessimistic locking
    // (prevents overselling in high-concurrency scenarios)
    if err := reserveInventory(tx, req.Items); err != nil {
        return nil, fmt.Errorf("inventory reservation failed: %w", err)
    }

    // Process payment with retry logic
    // External payment API is occasionally flaky, retry helps success rate
    payment, err := processPaymentWithRetry(req.Payment, 3)
    if err != nil {
        return nil, fmt.Errorf("payment processing failed: %w", ErrPaymentFailed)
    }

    // Create order record
    order := &Order{
        CustomerID: req.CustomerID,
        Items:      req.Items,
        PaymentID:  payment.ID,
        Status:     OrderStatusPending,
        CreatedAt:  time.Now(),
    }

    if err := tx.CreateOrder(order); err != nil {
        return nil, fmt.Errorf("failed to create order: %w", ErrDatabaseError)
    }

    // Commit transaction - this is the point of no return
    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", ErrDatabaseError)
    }

    return order, nil
}
```

## Example 6: Concurrency Documentation

```go
// ConcurrentProcessor processes items concurrently using worker pool pattern.
//
// This implementation uses a fixed-size worker pool to limit resource usage
// while maintaining high throughput for I/O-bound operations.
//
// Concurrency model:
// - Fixed worker pool (size = numWorkers)
// - Job distribution via buffered channel
// - Result collection via separate channel
// - Graceful shutdown on context cancellation
//
// Thread safety:
// - Safe for concurrent calls from multiple goroutines
// - Each call creates independent worker pool
// - No shared mutable state between calls
//
// Performance characteristics:
// - Optimal numWorkers = 2-4x CPU cores for I/O-bound work
// - Buffer size affects memory usage (recommend: 100-1000)
// - Processing time: O(n/numWorkers) for n items
//
// Example:
//   ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
//   defer cancel()
//
//   results, err := ConcurrentProcessor(ctx, items, 10)
//   if err != nil {
//       log.Fatalf("Processing failed: %v", err)
//   }
func ConcurrentProcessor(ctx context.Context, items []Item, numWorkers int) ([]Result, error) {
    // Use buffered channels to avoid goroutine blocking
    // Buffer size = numWorkers to ensure workers don't block on send
    jobs := make(chan Item, numWorkers)
    results := make(chan Result, numWorkers)
    errs := make(chan error, numWorkers)

    // Start worker pool
    // Each worker independently processes items from jobs channel
    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()

            for job := range jobs {
                // Check for cancellation before processing
                // Allows graceful shutdown when context cancelled
                select {
                case <-ctx.Done():
                    errs <- ctx.Err()
                    return
                default:
                }

                // Process item (I/O-bound operation)
                result, err := processItem(job)
                if err != nil {
                    errs <- fmt.Errorf("worker %d failed: %w", workerID, err)
                    return
                }

                results <- result
            }
        }(i)
    }

    // Send jobs to workers
    // Close channel when done to signal workers to exit
    go func() {
        defer close(jobs)
        for _, item := range items {
            select {
            case <-ctx.Done():
                return
            case jobs <- item:
            }
        }
    }()

    // Wait for all workers to complete and close results channel
    go func() {
        wg.Wait()
        close(results)
        close(errs)
    }()

    // Collect results
    // Check for errors first (fail fast)
    select {
    case err := <-errs:
        if err != nil {
            return nil, fmt.Errorf("worker error: %w", err)
        }
    default:
    }

    // Gather all results
    var allResults []Result
    for result := range results {
        allResults = append(allResults, result)
    }

    return allResults, nil
}
```

## Example 7: Task File Documentation

```markdown
## Documentation Impact

**Behavioral Change**: Yes - Added rate limiting to API endpoints

**Inline Documentation**:
- Added detailed comments explaining sliding window algorithm choice
- Documented rate limit configuration environment variables
- Explained Retry-After header calculation logic
- Noted why sliding window is superior to fixed window (prevents burst edge cases)

**External Documentation**:
- Updated docs/api.md with rate limiting section
- Documented headers, error responses, configuration options
- Added examples of rate limit exceeded response
- Included configuration guidance for tuning limits

**Commit Message**:
- Explained what changed (rate limiting added with sliding window algorithm)
- Explained why (preventing API abuse, addressing production incident)
- Referenced production incident that prompted change (40% capacity consumed by single user)
- Noted configuration options (RATE_LIMIT_AUTHENTICATED, RATE_LIMIT_ANONYMOUS)
- Included documentation update reference

**Language-Specific Standards**:
- Followed godoc conventions for function documentation
- Used complete sentences starting with function name
- Documented error conditions and return values
- Included implementation notes for non-obvious design decisions
```

## Summary

These examples demonstrate:
- When to use inline vs external documentation
- How to balance detail with clarity
- When to explain "why" vs "what"
- How to document complex algorithms, behavioral changes, workarounds, configuration, error handling, and concurrency
- How to maintain consistency across documentation types
- How to integrate documentation into the development workflow

Remember: Good documentation explains intent, captures decisions, and helps future maintainers understand not just what the code does, but why it does it that way.
