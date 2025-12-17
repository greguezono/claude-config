# Spring Core Patterns: REST API, Dependency Injection, and Spring Data

## Overview

This guide covers the three foundational Spring Boot patterns: REST API development with `@RestController`, dependency injection with constructor injection, and data access with Spring Data JPA. These patterns form the backbone of modern Spring Boot applications.

---

## Part 1: REST API Patterns

### Basic Controller Structure

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor  // Lombok generates constructor
public class UserController {
    private final UserService userService;

    @GetMapping
    public ResponseEntity<Page<UserDTO>> getUsers(Pageable pageable) {
        return ResponseEntity.ok(userService.findAll(pageable));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserDTO> getUser(@PathVariable Long id) {
        return userService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<UserDTO> createUser(@Valid @RequestBody CreateUserRequest request) {
        UserDTO created = userService.create(request);
        URI location = URI.create("/api/v1/users/" + created.getId());
        return ResponseEntity.created(location).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserDTO> updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return ResponseEntity.ok(userService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

### Request Validation

```java
public record CreateUserRequest(
    @NotBlank(message = "Username required")
    @Size(min = 3, max = 50)
    String username,

    @NotBlank @Email
    String email,

    @NotBlank
    @Size(min = 8, message = "Password must be at least 8 characters")
    String password,

    @Min(18) @Max(120)
    Integer age
) {}
```

### Global Exception Handling

```java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(
            ResourceNotFoundException ex, WebRequest request) {
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.NOT_FOUND.value())
            .error("Not Found")
            .message(ex.getMessage())
            .path(extractPath(request))
            .build();
        return new ResponseEntity<>(error, HttpStatus.NOT_FOUND);
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {

        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
            errors.put(error.getField(), error.getDefaultMessage())
        );

        ValidationErrorResponse response = ValidationErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error("Validation Failed")
            .fieldErrors(errors)
            .path(extractPath(request))
            .build();

        return new ResponseEntity<>(response, HttpStatus.BAD_REQUEST);
    }

    private String extractPath(WebRequest request) {
        return request.getDescription(false).replace("uri=", "");
    }
}
```

---

## Part 2: Dependency Injection Patterns

### Constructor Injection (Recommended)

```java
@Service
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    // @Autowired optional for single constructor since Spring 4.3
    public UserService(UserRepository userRepository,
                      EmailService emailService,
                      PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.emailService = emailService;
        this.passwordEncoder = passwordEncoder;
    }

    public UserDTO create(CreateUserRequest request) {
        User user = new User();
        user.setEmail(request.email());
        user.setPassword(passwordEncoder.encode(request.password()));

        User saved = userRepository.save(user);
        emailService.sendWelcomeEmail(saved.getEmail());

        return toDTO(saved);
    }
}
```

**Why constructor injection?**
- Dependencies can be `final` (immutable)
- Easy to test without Spring
- Explicit dependencies visible in constructor
- Spring detects circular dependencies at startup
- No framework coupling

### Bean Configuration

```java
@Configuration
public class AppConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }

    @Bean
    @ConditionalOnProperty(name = "app.feature.advanced", havingValue = "true")
    public AdvancedService advancedService() {
        return new AdvancedServiceImpl();
    }
}
```

### Bean Scopes

```java
@Component
@Scope("singleton")  // Default - one instance per application
public class DatabaseConfig { }

@Component
@Scope("prototype")  // New instance per injection
public class RequestProcessor { }

@Component
@Scope("request")  // New instance per HTTP request
public class RequestContext { }
```

### @Primary and @Qualifier

```java
@Configuration
public class EmailConfig {

    @Bean
    @Primary  // Default choice when multiple beans exist
    public EmailService primaryEmailService() {
        return new SmtpEmailService();
    }

    @Bean
    @Qualifier("sendgrid")
    public EmailService sendgridService() {
        return new SendGridEmailService();
    }
}

// Using qualifier
@Service
public class NotificationService {
    private final EmailService emailService;

    public NotificationService(@Qualifier("sendgrid") EmailService emailService) {
        this.emailService = emailService;
    }
}
```

---

## Part 3: Spring Data JPA Patterns

### Repository Interface

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    // Query method derivation
    Optional<User> findByEmail(String email);
    List<User> findByAgeGreaterThan(int age);

    // JPQL query
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveUserByEmail(@Param("email") String email);

    // Native SQL
    @Query(value = "SELECT * FROM users WHERE age > :age", nativeQuery = true)
    List<User> findUsersOlderThan(@Param("age") int age);

    // Modifying query
    @Modifying
    @Query("UPDATE User u SET u.active = false WHERE u.lastLoginDate < :date")
    int deactivateInactiveUsers(@Param("date") LocalDateTime date);

    // N+1 prevention with EntityGraph
    @EntityGraph(attributePaths = {"orders", "orders.items"})
    Optional<User> findWithOrdersById(Long id);
}
```

### Pagination and Sorting

```java
@GetMapping
public ResponseEntity<Page<UserDTO>> getUsers(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(defaultValue = "id,asc") String[] sort) {

    List<Sort.Order> orders = Arrays.stream(sort)
        .map(s -> {
            String[] parts = s.split(",");
            Sort.Direction direction = parts.length > 1 &&
                parts[1].equalsIgnoreCase("desc")
                ? Sort.Direction.DESC
                : Sort.Direction.ASC;
            return new Sort.Order(direction, parts[0]);
        })
        .toList();

    Pageable pageable = PageRequest.of(page, size, Sort.by(orders));
    return ResponseEntity.ok(userService.findAll(pageable));
}
```

### Specifications for Dynamic Queries

```java
public class UserSpecifications {

    public static Specification<User> hasEmail(String email) {
        return (root, query, cb) ->
            email == null ? null : cb.equal(root.get("email"), email);
    }

    public static Specification<User> ageGreaterThan(Integer age) {
        return (root, query, cb) ->
            age == null ? null : cb.greaterThan(root.get("age"), age);
    }

    public static Specification<User> isActive() {
        return (root, query, cb) -> cb.equal(root.get("active"), true);
    }
}

// Usage in service
public Page<User> searchUsers(String email, Integer age, Pageable pageable) {
    Specification<User> spec = Specification.where(UserSpecifications.isActive())
        .and(UserSpecifications.hasEmail(email))
        .and(UserSpecifications.ageGreaterThan(age));

    return userRepository.findAll(spec, pageable);
}
```

### N+1 Query Prevention

**Problem:**
```java
// Generates N+1 queries
List<User> users = userRepository.findAll();
users.forEach(user -> {
    System.out.println(user.getOrders().size());  // Lazy load triggers query
});
```

**Solution 1: @EntityGraph**
```java
@EntityGraph(attributePaths = {"orders", "orders.items"})
@Query("SELECT u FROM User u")
List<User> findAllWithOrders();

// Or define on entity
@Entity
@NamedEntityGraph(
    name = "User.withOrders",
    attributeNodes = @NamedAttributeNode("orders")
)
public class User {
    @OneToMany(mappedBy = "user")
    private List<Order> orders;
}
```

**Solution 2: JOIN FETCH**
```java
@Query("SELECT DISTINCT u FROM User u LEFT JOIN FETCH u.orders WHERE u.active = true")
List<User> findActiveUsersWithOrders();
```

**Solution 3: Batch Fetching**
```java
@Entity
public class User {
    @OneToMany(mappedBy = "user")
    @BatchSize(size = 10)  // Fetch in batches of 10
    private List<Order> orders;
}
```

### @Transactional Best Practices

```java
@Service
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;

    // Read-only optimization
    @Transactional(readOnly = true)
    public UserDTO findById(Long id) {
        return userRepository.findById(id)
            .map(this::toDTO)
            .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    // Write transaction
    @Transactional
    public UserDTO create(CreateUserRequest request) {
        User user = new User();
        user.setEmail(request.email());

        User saved = userRepository.save(user);
        emailService.sendWelcomeEmail(saved.getEmail());

        return toDTO(saved);
    }

    // Custom rollback rules
    @Transactional(rollbackFor = Exception.class,
                   noRollbackFor = EmailSendException.class)
    public UserDTO createWithOptionalEmail(CreateUserRequest request) {
        User user = new User();
        user.setEmail(request.email());
        User saved = userRepository.save(user);

        try {
            emailService.sendWelcomeEmail(saved.getEmail());
        } catch (EmailSendException e) {
            log.warn("Email failed but transaction continues", e);
        }

        return toDTO(saved);
    }
}
```

### DTO Projections

**Interface-based:**
```java
public interface UserSummary {
    String getEmail();
    String getFullName();
}

List<UserSummary> findByAgeGreaterThan(int age);
```

**Class-based:**
```java
public record UserDTO(Long id, String email, String firstName, String lastName) {}

@Query("SELECT new com.example.dto.UserDTO(u.id, u.email, u.firstName, u.lastName) " +
       "FROM User u WHERE u.active = true")
List<UserDTO> findAllActiveUsers();
```

---

## Best Practices Summary

### REST API
- ✅ Use DTOs, not entities
- ✅ Use `ResponseEntity` for HTTP control
- ✅ Validate with `@Valid`
- ✅ Global exception handling with `@RestControllerAdvice`
- ✅ Return proper status codes
- ❌ Don't expose entities directly
- ❌ Don't return 200 for everything

### Dependency Injection
- ✅ Constructor injection with `final` fields
- ✅ Use `@Primary` for defaults
- ✅ Use `@Qualifier` for specific beans
- ❌ Don't use field injection (except tests)
- ❌ Don't have too many dependencies (>5 suggests SRP violation)

### Spring Data
- ✅ Use `@EntityGraph` to prevent N+1
- ✅ Use `@Transactional(readOnly = true)` for reads
- ✅ Use DTOs/projections for queries
- ✅ Use pagination for large results
- ❌ Don't use `FetchType.EAGER` everywhere
- ❌ Don't ignore N+1 query problems
- ❌ Don't put `@Transactional` on repositories

---

## Further Reading

- [Spring Framework Documentation](https://docs.spring.io/spring-framework/reference/)
- [Spring Data JPA Reference](https://docs.spring.io/spring-data/jpa/reference/)
- [Baeldung Spring Tutorials](https://www.baeldung.com/spring-tutorial)
