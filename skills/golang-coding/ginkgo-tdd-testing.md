# Ginkgo TDD Testing Sub-Skill

**Last Updated**: 2025-11-02 (Research Date)
**Ginkgo Version**: v2 (Current as of 2024-2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Installation and Setup](#installation-and-setup)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)
7. [Tools and Libraries](#tools-and-libraries)
8. [Examples](#examples)
9. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for writing Behavior-Driven Development (BDD) tests in Go using the Ginkgo v2 testing framework and Gomega matcher library. It enables developers to create expressive, well-structured, maintainable test suites that serve as living documentation of system behavior.

**Key Capabilities:**
- Write readable BDD-style tests with natural language descriptions
- Organize test suites hierarchically using Describe/Context/It blocks
- Leverage powerful Gomega matchers for expressive assertions
- Execute table-driven tests efficiently with DescribeTable
- Test asynchronous behavior with Eventually and Consistently
- Run tests in parallel for faster feedback cycles
- Profile and optimize test suite performance

---

## When to Use

Use this sub-skill when:
- **Writing Unit Tests**: Testing individual functions, methods, or small components with clear behavioral specifications
- **Integration Testing**: Verifying interactions between multiple components or services
- **API Testing**: Validating HTTP endpoints, request/response handling, and error scenarios
- **Database Testing**: Testing data access layers, repositories, and query logic
- **Async Operations**: Testing goroutines, channels, timers, and other concurrent behavior
- **Refactoring Code**: Ensuring behavioral consistency when restructuring implementations
- **TDD Workflow**: Following red-green-refactor cycles with clear test organization

**Concrete Scenarios:**
- Testing a user authentication service with multiple login scenarios (valid credentials, invalid password, locked account, expired session)
- Verifying REST API endpoints return correct status codes and JSON responses for various input conditions
- Testing database repository methods for CRUD operations with different edge cases
- Validating concurrent data processing pipelines handle errors and timeouts correctly

---

## Core Concepts

### 1. Ginkgo BDD Structure

Ginkgo organizes tests hierarchically using three types of nodes:

**Container Nodes** (organize specs):
- `Describe(text, func)`: Groups related tests by component or feature
- `Context(text, func)`: Groups tests by specific conditions or scenarios
- `When(text, func)`: Alias for Context, emphasizes conditional behavior

**Subject Nodes** (define tests):
- `It(text, func)`: Defines a single test specification
- `Specify(text, func)`: Alias for It, alternative phrasing

**Setup Nodes** (manage lifecycle):
- `BeforeEach(func)`: Runs before each It block (setup)
- `AfterEach(func)`: Runs after each It block (cleanup)
- `BeforeSuite(func)`: Runs once before entire suite
- `AfterSuite(func)`: Runs once after entire suite
- `JustBeforeEach(func)`: Runs after BeforeEach but before It (useful for complex setups)
- `JustAfterEach(func)`: Runs after It but before AfterEach

### 2. Gomega Matchers

Gomega is a matcher/assertion library providing expressive, readable assertions:

**Core Matcher Pattern:**
```go
Expect(actual).To(matcher)
Expect(actual).NotTo(matcher)
Expect(actual).ToNot(matcher)  // Alias for NotTo
```

**Common Matchers:**
- `Equal(expected)`: Deep equality comparison
- `BeNil()`: Checks for nil values
- `BeTrue()` / `BeFalse()`: Boolean assertions
- `HaveLen(n)`: Checks collection length
- `ContainElement(element)`: Checks if collection contains element
- `ContainSubstring(substr)`: String containment
- `MatchRegexp(pattern)`: Regex matching
- `BeNumerically(comparator, value)`: Numeric comparisons (">", "<", ">=", etc.)
- `Succeed()`: Checks error is nil (common Go pattern)
- `MatchError(expected)`: Error matching
- `BeClosed()` / `BeSent()`: Channel operations

### 3. Async Testing

**Eventually**: Polls until condition is met or timeout occurs
```go
Eventually(func() bool {
    return condition
}).Should(BeTrue())

Eventually(func() (string, error) {
    return fetchData()
}).Should(Equal("expected"))
```

**Consistently**: Ensures condition remains true for duration
```go
Consistently(func() int {
    return counter
}).Should(Equal(0))
```

**Configuration:**
- Default timeout: 1 second
- Default polling interval: 10 milliseconds
- Customize: `Eventually(...).WithTimeout(5*time.Second).WithPolling(100*time.Millisecond)`

### 4. Table-Driven Tests

`DescribeTable` generates multiple It blocks from entries:

```go
DescribeTable("validation scenarios",
    func(input string, expectedValid bool) {
        result := Validate(input)
        Expect(result).To(Equal(expectedValid))
    },
    Entry("valid email", "user@example.com", true),
    Entry("invalid email", "notanemail", false),
    Entry("empty string", "", false),
)
```

**Entry Modifiers:**
- `FEntry`: Focused entry (runs only this)
- `PEntry` / `XEntry`: Pending entry (skips this)

### 5. Test Focus and Filtering

**Focus Tests** (run only these):
- `FDescribe`, `FContext`, `FIt`: Focused blocks
- When any F-prefixed block exists, only those run

**Pending Tests** (skip these):
- `PDescribe`, `PContext`, `PIt`: Pending blocks
- `XDescribe`, `XContext`, `XIt`: Alternative pending syntax

**Label-Based Filtering:**
```go
It("handles errors", Label("error-handling", "critical"), func() {
    // test code
})

// Run with: ginkgo --label-filter="critical"
```

### 6. Parallel Execution

Ginkgo supports parallel test execution:

```go
// Mark suite as parallelizable
var _ = BeforeSuite(func() {
    DeferCleanup(cleanup)
})

// Run with: ginkgo -p
// Or specify: ginkgo --procs=4
```

**Important**: Ensure tests are independent and avoid shared mutable state.

### 7. RegisterFailHandler Integration

The critical connection between Ginkgo and Gomega:

```go
func TestMyPackage(t *testing.T) {
    RegisterFailHandler(Fail)  // Tell Gomega to use Ginkgo's failure mechanism
    RunSpecs(t, "MyPackage Suite")
}
```

---

## Installation and Setup

### Install Ginkgo v2 and Gomega

```bash
# Install Ginkgo CLI (ensure version matches go.mod)
go install github.com/onsi/ginkgo/v2/ginkgo

# Add Ginkgo and Gomega to your project
go get github.com/onsi/ginkgo/v2
go get github.com/onsi/gomega
```

### Bootstrap a Test Suite

```bash
# Generate suite file in current package
ginkgo bootstrap

# This creates: package_name_suite_test.go
```

**Generated Suite File:**
```go
package mypackage_test

import (
    "testing"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestMyPackage(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "MyPackage Suite")
}
```

### Generate Spec Files

```bash
# Generate test file for a specific file
ginkgo generate calculator.go

# This creates: calculator_test.go
```

**Generated Spec File:**
```go
package mypackage_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    "path/to/mypackage"
)

var _ = Describe("Calculator", func() {
    // Your tests here
})
```

---

## Best Practices

### 1. Test Organization and Structure

**Organize logically with nested containers:**
```go
var _ = Describe("UserService", func() {
    Describe("Register", func() {
        Context("with valid input", func() {
            It("creates a new user", func() {
                // test implementation
            })

            It("returns user ID", func() {
                // test implementation
            })
        })

        Context("with duplicate email", func() {
            It("returns ErrDuplicateEmail", func() {
                // test implementation
            })
        })
    })

    Describe("Login", func() {
        // Login tests...
    })
})
```

**Keep tests focused and atomic:**
- Each It block tests ONE behavior
- Use descriptive text that reads as a specification
- Avoid testing multiple behaviors in single It block

### 2. Setup and Teardown

**Use BeforeEach for common setup:**
```go
var _ = Describe("Database tests", func() {
    var db *sql.DB

    BeforeEach(func() {
        db = setupTestDB()
        seedTestData(db)
    })

    AfterEach(func() {
        cleanupTestDB(db)
    })

    It("queries users correctly", func() {
        users, err := QueryUsers(db)
        Expect(err).ToNot(HaveOccurred())
        Expect(users).To(HaveLen(3))
    })
})
```

**Use DeferCleanup for resource management:**
```go
BeforeEach(func() {
    db := setupTestDB()
    DeferCleanup(func() {
        db.Close()
    })
})
```

### 3. Effective Use of Gomega Matchers

**Chain matchers for complex assertions:**
```go
Expect(response).To(And(
    HaveHTTPStatus(200),
    HaveHTTPBody(ContainSubstring("success")),
))
```

**Use Succeed() for Go error pattern:**
```go
// Instead of:
err := DoSomething()
Expect(err).To(BeNil())

// Prefer:
Expect(DoSomething()).To(Succeed())
```

**Match errors specifically:**
```go
// Match error message
Expect(err).To(MatchError("connection timeout"))

// Match error type
Expect(err).To(MatchError(ErrNotFound))

// Match error substring
Expect(err).To(MatchError(ContainSubstring("timeout")))
```

### 4. Table-Driven Tests for Multiple Scenarios

**Use DescribeTable for parametrized tests:**
```go
DescribeTable("password validation",
    func(password string, expectValid bool, expectedError string) {
        valid, err := ValidatePassword(password)
        Expect(valid).To(Equal(expectValid))
        if expectedError != "" {
            Expect(err).To(MatchError(ContainSubstring(expectedError)))
        }
    },
    Entry("valid strong password", "Str0ng!Pass", true, ""),
    Entry("too short", "weak", false, "at least 8 characters"),
    Entry("no special chars", "Password123", false, "special character"),
    Entry("no numbers", "Password!", false, "digit"),
)
```

### 5. Async Testing Patterns

**Test goroutine completion:**
```go
It("processes items asynchronously", func() {
    done := make(chan bool)
    go func() {
        defer GinkgoRecover()  // Important for goroutine failures
        ProcessItems()
        done <- true
    }()

    Eventually(done).Should(Receive())
})
```

**Poll for state changes:**
```go
It("cache expires after timeout", func() {
    cache.Set("key", "value", 1*time.Second)

    Eventually(func() bool {
        _, exists := cache.Get("key")
        return exists
    }).Should(BeFalse())
})
```

**Verify consistent behavior:**
```go
It("counter remains stable", func() {
    counter := NewCounter()

    Consistently(func() int {
        return counter.Value()
    }).WithTimeout(2 * time.Second).Should(Equal(0))
})
```

### 6. Custom Matchers for Domain Logic

**Create reusable domain-specific matchers:**
```go
func BeValidUser() types.GomegaMatcher {
    return WithTransform(func(u User) bool {
        return u.ID > 0 && u.Email != "" && u.CreatedAt.After(time.Time{})
    }, BeTrue())
}

// Usage:
It("creates valid user", func() {
    user := CreateUser("test@example.com")
    Expect(user).To(BeValidUser())
})
```

### 7. Handling Test Dependencies

**Use JustBeforeEach for deferred execution:**
```go
var _ = Describe("User API", func() {
    var response *http.Response
    var requestBody string

    BeforeEach(func() {
        // Set default request body
        requestBody = `{"email": "test@example.com"}`
    })

    JustBeforeEach(func() {
        // Make request after Context has chance to modify requestBody
        response = makeRequest("/users", requestBody)
    })

    Context("with valid data", func() {
        It("returns 201", func() {
            Expect(response.StatusCode).To(Equal(201))
        })
    })

    Context("with invalid JSON", func() {
        BeforeEach(func() {
            requestBody = `{invalid}`  // Override default
        })

        It("returns 400", func() {
            Expect(response.StatusCode).To(Equal(400))
        })
    })
})
```

### 8. Testing with Mocks

**Integration with gomock:**
```go
var _ = Describe("ServiceLayer", func() {
    var mockCtrl *gomock.Controller
    var mockRepo *MockRepository
    var service *Service

    BeforeEach(func() {
        mockCtrl = gomock.NewController(GinkgoT())
        mockRepo = NewMockRepository(mockCtrl)
        service = NewService(mockRepo)
    })

    AfterEach(func() {
        mockCtrl.Finish()
    })

    It("fetches user from repository", func() {
        expectedUser := User{ID: 1, Email: "test@example.com"}
        mockRepo.EXPECT().GetUser(1).Return(expectedUser, nil)

        user, err := service.GetUser(1)
        Expect(err).ToNot(HaveOccurred())
        Expect(user).To(Equal(expectedUser))
    })
})
```

### 9. Separate Test Files from Implementation

**Use _test package for black-box testing:**
```go
// calculator.go
package calculator

func Add(a, b int) int { return a + b }

// calculator_test.go
package calculator_test  // Note: separate package

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    "myproject/calculator"
)

var _ = Describe("Calculator", func() {
    It("adds numbers", func() {
        Expect(calculator.Add(2, 3)).To(Equal(5))
    })
})
```

---

## Common Pitfalls

### 1. Not Using RegisterFailHandler

**Problem:**
```go
func TestSomething(t *testing.T) {
    // Missing RegisterFailHandler(Fail)
    RunSpecs(t, "Suite")
}
```

**Impact**: Gomega assertions won't fail tests properly. Tests will pass even when assertions fail.

**Solution**: Always call `RegisterFailHandler(Fail)` before `RunSpecs`:
```go
func TestSomething(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Suite")
}
```

### 2. Shared Mutable State Between Tests

**Problem:**
```go
var sharedCounter int  // Shared across tests!

var _ = Describe("Counter", func() {
    It("increments", func() {
        sharedCounter++
        Expect(sharedCounter).To(Equal(1))  // Fails if tests run out of order
    })
})
```

**Impact**: Tests fail randomly, especially when run in parallel or different order.

**Solution**: Initialize in BeforeEach:
```go
var _ = Describe("Counter", func() {
    var counter int  // Declare here

    BeforeEach(func() {
        counter = 0  // Initialize for each test
    })

    It("increments", func() {
        counter++
        Expect(counter).To(Equal(1))
    })
})
```

### 3. Testing Multiple Behaviors in One It Block

**Problem:**
```go
It("handles user registration", func() {
    user := Register("test@example.com", "password")
    Expect(user.Email).To(Equal("test@example.com"))  // Test 1

    Expect(Login(user.Email, "password")).To(Succeed())  // Test 2 - Different behavior!

    Expect(GetUserCount()).To(Equal(1))  // Test 3 - Different behavior!
})
```

**Impact**: Hard to identify which behavior failed. Poor test organization.

**Solution**: One behavior per It block:
```go
Describe("User registration", func() {
    It("creates user with correct email", func() {
        user := Register("test@example.com", "password")
        Expect(user.Email).To(Equal("test@example.com"))
    })

    It("allows login after registration", func() {
        user := Register("test@example.com", "password")
        Expect(Login(user.Email, "password")).To(Succeed())
    })

    It("increments user count", func() {
        initialCount := GetUserCount()
        Register("test@example.com", "password")
        Expect(GetUserCount()).To(Equal(initialCount + 1))
    })
})
```

### 4. Not Using DeferCleanup for Resources

**Problem:**
```go
BeforeEach(func() {
    db := setupTestDB()
    // What if test panics? DB never cleaned up
})

AfterEach(func() {
    cleanupTestDB(db)  // db not in scope!
})
```

**Impact**: Resource leaks, scope issues, cleanup doesn't run on panics.

**Solution**: Use DeferCleanup:
```go
BeforeEach(func() {
    db := setupTestDB()
    DeferCleanup(func() {
        cleanupTestDB(db)
    })
})
```

### 5. Forgetting GinkgoRecover in Goroutines

**Problem:**
```go
It("runs async", func() {
    go func() {
        Expect(something).To(BeTrue())  // Panic won't be caught!
    }()
})
```

**Impact**: Goroutine panics don't fail the test. Silent failures.

**Solution**: Use GinkgoRecover:
```go
It("runs async", func() {
    done := make(chan bool)
    go func() {
        defer GinkgoRecover()  // Critical!
        Expect(something).To(BeTrue())
        done <- true
    }()
    Eventually(done).Should(Receive())
})
```

### 6. Incorrect Eventually Timeout Values

**Problem:**
```go
Eventually(func() bool {
    return longRunningOperation()  // Takes 5 seconds
}).Should(BeTrue())  // Default timeout: 1 second - will fail!
```

**Impact**: Flaky tests that fail intermittently based on timing.

**Solution**: Set appropriate timeouts:
```go
Eventually(func() bool {
    return longRunningOperation()
}).WithTimeout(10*time.Second).WithPolling(500*time.Millisecond).Should(BeTrue())
```

### 7. Not Running Tests in Reproducibly Random Order

**Problem**: Running tests in same order every time masks dependency issues.

**Solution**: Ginkgo randomizes by default. To reproduce specific order:
```bash
# Ginkgo prints seed for each run
ginkgo --seed=1234
```

### 8. Overusing Focused Tests in Version Control

**Problem**: Committing FDescribe, FIt blocks means only those tests run in CI.

**Solution**:
- Use focus during development only
- Remove before committing
- Configure CI to fail on focused tests: `ginkgo --fail-on-focused`

---

## Tools and Libraries

### Core Testing Stack (2024-2025)

1. **Ginkgo v2** - `github.com/onsi/ginkgo/v2`
   - BDD testing framework
   - Parallel execution
   - Rich CLI tools
   - Current stable: v2.x

2. **Gomega** - `github.com/onsi/gomega`
   - Matcher library
   - Async testing (Eventually, Consistently)
   - Extensive matcher collection
   - Integrates seamlessly with Ginkgo

### Mocking Libraries

3. **gomock** - `github.com/golang/mock`
   - Official Go mocking framework
   - Generate mocks from interfaces
   - Install: `go install github.com/golang/mock/mockgen@latest`

4. **testify/mock** - `github.com/stretchr/testify/mock`
   - Alternative mocking library
   - Less boilerplate than gomock
   - Good for simple mocking needs

### HTTP Testing

5. **httptest** - `net/http/httptest` (stdlib)
   - Test HTTP handlers
   - Mock HTTP servers and responses
   - No external dependencies

6. **ghttp** - `github.com/onsi/gomega/ghttp`
   - Gomega's HTTP testing helpers
   - Mock HTTP servers with assertions
   - Fluent API for request/response verification

### Database Testing

7. **go-sqlmock** - `github.com/DATA-DOG/go-sqlmock`
   - Mock SQL database connections
   - Test database interactions without real DB
   - Works with database/sql

8. **dockertest** - `github.com/ory/dockertest`
   - Spin up Docker containers for integration tests
   - Test against real databases (Postgres, MySQL, etc.)
   - Cleanup after tests

### Code Coverage

9. **ginkgo CLI** - Built-in coverage support
   ```bash
   ginkgo -cover
   ginkgo -coverprofile=coverage.out
   go tool cover -html=coverage.out
   ```

### Continuous Testing

10. **ginkgo watch** - Built-in file watcher
    ```bash
    ginkgo watch -notify
    ```
    Automatically reruns tests on file changes

---

## Examples

### Example 1: Basic Unit Test

```go
// calculator.go
package calculator

func Add(a, b int) int {
    return a + b
}

func Divide(a, b int) (int, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}

// calculator_test.go
package calculator_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    "myproject/calculator"
)

var _ = Describe("Calculator", func() {
    Describe("Add", func() {
        It("adds two positive numbers", func() {
            Expect(calculator.Add(2, 3)).To(Equal(5))
        })

        It("adds negative numbers", func() {
            Expect(calculator.Add(-2, -3)).To(Equal(-5))
        })
    })

    Describe("Divide", func() {
        Context("with non-zero divisor", func() {
            It("divides successfully", func() {
                result, err := calculator.Divide(10, 2)
                Expect(err).ToNot(HaveOccurred())
                Expect(result).To(Equal(5))
            })
        })

        Context("with zero divisor", func() {
            It("returns division by zero error", func() {
                _, err := calculator.Divide(10, 0)
                Expect(err).To(MatchError("division by zero"))
            })
        })
    })
})
```

### Example 2: Table-Driven Test

```go
var _ = Describe("Email Validation", func() {
    DescribeTable("validates email addresses",
        func(email string, expectedValid bool) {
            valid := ValidateEmail(email)
            Expect(valid).To(Equal(expectedValid))
        },
        Entry("valid standard email", "user@example.com", true),
        Entry("valid with subdomain", "user@mail.example.com", true),
        Entry("valid with plus", "user+tag@example.com", true),
        Entry("invalid missing @", "userexample.com", false),
        Entry("invalid missing domain", "user@", false),
        Entry("invalid empty", "", false),
        Entry("invalid spaces", "user @example.com", false),
    )
})
```

### Example 3: Async Testing

```go
var _ = Describe("Message Queue", func() {
    var queue *MessageQueue

    BeforeEach(func() {
        queue = NewMessageQueue()
        DeferCleanup(queue.Close)
    })

    It("processes messages asynchronously", func() {
        messages := []string{"msg1", "msg2", "msg3"}
        processed := make([]string, 0)
        var mu sync.Mutex

        queue.Subscribe(func(msg string) {
            mu.Lock()
            defer mu.Unlock()
            processed = append(processed, msg)
        })

        for _, msg := range messages {
            queue.Publish(msg)
        }

        Eventually(func() int {
            mu.Lock()
            defer mu.Unlock()
            return len(processed)
        }).Should(Equal(3))

        Expect(processed).To(ConsistOf(messages))
    })

    It("maintains order with single consumer", func() {
        received := make([]string, 0)
        var mu sync.Mutex

        queue.Subscribe(func(msg string) {
            mu.Lock()
            defer mu.Unlock()
            received = append(received, msg)
        })

        expected := []string{"first", "second", "third"}
        for _, msg := range expected {
            queue.Publish(msg)
        }

        Eventually(func() []string {
            mu.Lock()
            defer mu.Unlock()
            return received
        }).Should(Equal(expected))
    })
})
```

### Example 4: HTTP Handler Testing

```go
var _ = Describe("User Handler", func() {
    var handler *UserHandler
    var mockUserService *MockUserService
    var recorder *httptest.ResponseRecorder

    BeforeEach(func() {
        mockUserService = NewMockUserService()
        handler = NewUserHandler(mockUserService)
        recorder = httptest.NewRecorder()
    })

    Describe("GET /users/:id", func() {
        Context("when user exists", func() {
            It("returns user JSON", func() {
                expectedUser := User{ID: 1, Email: "test@example.com"}
                mockUserService.GetUserFunc = func(id int) (User, error) {
                    return expectedUser, nil
                }

                req := httptest.NewRequest("GET", "/users/1", nil)
                handler.GetUser(recorder, req)

                Expect(recorder.Code).To(Equal(200))
                Expect(recorder.Header().Get("Content-Type")).To(Equal("application/json"))

                var responseUser User
                err := json.Unmarshal(recorder.Body.Bytes(), &responseUser)
                Expect(err).ToNot(HaveOccurred())
                Expect(responseUser).To(Equal(expectedUser))
            })
        })

        Context("when user not found", func() {
            It("returns 404", func() {
                mockUserService.GetUserFunc = func(id int) (User, error) {
                    return User{}, ErrUserNotFound
                }

                req := httptest.NewRequest("GET", "/users/999", nil)
                handler.GetUser(recorder, req)

                Expect(recorder.Code).To(Equal(404))
            })
        })
    })
})
```

### Example 5: Database Integration Test

```go
var _ = Describe("UserRepository", func() {
    var db *sql.DB
    var repo *UserRepository

    BeforeSuite(func() {
        // Setup test database (use dockertest or test DB)
        db = setupTestDatabase()
    })

    AfterSuite(func() {
        db.Close()
    })

    BeforeEach(func() {
        // Clear and seed data for each test
        clearDatabase(db)
        repo = NewUserRepository(db)
    })

    Describe("Create", func() {
        It("inserts user into database", func() {
            user := User{Email: "test@example.com", Name: "Test User"}

            err := repo.Create(&user)
            Expect(err).ToNot(HaveOccurred())
            Expect(user.ID).To(BeNumerically(">", 0))

            // Verify in database
            var count int
            db.QueryRow("SELECT COUNT(*) FROM users WHERE email = ?", user.Email).Scan(&count)
            Expect(count).To(Equal(1))
        })

        It("returns error on duplicate email", func() {
            user1 := User{Email: "test@example.com", Name: "User 1"}
            user2 := User{Email: "test@example.com", Name: "User 2"}

            Expect(repo.Create(&user1)).To(Succeed())

            err := repo.Create(&user2)
            Expect(err).To(HaveOccurred())
            Expect(err).To(MatchError(ContainSubstring("duplicate")))
        })
    })

    Describe("FindByID", func() {
        It("retrieves existing user", func() {
            original := User{Email: "test@example.com", Name: "Test User"}
            repo.Create(&original)

            found, err := repo.FindByID(original.ID)
            Expect(err).ToNot(HaveOccurred())
            Expect(found.Email).To(Equal(original.Email))
            Expect(found.Name).To(Equal(original.Name))
        })

        It("returns error for non-existent user", func() {
            _, err := repo.FindByID(99999)
            Expect(err).To(MatchError(ErrUserNotFound))
        })
    })
})
```

### Example 6: Custom Matcher

```go
// custom_matchers.go
package matchers

import (
    "fmt"
    "github.com/onsi/gomega/types"
)

func HaveValidationError(field string) types.GomegaMatcher {
    return &validationErrorMatcher{
        expectedField: field,
    }
}

type validationErrorMatcher struct {
    expectedField string
}

func (m *validationErrorMatcher) Match(actual interface{}) (bool, error) {
    err, ok := actual.(ValidationError)
    if !ok {
        return false, fmt.Errorf("expected ValidationError, got %T", actual)
    }

    for _, fieldErr := range err.Errors {
        if fieldErr.Field == m.expectedField {
            return true, nil
        }
    }
    return false, nil
}

func (m *validationErrorMatcher) FailureMessage(actual interface{}) string {
    return fmt.Sprintf("Expected validation error for field '%s', but it was not present", m.expectedField)
}

func (m *validationErrorMatcher) NegatedFailureMessage(actual interface{}) string {
    return fmt.Sprintf("Expected no validation error for field '%s', but it was present", m.expectedField)
}

// Usage in tests:
var _ = Describe("Validation", func() {
    It("validates required fields", func() {
        input := UserInput{Email: ""}
        err := ValidateUser(input)

        Expect(err).To(HaveValidationError("email"))
    })
})
```

---

## Quick Reference

### Installation
```bash
go install github.com/onsi/ginkgo/v2/ginkgo
go get github.com/onsi/ginkgo/v2
go get github.com/onsi/gomega
```

### Bootstrapping
```bash
ginkgo bootstrap              # Create suite file
ginkgo generate filename.go   # Generate spec file
```

### Running Tests
```bash
ginkgo                        # Run all tests
ginkgo -v                     # Verbose output
ginkgo -p                     # Parallel execution
ginkgo --procs=4              # Specify number of processes
ginkgo -r                     # Recursive (all packages)
ginkgo --focus="pattern"      # Run tests matching pattern
ginkgo --skip="pattern"       # Skip tests matching pattern
ginkgo --label-filter="label" # Run tests with specific label
ginkgo --seed=1234            # Reproduce specific test order
ginkgo watch                  # Watch mode - rerun on changes
ginkgo --fail-on-focused      # Fail if focused tests present
```

### Coverage
```bash
ginkgo -cover                              # Show coverage summary
ginkgo -coverprofile=coverage.out          # Generate coverage profile
go tool cover -html=coverage.out           # View HTML coverage report
```

### Test Structure Template
```go
var _ = Describe("Component", func() {
    var variable Type

    BeforeEach(func() {
        // Setup for each test
        variable = Initialize()
        DeferCleanup(func() {
            // Cleanup
        })
    })

    Describe("Feature", func() {
        Context("scenario description", func() {
            It("specific behavior", func() {
                // Test code
                Expect(result).To(matcher)
            })
        })
    })
})
```

### Common Matchers
```go
Expect(x).To(Equal(y))                    // Deep equality
Expect(x).To(BeNil())                     // Nil check
Expect(x).To(BeTrue() / BeFalse())        // Boolean
Expect(x).To(HaveLen(n))                  // Length
Expect(x).To(ContainElement(e))           // Collection contains
Expect(x).To(ContainSubstring(s))         // String contains
Expect(x).To(MatchRegexp(pattern))        // Regex match
Expect(x).To(BeNumerically(">", y))       // Numeric comparison
Expect(err).To(Succeed())                 // err == nil
Expect(err).To(MatchError(expected))      // Error matching
Expect(ch).To(BeClosed())                 // Channel closed
Expect(ch).To(Receive())                  // Channel receive
```

### Async Testing
```go
Eventually(func() T {
    return value
}).Should(matcher)

Eventually(func() T {
    return value
}).WithTimeout(5*time.Second).WithPolling(100*time.Millisecond).Should(matcher)

Consistently(func() T {
    return value
}).Should(matcher)
```

### Table-Driven Tests
```go
DescribeTable("description",
    func(input T, expected U) {
        // Test body
    },
    Entry("case 1", input1, expected1),
    Entry("case 2", input2, expected2),
    FEntry("focused entry", input3, expected3),
    PEntry("pending entry", input4, expected4),
)
```

### Focus and Skip
```go
FDescribe / FContext / FIt    // Run only focused tests
PDescribe / PContext / PIt    // Skip pending tests
XDescribe / XContext / XIt    // Skip (alternative syntax)
```

### Suite Hooks
```go
BeforeSuite(func() { /* runs once before all tests */ })
AfterSuite(func() { /* runs once after all tests */ })
BeforeEach(func() { /* runs before each It */ })
JustBeforeEach(func() { /* runs after BeforeEach, before It */ })
AfterEach(func() { /* runs after each It */ })
JustAfterEach(func() { /* runs after It, before AfterEach */ })
```

### Goroutine Testing
```go
It("test", func() {
    done := make(chan bool)
    go func() {
        defer GinkgoRecover()  // Critical for catching failures
        // Test code
        done <- true
    }()
    Eventually(done).Should(Receive())
})
```

---

**For More Information:**
- Official Ginkgo Documentation: https://onsi.github.io/ginkgo/
- Official Gomega Documentation: https://onsi.github.io/gomega/
- Ginkgo GitHub: https://github.com/onsi/ginkgo
- Gomega GitHub: https://github.com/onsi/gomega
