# Spring Framework Quick Reference

## Overview

This quick reference provides a comprehensive lookup for Spring annotations, common patterns, and configuration options. Use this as a cheat sheet when building Spring Boot applications.

---

## Spring Core Annotations

### Component Scanning

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Component | Generic Spring bean | General purpose components |
| @Service | Service layer bean | Business logic classes |
| @Repository | Data access bean | DAO/Repository classes |
| @Controller | Web controller | MVC controllers |
| @RestController | REST API controller | @Controller + @ResponseBody |
| @Configuration | Configuration class | Bean definitions |

### Dependency Injection

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Autowired | Inject dependency | Field, constructor, setter injection |
| @Qualifier | Specify bean by name | When multiple beans of same type exist |
| @Primary | Default bean | Mark preferred bean when multiple exist |
| @Value | Inject property value | @Value("${app.name}") |
| @Lazy | Lazy initialization | Defer bean creation until needed |
| @Scope | Bean scope | singleton, prototype, request, session |

### Configuration

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Bean | Define bean in @Configuration | Factory methods for beans |
| @ComponentScan | Scan for components | Specify packages to scan |
| @PropertySource | Load properties file | @PropertySource("classpath:app.properties") |
| @ConfigurationProperties | Bind properties to class | Type-safe configuration |
| @EnableConfigurationProperties | Enable @ConfigurationProperties | Register config classes |
| @Profile | Profile-specific bean | dev, test, prod environments |
| @Conditional | Conditional bean creation | @ConditionalOnProperty, @ConditionalOnBean |

---

## Spring Web Annotations

### Request Mapping

| Annotation | Purpose | HTTP Method |
|-----------|---------|-------------|
| @RequestMapping | Map URL to method | Any (can specify) |
| @GetMapping | Handle GET requests | GET |
| @PostMapping | Handle POST requests | POST |
| @PutMapping | Handle PUT requests | PUT |
| @PatchMapping | Handle PATCH requests | PATCH |
| @DeleteMapping | Handle DELETE requests | DELETE |

### Request Parameters

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @PathVariable | Extract from URL path | /users/{id} → @PathVariable Long id |
| @RequestParam | Extract query parameter | /search?q=term → @RequestParam String q |
| @RequestBody | Parse request body | @RequestBody CreateUserRequest request |
| @RequestHeader | Extract header value | @RequestHeader("Authorization") String token |
| @CookieValue | Extract cookie value | @CookieValue("sessionId") String session |

### Response Handling

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @ResponseBody | Return object as HTTP response body | Automatically converts to JSON |
| @ResponseStatus | Set HTTP status code | @ResponseStatus(HttpStatus.CREATED) |
| @ExceptionHandler | Handle exceptions | Method-level exception handling |
| @RestControllerAdvice | Global exception handler | Class-level for all controllers |
| @ControllerAdvice | Global controller enhancements | Exception handling, model attributes |

---

## Spring Data JPA Annotations

### Entity Mapping

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Entity | JPA entity | Marks class as database table |
| @Table | Specify table details | @Table(name = "users") |
| @Id | Primary key | @Id @GeneratedValue |
| @GeneratedValue | Auto-generate ID | strategy = GenerationType.IDENTITY |
| @Column | Column details | @Column(name = "email", unique = true) |
| @Transient | Exclude from persistence | Non-persistent fields |
| @Enumerated | Enum mapping | @Enumerated(EnumType.STRING) |
| @Temporal | Date/time mapping | @Temporal(TemporalType.TIMESTAMP) |
| @Lob | Large object | BLOB/CLOB columns |

### Relationships

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @OneToOne | One-to-one relationship | User ↔ UserProfile |
| @OneToMany | One-to-many relationship | Customer → Orders |
| @ManyToOne | Many-to-one relationship | Order → Customer |
| @ManyToMany | Many-to-many relationship | Students ↔ Courses |
| @JoinColumn | Foreign key column | @JoinColumn(name = "customer_id") |
| @JoinTable | Join table for @ManyToMany | Specify join table details |
| @MapsId | Share primary key | One-to-one with shared ID |

### Query and Performance

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Query | Custom JPQL/SQL query | @Query("SELECT u FROM User u WHERE ...") |
| @Modifying | Modifying query (UPDATE/DELETE) | Used with @Query |
| @EntityGraph | Fetch strategy | Avoid N+1 queries |
| @NamedQuery | Named query | Define at entity level |
| @QueryHints | JPA query hints | Caching, fetch size, etc. |

---

## Spring Transaction Annotations

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @Transactional | Transaction management | Method or class level |
| @EnableTransactionManagement | Enable transactions | Configuration class |

### @Transactional Attributes

| Attribute | Options | Default |
|-----------|---------|---------|
| propagation | REQUIRED, REQUIRES_NEW, NESTED, etc. | REQUIRED |
| isolation | READ_UNCOMMITTED, READ_COMMITTED, REPEATABLE_READ, SERIALIZABLE | DEFAULT (database default) |
| readOnly | true, false | false |
| timeout | seconds | -1 (no timeout) |
| rollbackFor | Exception classes | RuntimeException |
| noRollbackFor | Exception classes | None |

---

## Spring Security Annotations

### Method Security

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @EnableMethodSecurity | Enable method security | Configuration class |
| @PreAuthorize | Check before method execution | @PreAuthorize("hasRole('ADMIN')") |
| @PostAuthorize | Check after method execution | @PostAuthorize("returnObject.owner == authentication.name") |
| @Secured | Simple role check | @Secured("ROLE_ADMIN") |
| @RolesAllowed | JSR-250 role check | @RolesAllowed({"ADMIN", "USER"}) |
| @PreFilter | Filter method parameters | Filter collections before execution |
| @PostFilter | Filter return value | Filter returned collections |

### Security Configuration

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @EnableWebSecurity | Enable web security | Configuration class |
| @EnableGlobalMethodSecurity | Enable method security (deprecated) | Use @EnableMethodSecurity |

---

## Validation Annotations

### Bean Validation (jakarta.validation.constraints)

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @NotNull | Field cannot be null | @NotNull String name |
| @NotBlank | String not null/empty/whitespace | @NotBlank String email |
| @NotEmpty | Collection/String not null/empty | @NotEmpty List<String> tags |
| @Size | Size constraints | @Size(min = 2, max = 100) |
| @Min | Minimum numeric value | @Min(0) |
| @Max | Maximum numeric value | @Max(100) |
| @DecimalMin | Minimum decimal value | @DecimalMin("0.01") |
| @DecimalMax | Maximum decimal value | @DecimalMax("999999.99") |
| @Email | Valid email format | @Email String email |
| @Pattern | Regex pattern | @Pattern(regexp = "...") |
| @Past | Date in past | @Past LocalDate birthDate |
| @Future | Date in future | @Future LocalDate expiryDate |
| @PastOrPresent | Date in past or present | @PastOrPresent LocalDate date |
| @FutureOrPresent | Date in future or present | @FutureOrPresent LocalDate date |
| @Positive | Positive number | @Positive Integer quantity |
| @PositiveOrZero | Positive or zero | @PositiveOrZero Integer count |
| @Negative | Negative number | @Negative Integer adjustment |
| @NegativeOrZero | Negative or zero | @NegativeOrZero Integer balance |
| @Valid | Nested object validation | @Valid Address address |

---

## Spring Boot Annotations

| Annotation | Purpose | Example |
|-----------|---------|---------|
| @SpringBootApplication | Main application class | Combines @Configuration, @EnableAutoConfiguration, @ComponentScan |
| @EnableAutoConfiguration | Enable auto-configuration | Usually via @SpringBootApplication |
| @SpringBootTest | Integration test | Full application context |
| @WebMvcTest | Test web layer | Controller tests |
| @DataJpaTest | Test JPA layer | Repository tests |
| @MockBean | Mock bean in tests | Replace real bean with mock |
| @TestConfiguration | Test-specific configuration | Additional beans for tests |

---

## Common Patterns

### REST Controller Pattern

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Validated
public class UserController {
    private final UserService userService;

    @GetMapping("/{id}")
    public ResponseEntity<UserDto> getUser(@PathVariable Long id) {
        return ResponseEntity.ok(userService.findById(id));
    }

    @PostMapping
    public ResponseEntity<UserDto> createUser(@Valid @RequestBody CreateUserRequest request) {
        UserDto created = userService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }
}
```

### Service Layer Pattern

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {
    private final UserRepository userRepository;

    public UserDto findById(Long id) {
        return userRepository.findById(id)
            .map(this::toDto)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    @Transactional
    public UserDto create(CreateUserRequest request) {
        User user = toEntity(request);
        User saved = userRepository.save(user);
        return toDto(saved);
    }
}
```

### Repository Pattern

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByLastName(String lastName);

    @Query("SELECT u FROM User u WHERE u.active = true")
    List<User> findActiveUsers();
}
```

### Configuration Properties Pattern

```java
@Configuration
@ConfigurationProperties(prefix = "app")
@Validated
public class AppProperties {
    @NotBlank
    private String name;

    @NotNull
    private Duration timeout;

    private int maxConnections = 10;

    // Nested configuration
    private Security security = new Security();

    public static class Security {
        private boolean enabled = true;
        private String secretKey;
        // getters/setters
    }

    // getters/setters
}
```

### Exception Handler Pattern

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(
            MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors()
            .forEach(error -> errors.put(error.getField(), error.getDefaultMessage()));

        return ResponseEntity.badRequest()
            .body(new ErrorResponse("Validation failed", errors));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(new ErrorResponse(ex.getMessage()));
    }
}
```

---

## Application Properties Reference

### Common Properties

```yaml
# Server
server:
  port: 8080
  servlet:
    context-path: /api

# DataSource
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/mydb
    username: user
    password: ${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000

  # JPA
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        format_sql: true
        dialect: org.hibernate.dialect.MySQL8Dialect
        default_batch_fetch_size: 20

  # Flyway
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

  # Jackson
  jackson:
    serialization:
      write-dates-as-timestamps: false
    deserialization:
      fail-on-unknown-properties: false
    default-property-inclusion: non_null

  # Security
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com

# Logging
logging:
  level:
    root: INFO
    com.example: DEBUG
    org.hibernate.SQL: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"

# Management (Actuator)
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
```

---

## HTTP Status Codes

### Success (2xx)

| Code | Name | Usage |
|------|------|-------|
| 200 | OK | Standard success response |
| 201 | Created | Resource created (POST) |
| 204 | No Content | Success with no response body (DELETE) |

### Client Error (4xx)

| Code | Name | Usage |
|------|------|-------|
| 400 | Bad Request | Invalid request/validation failure |
| 401 | Unauthorized | Authentication required |
| 403 | Forbidden | Not authorized |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Business rule violation |
| 422 | Unprocessable Entity | Semantic validation failure |

### Server Error (5xx)

| Code | Name | Usage |
|------|------|-------|
| 500 | Internal Server Error | Unexpected error |
| 503 | Service Unavailable | Service temporarily down |

---

## REST API Conventions

### Endpoint Naming

| Operation | HTTP Method | Path | Description |
|-----------|------------|------|-------------|
| List | GET | /api/v1/users | Get all users |
| Get | GET | /api/v1/users/{id} | Get user by ID |
| Create | POST | /api/v1/users | Create new user |
| Update | PUT | /api/v1/users/{id} | Replace user |
| Partial Update | PATCH | /api/v1/users/{id} | Update specific fields |
| Delete | DELETE | /api/v1/users/{id} | Delete user |
| Search | GET | /api/v1/users?search=term | Search users |
| Action | POST | /api/v1/users/{id}/activate | Perform action |

### Pagination Parameters

```
GET /api/v1/products?page=0&size=20&sort=name,asc

Response:
{
  "content": [...],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 20
  },
  "totalPages": 10,
  "totalElements": 200,
  "last": false,
  "first": true
}
```

---

## Spring Data JPA Query Methods

### Keywords

| Keyword | SQL Equivalent |
|---------|---------------|
| And | WHERE x = ? AND y = ? |
| Or | WHERE x = ? OR y = ? |
| Is, Equals | WHERE x = ? |
| Between | WHERE x BETWEEN ? AND ? |
| LessThan | WHERE x < ? |
| GreaterThan | WHERE x > ? |
| After | WHERE x > ? |
| Before | WHERE x < ? |
| IsNull | WHERE x IS NULL |
| IsNotNull | WHERE x IS NOT NULL |
| Like | WHERE x LIKE ? |
| NotLike | WHERE x NOT LIKE ? |
| StartingWith | WHERE x LIKE ?% |
| EndingWith | WHERE x LIKE %? |
| Containing | WHERE x LIKE %?% |
| OrderBy | ORDER BY x |
| Not | WHERE x <> ? |
| In | WHERE x IN (?) |
| NotIn | WHERE x NOT IN (?) |
| True | WHERE x = true |
| False | WHERE x = false |

---

## Transaction Propagation

| Propagation | Behavior |
|------------|----------|
| REQUIRED | Use existing transaction or create new (default) |
| REQUIRES_NEW | Always create new transaction, suspend existing |
| NESTED | Create savepoint in existing transaction |
| SUPPORTS | Use transaction if exists, otherwise non-transactional |
| NOT_SUPPORTED | Execute non-transactionally, suspend existing |
| NEVER | Execute non-transactionally, error if transaction exists |
| MANDATORY | Must run within existing transaction, error otherwise |

---

## Common Bean Scopes

| Scope | Description | Use Case |
|-------|-------------|----------|
| singleton | One instance per container | Stateless services (default) |
| prototype | New instance every time | Stateful objects |
| request | One per HTTP request | Web request-specific data |
| session | One per HTTP session | User session data |
| application | One per ServletContext | Application-wide singletons |

---

## Lombok Annotations

| Annotation | Purpose |
|-----------|---------|
| @Data | @Getter + @Setter + @ToString + @EqualsAndHashCode + @RequiredArgsConstructor |
| @Getter | Generate getters |
| @Setter | Generate setters |
| @ToString | Generate toString() |
| @EqualsAndHashCode | Generate equals() and hashCode() |
| @NoArgsConstructor | Generate no-args constructor |
| @AllArgsConstructor | Generate constructor with all fields |
| @RequiredArgsConstructor | Generate constructor for final fields |
| @Builder | Generate builder pattern |
| @Slf4j | Generate logger field |
| @Value | Immutable @Data (all fields final) |

---

## Summary

This reference covers:

- **Core annotations** for components, DI, and configuration
- **Web annotations** for REST controllers
- **Data annotations** for JPA entities and repositories
- **Transaction management** with @Transactional
- **Security annotations** for authorization
- **Validation annotations** for input validation
- **Common patterns** for controllers, services, repositories
- **Configuration properties** for Spring Boot
- **HTTP conventions** for REST APIs
- **Query keywords** for Spring Data JPA
- **Bean scopes** and lifecycle

Use this as a quick lookup when developing Spring Boot applications.
