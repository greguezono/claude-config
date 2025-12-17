# Java Testing Quick Reference

Quick reference guide for Java testing annotations, assertions, matchers, and common patterns.

## Table of Contents

- [JUnit 5 Annotations](#junit-5-annotations)
- [Mockito Annotations](#mockito-annotations)
- [Spring Boot Test Annotations](#spring-boot-test-annotations)
- [Assertions Quick Reference](#assertions-quick-reference)
- [Mockito Matchers](#mockito-matchers)
- [Common Test Patterns](#common-test-patterns)
- [HTTP Status Codes](#http-status-codes)
- [JSON Path Expressions](#json-path-expressions)

## JUnit 5 Annotations

### Test Lifecycle

| Annotation | Description | Scope |
|------------|-------------|-------|
| `@Test` | Marks a test method | Method |
| `@BeforeAll` | Runs once before all tests | Static method |
| `@AfterAll` | Runs once after all tests | Static method |
| `@BeforeEach` | Runs before each test | Method |
| `@AfterEach` | Runs after each test | Method |
| `@Disabled` | Disables a test | Class/Method |
| `@DisplayName("name")` | Custom display name | Class/Method |
| `@Nested` | Nested test class | Class |

### Parameterized Tests

| Annotation | Description | Example |
|------------|-------------|---------|
| `@ParameterizedTest` | Parameterized test | Method |
| `@ValueSource` | Simple value array | `@ValueSource(ints = {1, 2, 3})` |
| `@CsvSource` | CSV values | `@CsvSource({"1,2,3", "4,5,9"})` |
| `@CsvFileSource` | CSV file | `@CsvFileSource(resources = "/data.csv")` |
| `@MethodSource` | Method provider | `@MethodSource("provideArgs")` |
| `@EnumSource` | Enum values | `@EnumSource(TimeUnit.class)` |
| `@NullSource` | Null value | - |
| `@EmptySource` | Empty value | - |
| `@NullAndEmptySource` | Both null and empty | - |

### Conditional Execution

| Annotation | Description |
|------------|-------------|
| `@EnabledOnOs(OS.LINUX)` | Run on specific OS |
| `@DisabledOnOs(OS.WINDOWS)` | Skip on specific OS |
| `@EnabledOnJre(JRE.JAVA_17)` | Run on specific Java version |
| `@EnabledIfEnvironmentVariable` | Run if env var matches |
| `@EnabledIf("condition")` | Run if custom condition true |

### Test Ordering

| Annotation | Description |
|------------|-------------|
| `@TestMethodOrder(MethodOrderer.OrderAnnotation.class)` | Enable ordering |
| `@Order(1)` | Set execution order |
| `@TestInstance(Lifecycle.PER_CLASS)` | Share instance across tests |

## Mockito Annotations

### Mock Creation

| Annotation | Description |
|------------|-------------|
| `@Mock` | Create mock object |
| `@Spy` | Create spy (partial mock) |
| `@InjectMocks` | Create object with mocks injected |
| `@Captor` | Create ArgumentCaptor |
| `@ExtendWith(MockitoExtension.class)` | Enable Mockito for JUnit 5 |

### Usage Example

```java
@ExtendWith(MockitoExtension.class)
class ExampleTest {
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Captor
    private ArgumentCaptor<User> userCaptor;
}
```

## Spring Boot Test Annotations

### Test Slices

| Annotation | Purpose | Loads |
|------------|---------|-------|
| `@SpringBootTest` | Full integration test | Complete context |
| `@WebMvcTest(Controller.class)` | Controller test | Web layer only |
| `@DataJpaTest` | Repository test | JPA components |
| `@RestClientTest(Client.class)` | REST client test | REST client components |
| `@JsonTest` | JSON serialization test | Jackson components |
| `@WebFluxTest` | WebFlux controller test | WebFlux components |

### Configuration

| Annotation | Description |
|------------|-------------|
| `@MockBean` | Add mock bean to Spring context |
| `@SpyBean` | Add spy bean to Spring context |
| `@Import(Config.class)` | Import configuration |
| `@ActiveProfiles("test")` | Activate Spring profile |
| `@TestPropertySource` | Override properties |
| `@DynamicPropertySource` | Dynamic property registration |
| `@DirtiesContext` | Mark context as dirty |
| `@AutoConfigureTestDatabase` | Configure test database |

### Web Testing

| Annotation | Description |
|------------|-------------|
| `@AutoConfigureMockMvc` | Auto-configure MockMvc |
| `@WithMockUser` | Mock authenticated user |
| `@WithMockUser(roles="ADMIN")` | Mock user with role |

### TestContainers

| Annotation | Description |
|------------|-------------|
| `@Testcontainers` | Enable TestContainers |
| `@Container` | Declare container |

## Assertions Quick Reference

### JUnit 5 Assertions

```java
// Basic assertions
assertEquals(expected, actual);
assertEquals(expected, actual, "message");
assertNotEquals(unexpected, actual);

// Boolean assertions
assertTrue(condition);
assertFalse(condition);

// Null checks
assertNull(object);
assertNotNull(object);

// Reference comparison
assertSame(expected, actual);
assertNotSame(expected, actual);

// Array/Iterable
assertArrayEquals(expectedArray, actualArray);
assertIterableEquals(expectedList, actualList);

// Exception assertions
assertThrows(Exception.class, () -> code());
assertDoesNotThrow(() -> code());

// Timeout assertions
assertTimeout(Duration.ofSeconds(1), () -> code());
assertTimeoutPreemptively(Duration.ofSeconds(1), () -> code());

// Grouped assertions
assertAll(
    () -> assertEquals(expected1, actual1),
    () -> assertEquals(expected2, actual2)
);
```

### AssertJ Assertions

```java
// Basic
assertThat(actual).isEqualTo(expected);
assertThat(actual).isNotNull();
assertThat(actual).isInstanceOf(Type.class);

// Strings
assertThat(string).startsWith("prefix");
assertThat(string).endsWith("suffix");
assertThat(string).contains("substring");
assertThat(string).matches("regex");
assertThat(string).isBlank();
assertThat(string).isNotBlank();

// Numbers
assertThat(number).isPositive();
assertThat(number).isNegative();
assertThat(number).isZero();
assertThat(number).isBetween(min, max);
assertThat(number).isGreaterThan(value);
assertThat(number).isLessThan(value);

// Collections
assertThat(list).hasSize(3);
assertThat(list).isEmpty();
assertThat(list).isNotEmpty();
assertThat(list).contains(element);
assertThat(list).containsOnly(elements);
assertThat(list).containsExactly(elements);
assertThat(list).startsWith(elements);
assertThat(list).doesNotContain(element);

// Objects
assertThat(object).extracting("field").isEqualTo(value);
assertThat(object).hasFieldOrPropertyWithValue("field", value);

// Exceptions
assertThatThrownBy(() -> code())
    .isInstanceOf(Exception.class)
    .hasMessage("message")
    .hasMessageContaining("partial");
```

### Hamcrest Matchers (MockMvc)

```java
// Basic matchers
is(value)
not(value)
equalTo(value)
nullValue()
notNullValue()
instanceOf(Type.class)

// String matchers
startsWith("prefix")
endsWith("suffix")
containsString("substring")
matchesPattern("regex")
blankString()

// Number matchers
greaterThan(value)
lessThan(value)
greaterThanOrEqualTo(value)
lessThanOrEqualTo(value)
closeTo(value, delta)

// Collection matchers
hasSize(3)
empty()
hasItem(item)
hasItems(item1, item2)
contains(items)
containsInAnyOrder(items)

// Usage in MockMvc
mockMvc.perform(get("/api/users"))
    .andExpect(jsonPath("$.name", is("John")))
    .andExpect(jsonPath("$", hasSize(3)))
    .andExpect(jsonPath("$.items", hasItem("value")));
```

## Mockito Matchers

### Argument Matchers

```java
// Any value
any()
any(Class.class)
anyString()
anyInt()
anyLong()
anyDouble()
anyBoolean()
anyList()
anyMap()
anyCollection()

// Specific values
eq(value)           // Exact match
same(object)        // Reference equality
isNull()
isNotNull()
notNull()

// String matchers
startsWith("prefix")
endsWith("suffix")
contains("substring")
matches("regex")

// Number matchers
gt(value)           // Greater than
lt(value)           // Less than
geq(value)          // Greater or equal
leq(value)          // Less or equal

// Collection matchers
anyIterable()
anyList()
anySet()
anyMap()

// Custom matchers
argThat(predicate)
argThat(matcher)

// Usage
when(service.method(anyString())).thenReturn(result);
when(service.method(eq("exact"))).thenReturn(result);
when(service.save(argThat(user -> user.getAge() > 18))).thenReturn(saved);
```

## Common Test Patterns

### Given-When-Then

```java
@Test
void shouldFollowGivenWhenThen() {
    // Given - Setup preconditions and inputs
    User user = new User("John", "john@example.com");
    when(userRepository.save(any())).thenReturn(user);

    // When - Execute the behavior being tested
    User result = userService.createUser("John", "john@example.com");

    // Then - Verify outputs and interactions
    assertNotNull(result);
    assertEquals("John", result.getName());
    verify(userRepository).save(any(User.class));
}
```

### Stubbing Pattern

```java
// Return value
when(mock.method()).thenReturn(value);

// Return multiple values
when(mock.method()).thenReturn(value1, value2, value3);

// Throw exception
when(mock.method()).thenThrow(new Exception());

// Use answer for custom logic
when(mock.method()).thenAnswer(invocation -> {
    String arg = invocation.getArgument(0);
    return "processed: " + arg;
});

// Void method
doNothing().when(mock).voidMethod();
doThrow(new Exception()).when(mock).voidMethod();
```

### Verification Pattern

```java
// Basic verification
verify(mock).method();
verify(mock).method(arg);
verify(mock).method(argThat(predicate));

// Invocation count
verify(mock, times(3)).method();
verify(mock, never()).method();
verify(mock, atLeast(2)).method();
verify(mock, atMost(5)).method();
verify(mock, atLeastOnce()).method();

// Verification order
InOrder inOrder = inOrder(mock1, mock2);
inOrder.verify(mock1).method1();
inOrder.verify(mock2).method2();

// No interactions
verifyNoInteractions(mock);
verifyNoMoreInteractions(mock);

// Timeout (for async)
verify(mock, timeout(1000)).method();
```

### ArgumentCaptor Pattern

```java
// Create captor
@Captor
private ArgumentCaptor<User> userCaptor;

// Or manually
ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);

// Capture argument
verify(userRepository).save(userCaptor.capture());

// Get captured value
User captured = userCaptor.getValue();
assertEquals("John", captured.getName());

// Multiple captures
verify(mock, times(3)).method(captor.capture());
List<String> allValues = captor.getAllValues();
```

### MockMvc Pattern

```java
mockMvc.perform(
    get("/api/users/1")
        .accept(MediaType.APPLICATION_JSON)
        .header("Authorization", "Bearer token")
)
    .andExpect(status().isOk())
    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
    .andExpect(jsonPath("$.id").value(1))
    .andExpect(jsonPath("$.name").value("John"));
```

## HTTP Status Codes

### Common Status Codes

```java
// 2xx Success
status().isOk()                      // 200
status().isCreated()                 // 201
status().isAccepted()                // 202
status().isNoContent()               // 204

// 3xx Redirection
status().isMovedPermanently()        // 301
status().isFound()                   // 302
status().isNotModified()             // 304

// 4xx Client Error
status().isBadRequest()              // 400
status().isUnauthorized()            // 401
status().isForbidden()               // 403
status().isNotFound()                // 404
status().isMethodNotAllowed()        // 405
status().isConflict()                // 409
status().isUnprocessableEntity()     // 422

// 5xx Server Error
status().isInternalServerError()     // 500
status().isNotImplemented()          // 501
status().isBadGateway()              // 502
status().isServiceUnavailable()      // 503

// General
status().is2xxSuccessful()
status().is3xxRedirection()
status().is4xxClientError()
status().is5xxServerError()
```

## JSON Path Expressions

### Basic Selectors

```java
// Root element
$

// Property access
$.propertyName
$.user.name
$.user.address.city

// Array access
$.users[0]
$.users[1].name
$.users[-1]              // Last element

// All elements
$.users[*]
$.users[*].name

// Range
$.users[0:3]            // First 3 elements
$.users[-3:]            // Last 3 elements

// Filter
$.users[?(@.age > 18)]
$.users[?(@.name == 'John')]
$.users[?(@.active == true)]
```

### Common Assertions

```java
// Value assertions
.andExpect(jsonPath("$.name").value("John"))
.andExpect(jsonPath("$.age").value(25))
.andExpect(jsonPath("$.active").value(true))

// Existence
.andExpect(jsonPath("$.id").exists())
.andExpect(jsonPath("$.deletedAt").doesNotExist())

// Empty/null
.andExpect(jsonPath("$.list").isEmpty())
.andExpect(jsonPath("$.value").isNotEmpty())

// Array assertions
.andExpect(jsonPath("$", hasSize(3)))
.andExpect(jsonPath("$.users", hasSize(2)))
.andExpect(jsonPath("$.users[*].name", containsInAnyOrder("John", "Jane")))

// Type assertions
.andExpect(jsonPath("$.name").isString())
.andExpect(jsonPath("$.age").isNumber())
.andExpect(jsonPath("$.active").isBoolean())
.andExpect(jsonPath("$.users").isArray())

// Nested assertions
.andExpect(jsonPath("$.user.address.city").value("New York"))
.andExpect(jsonPath("$.users[0].email").value("john@example.com"))
```

### Complex Filters

```java
// Filter by property
jsonPath("$.users[?(@.age > 18)]")
jsonPath("$.users[?(@.name =~ /John.*/)]")     // Regex

// Multiple conditions
jsonPath("$.users[?(@.age > 18 && @.active == true)]")
jsonPath("$.users[?(@.age > 18 || @.verified == true)]")

// Nested property filter
jsonPath("$.users[?(@.address.city == 'New York')]")

// Array contains
jsonPath("$.users[?(@.roles contains 'ADMIN')]")
```

## TestContainers Quick Reference

### Common Containers

```java
// PostgreSQL
new PostgreSQLContainer<>("postgres:15-alpine")
    .withDatabaseName("testdb")
    .withUsername("test")
    .withPassword("test")

// MySQL
new MySQLContainer<>("mysql:8.0")
    .withDatabaseName("testdb")
    .withUsername("test")
    .withPassword("test")

// MongoDB
new MongoDBContainer("mongo:7")
    .withExposedPorts(27017)

// Redis
new GenericContainer<>("redis:7-alpine")
    .withExposedPorts(6379)

// Kafka
new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.5.0"))
```

### Dynamic Properties

```java
@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
    registry.add("spring.datasource.username", postgres::getUsername);
    registry.add("spring.datasource.password", postgres::getPassword);
}
```

## Test Data Builders

### Builder Pattern for Test Data

```java
public class UserTestBuilder {
    private Long id;
    private String name = "Test User";
    private String email = "test@example.com";
    private int age = 25;

    public static UserTestBuilder aUser() {
        return new UserTestBuilder();
    }

    public UserTestBuilder withId(Long id) {
        this.id = id;
        return this;
    }

    public UserTestBuilder withName(String name) {
        this.name = name;
        return this;
    }

    public UserTestBuilder withEmail(String email) {
        this.email = email;
        return this;
    }

    public UserTestBuilder withAge(int age) {
        this.age = age;
        return this;
    }

    public User build() {
        User user = new User(name, email);
        user.setId(id);
        user.setAge(age);
        return user;
    }
}

// Usage
User user = aUser()
    .withName("John")
    .withEmail("john@example.com")
    .withAge(30)
    .build();
```

## Summary

This quick reference covers:
- **JUnit 5**: Test lifecycle, parameterized tests, conditional execution
- **Mockito**: Mocking, stubbing, verification, argument matching
- **Spring Boot**: Test slices, configuration, security testing
- **Assertions**: JUnit, AssertJ, Hamcrest matchers
- **MockMvc**: HTTP testing, JSON path expressions
- **TestContainers**: Container setup, configuration
- **Patterns**: Given-When-Then, stubbing, verification, test builders

Keep this reference handy for quick lookups during test development!
