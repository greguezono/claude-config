# Spring Boot Testing and TestContainers

## Overview

Spring Boot Test provides test slices (`@WebMvcTest`, `@DataJpaTest`) for fast, focused tests. TestContainers enables Docker-based integration testing with real databases. Together they provide comprehensive testing from fast unit tests to realistic integration tests.

---

## Part 1: Spring Boot Test Slices

### Performance Comparison

| Test Type | Annotation | Startup | Use Case |
|-----------|-----------|---------|----------|
| Unit | `@ExtendWith(MockitoExtension.class)` | <10ms | Service logic |
| Controller | `@WebMvcTest` | 200-500ms | REST endpoints |
| Repository | `@DataJpaTest` | 500-1000ms | Database queries |
| Full | `@SpringBootTest` | 3-5s | End-to-end |

**Key insight:** Test slices are 5-10x faster than `@SpringBootTest`

### @WebMvcTest (Controller Testing)

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean  // Spring's @MockBean, not Mockito's @Mock
    private UserService userService;

    @Test
    void shouldReturnUser() throws Exception {
        // Given
        UserDTO user = new UserDTO(1L, "john@example.com", "John", "Doe");
        when(userService.findById(1L)).thenReturn(Optional.of(user));

        // When/Then
        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("john@example.com"));

        verify(userService).findById(1L);
    }

    @Test
    void shouldCreateUser() throws Exception {
        // Given
        UserDTO user = new UserDTO(1L, "jane@example.com", "Jane", "Smith");
        when(userService.create(any(CreateUserRequest.class))).thenReturn(user);

        String requestBody = """
            {
                "email": "jane@example.com",
                "password": "password123",
                "firstName": "Jane",
                "lastName": "Smith"
            }
            """;

        // When/Then
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("jane@example.com"));
    }

    @Test
    void shouldReturn404WhenUserNotFound() throws Exception {
        when(userService.findById(999L))
            .thenReturn(Optional.empty());

        mockMvc.perform(get("/api/v1/users/999"))
            .andExpect(status().isNotFound());
    }
}
```

### @DataJpaTest (Repository Testing)

```java
@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldFindUserByEmail() {
        // Given
        User user = new User("test@example.com");
        entityManager.persistAndFlush(user);

        // When
        Optional<User> found = userRepository.findByEmail("test@example.com");

        // Then
        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("test@example.com");
    }

    @Test
    void shouldReturnEmptyWhenUserNotFound() {
        Optional<User> found = userRepository.findByEmail("nonexistent@example.com");
        assertThat(found).isEmpty();
    }
}
```

### @SpringBootTest (Full Integration)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class UserApiIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void shouldCreateUserViaApi() {
        CreateUserRequest request = new CreateUserRequest(
            "john@example.com", "password123", "John", "Doe"
        );

        ResponseEntity<UserDTO> response = restTemplate.postForEntity(
            "/api/v1/users",
            request,
            UserDTO.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getId()).isNotNull();
    }
}
```

### Test Configuration Reuse

```java
// Shared config - reuses context across tests
@TestConfiguration
public class SharedTestConfig {

    @Bean
    public Clock testClock() {
        return Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneId.of("UTC"));
    }
}

// Import in multiple tests
@WebMvcTest(UserController.class)
@Import(SharedTestConfig.class)
class UserControllerTest {
    // Shares context with other tests using SharedTestConfig
}
```

---

## Part 2: TestContainers

### Basic Setup

```java
@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldPersistUser() {
        User user = new User("test@example.com");
        User saved = userRepository.save(user);

        assertThat(saved.getId()).isNotNull();
        assertThat(userRepository.findById(saved.getId())).isPresent();
    }
}
```

### Singleton Container Pattern (Performance)

```java
// Base class with shared container - much faster
public abstract class AbstractIntegrationTest {

    static final PostgreSQLContainer<?> POSTGRES;

    static {
        POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withReuse(true);  // Reuse between test runs
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }
}

// Tests extend base - no container startup cost
@SpringBootTest
class UserRepositoryTest extends AbstractIntegrationTest {
    // Container already running
}
```

### MySQL Container

```java
@Container
static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
    .withDatabaseName("testdb")
    .withUsername("test")
    .withPassword("test")
    .withCommand("--character-set-server=utf8mb4");
```

### Multiple Containers

```java
@SpringBootTest
@Testcontainers
class CacheIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine");

    @Container
    static GenericContainer<?> redis =
        new GenericContainer<>("redis:7-alpine")
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // Database
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);

        // Redis
        registry.add("spring.redis.host", redis::getHost);
        registry.add("spring.redis.port", redis::getFirstMappedPort);
    }
}
```

## Best Practices

### Spring Boot Testing

**DO:**
- ✅ Use test slices (`@WebMvcTest`, `@DataJpaTest`) when possible
- ✅ Share `@TestConfiguration` across tests for context reuse
- ✅ Use `@MockBean` for external dependencies
- ✅ Keep tests isolated and independent

**DON'T:**
- ❌ Use `@SpringBootTest` for everything (slow)
- ❌ Create unique `@MockBean` in every test (breaks context reuse)
- ❌ Overuse `@DirtiesContext` (expensive)
- ❌ Test implementation details instead of behavior

### TestContainers

**DO:**
- ✅ Use singleton pattern for speed
- ✅ Test against production database
- ✅ Use `@DynamicPropertySource` for Spring integration
- ✅ Enable `.withReuse(true)` in development

**DON'T:**
- ❌ Create new container per test class (slow)
- ❌ Forget `@Testcontainers` annotation
- ❌ Test with H2 when production uses PostgreSQL/MySQL
- ❌ Leave containers running (use `@Container` for auto-cleanup)

## Testing Performance Tips

1. **Maximize context reuse** - Use shared `@TestConfiguration`
2. **Use test slices** - 5-10x faster than `@SpringBootTest`
3. **Singleton containers** - Reuse across test classes
4. **Avoid `@DirtiesContext`** - Restructure tests instead
5. **Mock external APIs** - Don't make real HTTP calls
6. **Use in-memory databases for unit tests** - Save containers for integration tests

## Further Reading

- [Spring Boot Testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
- [TestContainers](https://java.testcontainers.org/)
- [Spring Boot Test Slices](https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html#testing.spring-boot-applications.autoconfigured-tests)
