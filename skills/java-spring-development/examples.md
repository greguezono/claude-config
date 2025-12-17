# Complete Spring Boot Application Examples

## Overview

This guide provides complete, production-ready examples showing all layers of Spring Boot applications: controller, service, repository, entity, DTO, mapper, and exception handling. These examples demonstrate best practices and common patterns.

## Table of Contents

1. [Simple CRUD Application](#simple-crud-application)
2. [E-Commerce Order System](#e-commerce-order-system)
3. [Blog Application with Comments](#blog-application-with-comments)
4. [Multi-Tenant SaaS Application](#multi-tenant-saas-application)

---

## Simple CRUD Application

A complete user management system demonstrating basic CRUD operations.

### Entity

```java
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String firstName;

    @Column(nullable = false)
    private String lastName;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserRole role = UserRole.USER;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

public enum UserRole {
    USER,
    ADMIN,
    MODERATOR
}
```

### DTOs

```java
// Response DTO
public record UserDto(
    Long id,
    String firstName,
    String lastName,
    String email,
    UserRole role,
    boolean active,
    LocalDateTime createdAt,
    LocalDateTime updatedAt
) {}

// Create request DTO
public record CreateUserRequest(
    @NotBlank(message = "First name is required")
    @Size(min = 2, max = 50)
    String firstName,

    @NotBlank(message = "Last name is required")
    @Size(min = 2, max = 50)
    String lastName,

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    String email,

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    String password,

    @NotNull(message = "Role is required")
    UserRole role
) {}

// Update request DTO
public record UpdateUserRequest(
    @Size(min = 2, max = 50)
    String firstName,

    @Size(min = 2, max = 50)
    String lastName,

    @Email
    String email,

    UserRole role,

    Boolean active
) {}
```

### Mapper

```java
@Component
public class UserMapper {

    public UserDto toDto(User user) {
        return new UserDto(
            user.getId(),
            user.getFirstName(),
            user.getLastName(),
            user.getEmail(),
            user.getRole(),
            user.isActive(),
            user.getCreatedAt(),
            user.getUpdatedAt()
        );
    }

    public User toEntity(CreateUserRequest request) {
        return User.builder()
            .firstName(request.firstName())
            .lastName(request.lastName())
            .email(request.email())
            .password(request.password()) // Should be encoded by service
            .role(request.role())
            .active(true)
            .build();
    }

    public void updateEntity(User user, UpdateUserRequest request) {
        if (request.firstName() != null) {
            user.setFirstName(request.firstName());
        }
        if (request.lastName() != null) {
            user.setLastName(request.lastName());
        }
        if (request.email() != null) {
            user.setEmail(request.email());
        }
        if (request.role() != null) {
            user.setRole(request.role());
        }
        if (request.active() != null) {
            user.setActive(request.active());
        }
    }
}
```

### Repository

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    List<User> findByRole(UserRole role);
    Page<User> findByActiveTrue(Pageable pageable);

    @Query("SELECT u FROM User u WHERE " +
           "LOWER(u.firstName) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(u.lastName) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(u.email) LIKE LOWER(CONCAT('%', :search, '%'))")
    Page<User> search(@Param("search") String search, Pageable pageable);
}
```

### Service

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
@Slf4j
public class UserService {
    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public Page<UserDto> findAll(Pageable pageable) {
        return userRepository.findAll(pageable)
            .map(userMapper::toDto);
    }

    public Page<UserDto> search(String query, Pageable pageable) {
        return userRepository.search(query, pageable)
            .map(userMapper::toDto);
    }

    public UserDto findById(Long id) {
        return userRepository.findById(id)
            .map(userMapper::toDto)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    public UserDto findByEmail(String email) {
        return userRepository.findByEmail(email)
            .map(userMapper::toDto)
            .orElseThrow(() -> new UserNotFoundException("User not found with email: " + email));
    }

    @Transactional
    public UserDto create(CreateUserRequest request) {
        // Validate email doesn't exist
        if (userRepository.existsByEmail(request.email())) {
            throw new EmailAlreadyExistsException(request.email());
        }

        User user = userMapper.toEntity(request);
        user.setPassword(passwordEncoder.encode(request.password()));

        User saved = userRepository.save(user);
        log.info("Created user with id: {}", saved.getId());

        return userMapper.toDto(saved);
    }

    @Transactional
    public UserDto update(Long id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));

        // Check email uniqueness if being updated
        if (request.email() != null && !request.email().equals(user.getEmail())) {
            if (userRepository.existsByEmail(request.email())) {
                throw new EmailAlreadyExistsException(request.email());
            }
        }

        userMapper.updateEntity(user, request);
        User updated = userRepository.save(user);

        log.info("Updated user with id: {}", id);
        return userMapper.toDto(updated);
    }

    @Transactional
    public void delete(Long id) {
        if (!userRepository.existsById(id)) {
            throw new UserNotFoundException(id);
        }

        userRepository.deleteById(id);
        log.info("Deleted user with id: {}", id);
    }

    @Transactional
    public UserDto deactivate(Long id) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));

        user.setActive(false);
        User updated = userRepository.save(user);

        log.info("Deactivated user with id: {}", id);
        return userMapper.toDto(updated);
    }
}
```

### Controller

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Validated
@Tag(name = "Users", description = "User management APIs")
public class UserController {
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all users", description = "Returns paginated list of users")
    public ResponseEntity<Page<UserDto>> getAllUsers(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "id,asc") String sort) {

        Pageable pageable = PageRequest.of(page, size, parseSort(sort));

        Page<UserDto> users = search != null
            ? userService.search(search, pageable)
            : userService.findAll(pageable);

        return ResponseEntity.ok(users);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get user by ID")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "User found"),
        @ApiResponse(responseCode = "404", description = "User not found")
    })
    public ResponseEntity<UserDto> getUser(@PathVariable Long id) {
        return ResponseEntity.ok(userService.findById(id));
    }

    @PostMapping
    @Operation(summary = "Create new user")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "User created"),
        @ApiResponse(responseCode = "400", description = "Invalid input"),
        @ApiResponse(responseCode = "409", description = "Email already exists")
    })
    public ResponseEntity<UserDto> createUser(@Valid @RequestBody CreateUserRequest request) {
        UserDto created = userService.create(request);

        URI location = ServletUriComponentsBuilder
            .fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.id())
            .toUri();

        return ResponseEntity.created(location).body(created);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update user")
    public ResponseEntity<UserDto> updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return ResponseEntity.ok(userService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete user")
    @ApiResponse(responseCode = "204", description = "User deleted")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/deactivate")
    @Operation(summary = "Deactivate user")
    public ResponseEntity<UserDto> deactivateUser(@PathVariable Long id) {
        return ResponseEntity.ok(userService.deactivate(id));
    }

    private Sort parseSort(String sort) {
        String[] parts = sort.split(",");
        String property = parts[0];
        Sort.Direction direction = parts.length > 1 && parts[1].equalsIgnoreCase("desc")
            ? Sort.Direction.DESC
            : Sort.Direction.ASC;
        return Sort.by(direction, property);
    }
}
```

### Exception Handling

```java
// Custom exceptions
public class UserNotFoundException extends RuntimeException {
    public UserNotFoundException(Long id) {
        super("User not found with id: " + id);
    }

    public UserNotFoundException(String message) {
        super(message);
    }
}

public class EmailAlreadyExistsException extends RuntimeException {
    public EmailAlreadyExistsException(String email) {
        super("User already exists with email: " + email);
    }
}

// Global exception handler
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(UserNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleUserNotFound(UserNotFoundException ex) {
        log.warn("User not found: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(new ErrorResponse(
                HttpStatus.NOT_FOUND.value(),
                ex.getMessage(),
                LocalDateTime.now()
            ));
    }

    @ExceptionHandler(EmailAlreadyExistsException.class)
    public ResponseEntity<ErrorResponse> handleEmailAlreadyExists(EmailAlreadyExistsException ex) {
        log.warn("Email conflict: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT)
            .body(new ErrorResponse(
                HttpStatus.CONFLICT.value(),
                ex.getMessage(),
                LocalDateTime.now()
            ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ValidationErrorResponse> handleValidationErrors(
            MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
            errors.put(error.getField(), error.getDefaultMessage())
        );

        log.warn("Validation failed: {}", errors);
        return ResponseEntity.badRequest()
            .body(new ValidationErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                "Validation failed",
                errors,
                LocalDateTime.now()
            ));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception ex) {
        log.error("Unexpected error", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(new ErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "An unexpected error occurred",
                LocalDateTime.now()
            ));
    }
}

// Error response DTOs
public record ErrorResponse(
    int status,
    String message,
    LocalDateTime timestamp
) {}

public record ValidationErrorResponse(
    int status,
    String message,
    Map<String, String> errors,
    LocalDateTime timestamp
) {}
```

---

## E-Commerce Order System

Complete order management system with relationships.

### Entities

```java
@Entity
@Table(name = "orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Order {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String orderNumber;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<OrderItem> items = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private OrderStatus status = OrderStatus.PENDING;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal tax;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal shipping;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    // Helper methods for bidirectional relationship
    public void addItem(OrderItem item) {
        items.add(item);
        item.setOrder(this);
    }

    public void removeItem(OrderItem item) {
        items.remove(item);
        item.setOrder(null);
    }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (orderNumber == null) {
            orderNumber = generateOrderNumber();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    private String generateOrderNumber() {
        return "ORD-" + System.currentTimeMillis();
    }
}

@Entity
@Table(name = "order_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(nullable = false)
    private Integer quantity;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    @PrePersist
    @PreUpdate
    protected void calculateSubtotal() {
        subtotal = unitPrice.multiply(BigDecimal.valueOf(quantity));
    }
}

@Entity
@Table(name = "customers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Customer {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String firstName;

    @Column(nullable = false)
    private String lastName;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String phone;

    @Embedded
    private Address shippingAddress;

    @OneToMany(mappedBy = "customer")
    private List<Order> orders = new ArrayList<>();
}

@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Address {
    private String street;
    private String city;
    private String state;
    private String zipCode;
    private String country;
}

@Entity
@Table(name = "products")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Product {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(nullable = false)
    private Integer stockQuantity;

    @Column(nullable = false)
    private boolean active = true;
}

public enum OrderStatus {
    PENDING,
    CONFIRMED,
    PROCESSING,
    SHIPPED,
    DELIVERED,
    CANCELLED
}
```

### DTOs

```java
// Order DTOs
public record OrderDto(
    Long id,
    String orderNumber,
    CustomerSummaryDto customer,
    List<OrderItemDto> items,
    OrderStatus status,
    BigDecimal subtotal,
    BigDecimal tax,
    BigDecimal shipping,
    BigDecimal total,
    LocalDateTime createdAt,
    LocalDateTime updatedAt
) {}

public record OrderItemDto(
    Long id,
    ProductSummaryDto product,
    Integer quantity,
    BigDecimal unitPrice,
    BigDecimal subtotal
) {}

public record CreateOrderRequest(
    @NotNull
    Long customerId,

    @NotEmpty
    @Valid
    List<OrderItemRequest> items,

    @NotNull
    @DecimalMin("0.00")
    BigDecimal shipping
) {}

public record OrderItemRequest(
    @NotNull
    Long productId,

    @NotNull
    @Min(1)
    Integer quantity
) {}

// Customer DTOs
public record CustomerDto(
    Long id,
    String firstName,
    String lastName,
    String email,
    String phone,
    AddressDto shippingAddress
) {}

public record CustomerSummaryDto(
    Long id,
    String firstName,
    String lastName,
    String email
) {}

public record AddressDto(
    String street,
    String city,
    String state,
    String zipCode,
    String country
) {}

// Product DTOs
public record ProductDto(
    Long id,
    String name,
    String description,
    BigDecimal price,
    Integer stockQuantity,
    boolean active
) {}

public record ProductSummaryDto(
    Long id,
    String name,
    BigDecimal price
) {}
```

### Service

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
@Slf4j
public class OrderService {
    private final OrderRepository orderRepository;
    private final CustomerRepository customerRepository;
    private final ProductRepository productRepository;
    private final OrderMapper orderMapper;

    public Page<OrderDto> findAll(Pageable pageable) {
        return orderRepository.findAllWithDetails(pageable)
            .map(orderMapper::toDto);
    }

    public Page<OrderDto> findByCustomer(Long customerId, Pageable pageable) {
        return orderRepository.findByCustomerIdWithDetails(customerId, pageable)
            .map(orderMapper::toDto);
    }

    public OrderDto findById(Long id) {
        return orderRepository.findByIdWithDetails(id)
            .map(orderMapper::toDto)
            .orElseThrow(() -> new OrderNotFoundException(id));
    }

    @Transactional
    public OrderDto create(CreateOrderRequest request) {
        // Validate customer exists
        Customer customer = customerRepository.findById(request.customerId())
            .orElseThrow(() -> new CustomerNotFoundException(request.customerId()));

        // Create order
        Order order = Order.builder()
            .customer(customer)
            .shipping(request.shipping())
            .build();

        BigDecimal subtotal = BigDecimal.ZERO;

        // Add items and calculate totals
        for (OrderItemRequest itemRequest : request.items()) {
            Product product = productRepository.findById(itemRequest.productId())
                .orElseThrow(() -> new ProductNotFoundException(itemRequest.productId()));

            // Check stock
            if (product.getStockQuantity() < itemRequest.quantity()) {
                throw new InsufficientStockException(product.getName(), itemRequest.quantity());
            }

            OrderItem orderItem = OrderItem.builder()
                .product(product)
                .quantity(itemRequest.quantity())
                .unitPrice(product.getPrice())
                .build();

            order.addItem(orderItem);
            subtotal = subtotal.add(orderItem.getSubtotal());

            // Reduce stock
            product.setStockQuantity(product.getStockQuantity() - itemRequest.quantity());
        }

        // Calculate totals
        order.setSubtotal(subtotal);
        order.setTax(subtotal.multiply(new BigDecimal("0.08"))); // 8% tax
        order.setTotal(subtotal.add(order.getTax()).add(order.getShipping()));

        Order saved = orderRepository.save(order);
        log.info("Created order {} for customer {}", saved.getOrderNumber(), customer.getId());

        return orderMapper.toDto(saved);
    }

    @Transactional
    public OrderDto updateStatus(Long id, OrderStatus newStatus) {
        Order order = orderRepository.findById(id)
            .orElseThrow(() -> new OrderNotFoundException(id));

        OrderStatus currentStatus = order.getStatus();

        // Validate status transition
        if (!isValidStatusTransition(currentStatus, newStatus)) {
            throw new InvalidStatusTransitionException(currentStatus, newStatus);
        }

        order.setStatus(newStatus);
        Order updated = orderRepository.save(order);

        log.info("Updated order {} status from {} to {}", id, currentStatus, newStatus);
        return orderMapper.toDto(updated);
    }

    @Transactional
    public void cancel(Long id) {
        Order order = orderRepository.findByIdWithDetails(id)
            .orElseThrow(() -> new OrderNotFoundException(id));

        if (order.getStatus() == OrderStatus.SHIPPED || order.getStatus() == OrderStatus.DELIVERED) {
            throw new OrderCannotBeCancelledException(id, order.getStatus());
        }

        // Restore stock
        for (OrderItem item : order.getItems()) {
            Product product = item.getProduct();
            product.setStockQuantity(product.getStockQuantity() + item.getQuantity());
        }

        order.setStatus(OrderStatus.CANCELLED);
        orderRepository.save(order);

        log.info("Cancelled order {}", id);
    }

    private boolean isValidStatusTransition(OrderStatus current, OrderStatus target) {
        return switch (current) {
            case PENDING -> target == OrderStatus.CONFIRMED || target == OrderStatus.CANCELLED;
            case CONFIRMED -> target == OrderStatus.PROCESSING || target == OrderStatus.CANCELLED;
            case PROCESSING -> target == OrderStatus.SHIPPED || target == OrderStatus.CANCELLED;
            case SHIPPED -> target == OrderStatus.DELIVERED;
            case DELIVERED, CANCELLED -> false;
        };
    }
}
```

### Repository

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    @EntityGraph(attributePaths = {"customer", "items", "items.product"})
    Page<Order> findAllWithDetails(Pageable pageable);

    @EntityGraph(attributePaths = {"customer", "items", "items.product"})
    @Query("SELECT o FROM Order o WHERE o.id = :id")
    Optional<Order> findByIdWithDetails(@Param("id") Long id);

    @EntityGraph(attributePaths = {"customer", "items", "items.product"})
    Page<Order> findByCustomerIdWithDetails(Long customerId, Pageable pageable);

    List<Order> findByStatus(OrderStatus status);

    @Query("SELECT o FROM Order o WHERE o.createdAt BETWEEN :start AND :end")
    List<Order> findOrdersBetweenDates(
        @Param("start") LocalDateTime start,
        @Param("end") LocalDateTime end
    );
}
```

---

This examples file demonstrates:

1. **Complete entity models** with relationships and lifecycle hooks
2. **DTO patterns** for requests and responses
3. **Mapper classes** for entity-DTO conversion
4. **Repository patterns** with custom queries and @EntityGraph
5. **Service layer** with business logic and transaction management
6. **Controller layer** with validation and documentation
7. **Exception handling** with custom exceptions and global handler
8. **Complex business logic** like order processing and inventory management

These examples can be used as templates for building production-grade Spring Boot applications.
