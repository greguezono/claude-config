---
name: java-testing
description: Java testing with JUnit 5, Mockito, TestContainers, and Spring Boot Test. Covers unit testing, integration testing, mocking, test slices, parameterized tests, and TDD workflow. Use when writing Java tests, setting up test infrastructure, mocking dependencies, or testing Spring applications.
---

# Java Testing Skill

## Overview

The Java Testing skill provides comprehensive expertise for testing Java applications using modern testing frameworks and practices. It covers JUnit 5 features, Mockito mocking patterns, TestContainers for integration tests, and Spring Boot Test slices for efficient testing of Spring applications.

This skill consolidates testing patterns that ensure reliable, maintainable test suites while keeping tests fast and focused. It emphasizes the test pyramid approach: many unit tests, fewer integration tests, and minimal end-to-end tests.

Whether testing pure Java classes, Spring services, REST controllers, or data access layers, this skill provides the patterns and techniques for comprehensive test coverage with minimal boilerplate.

## When to Use

Use this skill when you need to:

- Write unit tests with JUnit 5 and Mockito
- Test Spring Boot controllers, services, and repositories
- Set up integration tests with TestContainers
- Implement parameterized and data-driven tests
- Mock external dependencies and APIs
- Configure test slices for focused testing
- Apply TDD methodology in Java projects

## Core Capabilities

### 1. JUnit 5 and Mockito

Master modern Java testing with JUnit 5 (lifecycle, assertions, parameterized tests) and Mockito (mocking, stubbing, verification). These work together for comprehensive unit testing.

See [junit-mockito.md](junit-mockito.md) for complete JUnit 5 and Mockito guidance.

### 2. Spring Boot Testing and TestContainers

Use Spring Boot Test slices (@WebMvcTest, @DataJpaTest, @SpringBootTest) for fast, focused tests. Use TestContainers for realistic integration testing with Docker-based databases.

See [spring-testing.md](spring-testing.md) for Spring Boot Test and TestContainers patterns.

## Quick Start Workflows

### Writing a Unit Test

1. Set up the test class with @ExtendWith(MockitoExtension.class)
2. Mock dependencies with @Mock
3. Inject mocks into subject with @InjectMocks
4. Write tests following Given-When-Then pattern
5. Use descriptive test names with @DisplayName

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private PaymentService paymentService;

    @InjectMocks
    private OrderService orderService;

    @Test
    @DisplayName("Should create order when payment succeeds")
    void createOrder_WhenPaymentSucceeds_CreatesOrder() {
        // Given
        CreateOrderRequest request = new CreateOrderRequest(100.00);
        when(paymentService.process(any())).thenReturn(PaymentResult.success());
        when(orderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // When
        Order result = orderService.createOrder(request);

        // Then
        assertThat(result.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        verify(paymentService).process(any());
        verify(orderRepository).save(any());
    }
}
```

### Testing a REST Controller

1. Use @WebMvcTest for controller slice testing
2. Mock service dependencies with @MockBean
3. Use MockMvc to perform requests
4. Assert response status, content type, and body

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void getUser_WhenExists_ReturnsUser() throws Exception {
        // Given
        UserDto user = new UserDto(1L, "john@example.com");
        when(userService.findById(1L)).thenReturn(user);

        // When/Then
        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("john@example.com"));
    }

    @Test
    void getUser_WhenNotExists_Returns404() throws Exception {
        when(userService.findById(1L))
            .thenThrow(new UserNotFoundException(1L));

        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isNotFound());
    }
}
```

### Integration Test with TestContainers

1. Add @Testcontainers and @Container annotations
2. Configure container with required image and settings
3. Use @DynamicPropertySource to inject container properties
4. Test against real database/service

```java
@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void save_PersistsUser() {
        User user = new User("test@example.com");
        User saved = userRepository.save(user);

        assertThat(saved.getId()).isNotNull();
        assertThat(userRepository.findById(saved.getId())).isPresent();
    }
}
```

## Core Principles

### 1. Test Behavior, Not Implementation

Tests should verify what the code does, not how it does it internally. This makes tests resilient to refactoring. If the behavior hasn't changed, tests shouldn't break.

```java
// Good: Tests behavior
@Test
void withdraw_WhenSufficientFunds_DecreasesBalance() {
    account.deposit(100);
    account.withdraw(30);
    assertThat(account.getBalance()).isEqualTo(70);
}

// Avoid: Tests implementation details
@Test
void withdraw_CallsDeductMethodOnBalanceField() {
    // Too coupled to internal implementation
}
```

### 2. Use Test Slices for Speed

Use Spring Boot test slices (@WebMvcTest, @DataJpaTest) instead of @SpringBootTest when possible. Slices load only relevant components, making tests faster.

### 3. Prefer AssertJ Over JUnit Assertions

AssertJ provides fluent, readable assertions with better error messages. Use assertThat() for all assertions.

```java
// AssertJ - preferred
assertThat(users).hasSize(3).extracting(User::getName).contains("Alice", "Bob");

// JUnit - less readable
assertEquals(3, users.size());
assertTrue(users.stream().anyMatch(u -> u.getName().equals("Alice")));
```

### 4. Arrange-Act-Assert (Given-When-Then)

Structure tests in three clear sections: set up (Given), execute (When), verify (Then). Add blank lines between sections for readability.

### 5. One Concept Per Test

Each test should verify one specific behavior. Multiple assertions are fine if they verify the same concept. Split tests that verify unrelated behaviors.

## Resource References

- **[junit-mockito.md](junit-mockito.md)**: JUnit 5 and Mockito patterns together
- **[spring-testing.md](spring-testing.md)**: Spring Boot Test and TestContainers patterns
- **[references.md](references.md)**: Testing annotations and assertion reference
- **[examples.md](examples.md)**: Complete test examples for various scenarios
- **[templates/](templates/)**: Test class templates for different scenarios

## Success Criteria

Java testing is effective when:

- Tests follow Given-When-Then structure consistently
- Unit tests run in milliseconds, not seconds
- Mocks are used appropriately (mock collaborators, not the subject)
- Integration tests use real infrastructure via TestContainers
- Test names clearly describe the scenario and expected outcome
- Tests are independent and can run in any order
- Code coverage focuses on critical paths and edge cases

## Next Steps

1. Master [junit-mockito.md](junit-mockito.md) for JUnit 5 and Mockito patterns
2. Study [spring-testing.md](spring-testing.md) for Spring Boot Test and TestContainers
3. Review [examples.md](examples.md) for complete test examples
4. Use [templates/](templates/) for consistent test structure

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
