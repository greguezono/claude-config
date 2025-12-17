---
name: java-spring-development
description: Spring Boot and Spring Framework development patterns including dependency injection, REST API design, Spring MVC, Spring Data JPA, configuration, security, and microservices architecture. Use when building Java web applications, REST APIs, configuring Spring beans, implementing controllers, services, or repositories.
---

# Java Spring Development Skill

## Overview

The Java Spring Development skill provides comprehensive expertise for building production-grade applications using Spring Boot and the Spring Framework ecosystem. It covers dependency injection patterns, REST API design, data access with Spring Data JPA, security configuration, and microservices architecture.

This skill consolidates proven patterns from enterprise Spring applications, official Spring documentation, and common pitfalls encountered in production systems. It emphasizes convention over configuration while maintaining flexibility for complex requirements.

Whether building new microservices, maintaining existing Spring applications, or migrating legacy systems to Spring Boot, this skill provides the patterns, anti-patterns, and decision-making frameworks needed for effective Spring development.

## When to Use

Use this skill when you need to:

- Build REST APIs with Spring Boot and Spring MVC
- Configure dependency injection and bean management
- Implement data access with Spring Data JPA/JDBC
- Set up Spring Security for authentication/authorization
- Design microservices with Spring Cloud
- Handle configuration and profiles for different environments
- Implement proper error handling and validation

## Core Capabilities

### 1. REST API, Dependency Injection & Data Access

Design and implement RESTful APIs with proper dependency injection and data access patterns. Includes controller patterns, constructor injection, Spring Data JPA repositories, pagination, N+1 prevention, and transactions.

See [spring-core-patterns.md](spring-core-patterns.md) for complete guidance on REST API, DI, and Spring Data patterns.

### 2. Security Implementation

Configure Spring Security 6 for authentication, authorization, JWT, OAuth2, and method-level security.

See [spring-security.md](spring-security.md) for security implementation.

## Quick Start Workflows

### Creating a New REST Controller

1. Define the controller with @RestController and @RequestMapping
2. Implement endpoints with appropriate HTTP method annotations
3. Use DTOs for request/response bodies with validation
4. Inject service layer dependencies via constructor
5. Handle exceptions with @ExceptionHandler or @ControllerAdvice

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
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

### Implementing a Service Layer

1. Define service interface (optional but recommended for testability)
2. Implement with @Service annotation
3. Use constructor injection for dependencies
4. Apply @Transactional where needed
5. Throw domain-specific exceptions for error cases

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserServiceImpl implements UserService {
    private final UserRepository userRepository;
    private final UserMapper userMapper;

    @Override
    public UserDto findById(Long id) {
        return userRepository.findById(id)
            .map(userMapper::toDto)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    @Override
    @Transactional
    public UserDto create(CreateUserRequest request) {
        User user = userMapper.toEntity(request);
        return userMapper.toDto(userRepository.save(user));
    }
}
```

## Core Principles

### 1. Constructor Injection Over Field Injection

Always use constructor injection for required dependencies. It makes dependencies explicit, enables immutability, and simplifies testing. Lombok's @RequiredArgsConstructor eliminates boilerplate.

```java
// Good: Constructor injection
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
}

// Avoid: Field injection
@Service
public class OrderService {
    @Autowired  // Not recommended
    private OrderRepository orderRepository;
}
```

### 2. DTOs at API Boundaries

Never expose JPA entities directly in API responses. Use DTOs (Data Transfer Objects) to decouple your API contract from your domain model. This prevents accidental data exposure and allows independent evolution.

### 3. Layered Architecture

Maintain clear separation: Controller → Service → Repository. Controllers handle HTTP concerns, services contain business logic, repositories handle data access. Each layer should only depend on the layer below it.

### 4. Externalized Configuration

Use @ConfigurationProperties for type-safe configuration. Keep environment-specific values in application-{profile}.yml files. Never hardcode credentials or environment-specific values.

```java
@Configuration
@ConfigurationProperties(prefix = "app.cache")
@Validated
public class CacheProperties {
    @NotNull
    private Duration ttl;
    private int maxSize = 1000;
    // getters/setters
}
```

### 5. Proper Exception Handling

Use @ControllerAdvice for global exception handling. Return consistent error responses with appropriate HTTP status codes. Log exceptions at the appropriate level.

## Resource References

For detailed guidance on specific operations, see:

- **[spring-core-patterns.md](spring-core-patterns.md)**: REST API, dependency injection, and Spring Data patterns
- **[spring-security.md](spring-security.md)**: Spring Security 6 configuration and JWT
- **[references.md](references.md)**: Spring annotations reference and configuration options
- **[examples.md](examples.md)**: Complete application examples with all layers
- **[templates/](templates/)**: Controller, service, repository templates

## Success Criteria

Spring development is effective when:

- Dependencies are injected via constructors, not fields
- API endpoints follow REST conventions with proper HTTP methods/status codes
- Validation is applied to all incoming data with clear error messages
- Transactions are properly scoped (@Transactional on service methods)
- Configuration is externalized and environment-agnostic
- Exceptions are handled consistently with appropriate responses
- Tests cover controllers, services, and repositories independently

## Next Steps

1. Review [spring-core-patterns.md](spring-core-patterns.md) for REST API, DI, and Data patterns
2. Study [spring-security.md](spring-security.md) for security implementation
3. Refer to [examples.md](examples.md) for complete application structure
4. Use [templates/](templates/) for consistent code structure

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
