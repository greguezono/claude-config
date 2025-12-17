# JUnit 5 and Mockito Patterns

## Overview

Modern Java testing combines JUnit 5 (test framework) with Mockito (mocking library) for comprehensive unit testing. This guide covers both together since they're typically used in combination.

---

## Part 1: JUnit 5 Essentials

### Basic Test Structure

```java
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

@DisplayName("Calculator Tests")
class CalculatorTest {

    private Calculator calculator;

    @BeforeEach
    void setup() {
        calculator = new Calculator();
    }

    @Test
    @DisplayName("Should add two positive numbers")
    void shouldAddPositiveNumbers() {
        // Given
        int a = 5, b = 3;

        // When
        int result = calculator.add(a, b);

        // Then
        assertThat(result).isEqualTo(8);
    }

    @AfterEach
    void tearDown() {
        calculator = null;
    }
}
```

### Lifecycle Annotations

```java
@BeforeAll
static void setupAll() {
    // Runs once before all tests (must be static)
}

@BeforeEach
void setup() {
    // Runs before each test - create fresh test data
}

@AfterEach
void tearDown() {
    // Runs after each test - cleanup
}

@AfterAll
static void tearDownAll() {
    // Runs once after all tests
}
```

### Parameterized Tests

**@ValueSource:**
```java
@ParameterizedTest
@ValueSource(strings = {"level", "madam", "radar"})
void shouldIdentifyPalindromes(String word) {
    assertThat(StringUtils.isPalindrome(word)).isTrue();
}

@ParameterizedTest
@ValueSource(ints = {2, 4, 6, 8})
void shouldBeEvenNumbers(int number) {
    assertThat(number % 2).isZero();
}
```

**@CsvSource:**
```java
@ParameterizedTest
@CsvSource({
    "2, 3, 5",
    "4, 5, 9",
    "10, 15, 25"
})
void shouldAddNumbers(int a, int b, int expected) {
    assertThat(calculator.add(a, b)).isEqualTo(expected);
}

// Modern text block format
@ParameterizedTest
@CsvSource(delimiterString = "->", textBlock = """
    fooBar -> FooBar
    snake_case -> SnakeCase
    """)
void shouldConvertCase(String input, String expected) {
    assertThat(converter.toUpperCamelCase(input)).isEqualTo(expected);
}
```

### Nested Tests

```java
@DisplayName("User Service Tests")
class UserServiceTest {

    @Nested
    @DisplayName("When user is authenticated")
    class AuthenticatedUser {

        @BeforeEach
        void setupAuth() {
            // Setup authenticated context
        }

        @Test
        void shouldAccessPrivateData() {
            // Test authenticated behavior
        }
    }

    @Nested
    @DisplayName("When user is not authenticated")
    class UnauthenticatedUser {

        @Test
        void shouldDenyAccess() {
            // Test unauthenticated behavior
        }
    }
}
```

### Test Tags and Filtering

```java
@Tag("integration")
class IntegrationTest {

    @Test
    @Tag("slow")
    void shouldRunSlowTest() {
        // Expensive operation
    }

    @Test
    @Tag("fast")
    void shouldRunFastTest() {
        // Quick test
    }
}
```

```bash
# Run only fast tests
./gradlew test --tests "*" -Dtags="fast"
```

---

## Part 2: Mockito Patterns

### Basic Mocking Setup

```java
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.mockito.Mockito.*;
import static org.assertj.core.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private EmailService emailService;

    @InjectMocks  // Injects mocks into UserService
    private UserService userService;

    @Test
    void shouldCreateUser() {
        // Given
        User user = new User("john@example.com");
        when(userRepository.save(any(User.class))).thenReturn(user);

        // When
        User result = userService.createUser(user);

        // Then
        assertThat(result).isNotNull();
        verify(userRepository).save(user);
        verify(emailService).sendWelcomeEmail(user.getEmail());
    }
}
```

### Stubbing with when/thenReturn

```java
// Simple return
when(userRepository.findById(1L)).thenReturn(Optional.of(user));

// Multiple calls return different values
when(rateLimiter.allowRequest())
    .thenReturn(true)
    .thenReturn(true)
    .thenReturn(false);  // Third call returns false

// Argument matching
when(userRepository.findByEmail(anyString())).thenReturn(Optional.empty());
when(calculator.add(eq(2), anyInt())).thenReturn(10);

// Throw exception
when(authService.authenticate(any())).thenThrow(new AuthException("Invalid"));
```

### Verification

```java
// Basic verification
verify(emailService).sendEmail(user.getEmail());

// Verify call count
verify(userRepository, times(2)).findById(anyLong());
verify(cache, never()).clear();
verify(logger, atLeastOnce()).log(anyString());
verify(emailService, atMost(3)).sendEmail(anyString());

// Verify no other interactions
verifyNoMoreInteractions(emailService);

// Verify order
InOrder inOrder = inOrder(userRepository, emailService);
inOrder.verify(userRepository).save(user);
inOrder.verify(emailService).sendWelcomeEmail(user.getEmail());
```

### Argument Captors

```java
@Captor
private ArgumentCaptor<EmailMessage> emailCaptor;

@Test
void shouldSendCorrectEmail() {
    // When
    orderService.placeOrder(order);

    // Then - capture argument
    verify(emailService).send(emailCaptor.capture());

    EmailMessage captured = emailCaptor.getValue();
    assertThat(captured.getFrom()).isEqualTo("orders@example.com");
    assertThat(captured.getBody()).contains("Order #12345");
}

@Test
void shouldCaptureMultipleCalls() {
    orderService.processBatch(orders);

    verify(emailService, times(3)).send(emailCaptor.capture());
    List<EmailMessage> allEmails = emailCaptor.getAllValues();
    assertThat(allEmails).hasSize(3);
}
```

### Spies (Partial Mocking)

```java
@Spy
private CacheService cacheService;

@Test
void shouldUseRealMethodsUnlessStubbed() {
    // Real methods called
    cacheService.put("key", "value");
    assertThat(cacheService.get("key")).isEqualTo("value");

    // Stub specific method
    doReturn(false).when(cacheService).isExpired("key");

    // Verify calls
    verify(cacheService).put("key", "value");
}
```

### doThrow/doAnswer for Void Methods

```java
// Stub void method to throw
doThrow(new IOException("Network error"))
    .when(fileService).deleteFile(anyString());

// Custom behavior
doAnswer(invocation -> {
    String fileName = invocation.getArgument(0);
    System.out.println("Deleting: " + fileName);
    return null;
}).when(fileService).deleteFile(anyString());
```

## Best Practices

### JUnit 5

**DO:**
- ✅ Use `@DisplayName` for readable test names
- ✅ Use Given-When-Then or AAA structure
- ✅ Use `@ParameterizedTest` for multiple inputs
- ✅ Use AssertJ `assertThat()` for fluent assertions
- ✅ Use `@BeforeEach` for test setup

**DON'T:**
- ❌ Use JUnit 4 annotations (@Before, @After, @RunWith)
- ❌ Mix static/non-static lifecycle without `@TestInstance`
- ❌ Write tests that depend on execution order
- ❌ Create god tests (test one behavior per test)

### Mockito

**DO:**
- ✅ Mock interfaces and complex dependencies
- ✅ Use ArgumentCaptor with `verify()` only
- ✅ Verify critical behavior, not every call
- ✅ Use all matchers OR all raw values

**DON'T:**
- ❌ Over-mock (don't mock DTOs, simple objects)
- ❌ Mix matchers and raw values: `when(service.get(anyString(), "literal"))` ❌
- ❌ Use ArgumentCaptor with stubbing
- ❌ Verify every single method call

## Common Mistakes

**JUnit 5:**
```java
// ❌ Wrong - JUnit 4 annotation
@Before
public void setup() { }

// ✅ Correct - JUnit 5
@BeforeEach
void setup() { }
```

**Mockito:**
```java
// ❌ Wrong - mixing matchers with raw values
when(service.process(anyString(), "literal")).thenReturn(result);

// ✅ Correct - all matchers or all raw
when(service.process(anyString(), eq("literal"))).thenReturn(result);
when(service.process("test", "literal")).thenReturn(result);
```

## Complete Test Example

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("Order Service Tests")
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private PaymentService paymentService;

    @Mock
    private EmailService emailService;

    @InjectMocks
    private OrderService orderService;

    @Test
    @DisplayName("Should create order when payment succeeds")
    void createOrder_WhenPaymentSucceeds_CreatesOrder() {
        // Given
        CreateOrderRequest request = new CreateOrderRequest(100.00, "CREDIT_CARD");
        Order savedOrder = new Order(1L, 100.00, OrderStatus.CONFIRMED);

        when(paymentService.process(any())).thenReturn(PaymentResult.success());
        when(orderRepository.save(any(Order.class))).thenReturn(savedOrder);

        // When
        Order result = orderService.createOrder(request);

        // Then
        assertThat(result.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        assertThat(result.getId()).isEqualTo(1L);

        verify(paymentService).process(any(PaymentRequest.class));
        verify(orderRepository).save(any(Order.class));
        verify(emailService).sendOrderConfirmation(savedOrder.getId());
    }

    @Test
    @DisplayName("Should not create order when payment fails")
    void createOrder_WhenPaymentFails_ThrowsException() {
        // Given
        CreateOrderRequest request = new CreateOrderRequest(100.00, "CREDIT_CARD");
        when(paymentService.process(any())).thenThrow(new PaymentException("Declined"));

        // When/Then
        assertThatThrownBy(() -> orderService.createOrder(request))
            .isInstanceOf(PaymentException.class)
            .hasMessageContaining("Declined");

        verify(paymentService).process(any());
        verify(orderRepository, never()).save(any());
        verify(emailService, never()).sendOrderConfirmation(anyLong());
    }

    @ParameterizedTest
    @CsvSource({
        "100.00, CREDIT_CARD, true",
        "200.00, PAYPAL, true",
        "50.00, BANK_TRANSFER, true"
    })
    @DisplayName("Should process various payment methods")
    void shouldProcessVariousPaymentMethods(double amount, String method, boolean expected) {
        // Given
        CreateOrderRequest request = new CreateOrderRequest(amount, method);
        when(paymentService.process(any())).thenReturn(PaymentResult.success());

        // When
        boolean result = orderService.canProcess(request);

        // Then
        assertThat(result).isEqualTo(expected);
    }
}
```

## Further Reading

- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [Mockito Documentation](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html)
- [AssertJ Documentation](https://assertj.github.io/doc/)
