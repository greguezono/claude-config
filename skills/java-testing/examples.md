# Java Testing Examples

Complete, realistic testing examples for controllers, services, and repositories using JUnit 5, Mockito, Spring Boot, and TestContainers.

## Table of Contents

- [Controller Testing Examples](#controller-testing-examples)
- [Service Testing Examples](#service-testing-examples)
- [Repository Testing Examples](#repository-testing-examples)
- [Integration Testing Examples](#integration-testing-examples)
- [REST Client Testing Examples](#rest-client-testing-examples)
- [Security Testing Examples](#security-testing-examples)
- [Error Handling Examples](#error-handling-examples)
- [Async Testing Examples](#async-testing-examples)

## Controller Testing Examples

### Basic CRUD Controller Tests

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private UserService userService;

    @Nested
    @DisplayName("GET /api/users/{id}")
    class GetUser {

        @Test
        @DisplayName("Should return user when exists")
        void shouldReturnUserWhenExists() throws Exception {
            // Given
            Long userId = 1L;
            User user = new User(userId, "John Doe", "john@example.com");
            when(userService.getUser(userId)).thenReturn(user);

            // When & Then
            mockMvc.perform(get("/api/users/{id}", userId)
                    .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("John Doe"))
                .andExpect(jsonPath("$.email").value("john@example.com"));

            verify(userService).getUser(userId);
        }

        @Test
        @DisplayName("Should return 404 when user not found")
        void shouldReturn404WhenUserNotFound() throws Exception {
            // Given
            Long userId = 999L;
            when(userService.getUser(userId))
                .thenThrow(new UserNotFoundException("User not found with id: " + userId));

            // When & Then
            mockMvc.perform(get("/api/users/{id}", userId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("User not found with id: 999"));
        }
    }

    @Nested
    @DisplayName("POST /api/users")
    class CreateUser {

        @Test
        @DisplayName("Should create user with valid request")
        void shouldCreateUserWithValidRequest() throws Exception {
            // Given
            CreateUserRequest request = new CreateUserRequest("John Doe", "john@example.com");
            User createdUser = new User(1L, "John Doe", "john@example.com");

            when(userService.createUser(any(CreateUserRequest.class))).thenReturn(createdUser);

            // When & Then
            mockMvc.perform(post("/api/users")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/users/1"))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("John Doe"))
                .andExpect(jsonPath("$.email").value("john@example.com"));

            verify(userService).createUser(argThat(req ->
                req.getName().equals("John Doe") &&
                req.getEmail().equals("john@example.com")
            ));
        }

        @Test
        @DisplayName("Should return 400 when name is missing")
        void shouldReturn400WhenNameIsMissing() throws Exception {
            // Given
            CreateUserRequest request = new CreateUserRequest(null, "john@example.com");

            // When & Then
            mockMvc.perform(post("/api/users")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors").isArray())
                .andExpect(jsonPath("$.errors[*].field", hasItem("name")))
                .andExpect(jsonPath("$.errors[*].message", hasItem("Name is required")));

            verifyNoInteractions(userService);
        }

        @Test
        @DisplayName("Should return 400 when email is invalid")
        void shouldReturn400WhenEmailIsInvalid() throws Exception {
            // Given
            CreateUserRequest request = new CreateUserRequest("John", "invalid-email");

            // When & Then
            mockMvc.perform(post("/api/users")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[*].field", hasItem("email")))
                .andExpect(jsonPath("$.errors[*].message", hasItem("Invalid email format")));
        }

        @Test
        @DisplayName("Should return 409 when email already exists")
        void shouldReturn409WhenEmailAlreadyExists() throws Exception {
            // Given
            CreateUserRequest request = new CreateUserRequest("John", "john@example.com");
            when(userService.createUser(any()))
                .thenThrow(new EmailAlreadyExistsException("Email already registered"));

            // When & Then
            mockMvc.perform(post("/api/users")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("Email already registered"));
        }
    }

    @Nested
    @DisplayName("PUT /api/users/{id}")
    class UpdateUser {

        @Test
        @DisplayName("Should update user with valid request")
        void shouldUpdateUserWithValidRequest() throws Exception {
            // Given
            Long userId = 1L;
            UpdateUserRequest request = new UpdateUserRequest("Jane Doe", "jane@example.com");
            User updatedUser = new User(userId, "Jane Doe", "jane@example.com");

            when(userService.updateUser(eq(userId), any(UpdateUserRequest.class)))
                .thenReturn(updatedUser);

            // When & Then
            mockMvc.perform(put("/api/users/{id}", userId)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("Jane Doe"))
                .andExpect(jsonPath("$.email").value("jane@example.com"));
        }

        @Test
        @DisplayName("Should return 404 when updating non-existent user")
        void shouldReturn404WhenUpdatingNonExistentUser() throws Exception {
            // Given
            Long userId = 999L;
            UpdateUserRequest request = new UpdateUserRequest("Jane", "jane@example.com");

            when(userService.updateUser(eq(userId), any()))
                .thenThrow(new UserNotFoundException("User not found"));

            // When & Then
            mockMvc.perform(put("/api/users/{id}", userId)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());
        }
    }

    @Nested
    @DisplayName("DELETE /api/users/{id}")
    class DeleteUser {

        @Test
        @DisplayName("Should delete user successfully")
        void shouldDeleteUserSuccessfully() throws Exception {
            // Given
            Long userId = 1L;
            doNothing().when(userService).deleteUser(userId);

            // When & Then
            mockMvc.perform(delete("/api/users/{id}", userId))
                .andExpect(status().isNoContent());

            verify(userService).deleteUser(userId);
        }

        @Test
        @DisplayName("Should return 404 when deleting non-existent user")
        void shouldReturn404WhenDeletingNonExistentUser() throws Exception {
            // Given
            Long userId = 999L;
            doThrow(new UserNotFoundException("User not found"))
                .when(userService).deleteUser(userId);

            // When & Then
            mockMvc.perform(delete("/api/users/{id}", userId))
                .andExpect(status().isNotFound());
        }
    }

    @Nested
    @DisplayName("GET /api/users")
    class ListUsers {

        @Test
        @DisplayName("Should return paginated users")
        void shouldReturnPaginatedUsers() throws Exception {
            // Given
            List<User> users = Arrays.asList(
                new User(1L, "John", "john@example.com"),
                new User(2L, "Jane", "jane@example.com")
            );

            Page<User> page = new PageImpl<>(users, PageRequest.of(0, 10), 2);
            when(userService.getUsers(any(Pageable.class))).thenReturn(page);

            // When & Then
            mockMvc.perform(get("/api/users")
                    .param("page", "0")
                    .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.content[0].name").value("John"))
                .andExpect(jsonPath("$.content[1].name").value("Jane"))
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.totalPages").value(1))
                .andExpect(jsonPath("$.number").value(0));
        }

        @Test
        @DisplayName("Should return empty list when no users found")
        void shouldReturnEmptyListWhenNoUsersFound() throws Exception {
            // Given
            Page<User> emptyPage = new PageImpl<>(Collections.emptyList());
            when(userService.getUsers(any(Pageable.class))).thenReturn(emptyPage);

            // When & Then
            mockMvc.perform(get("/api/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)))
                .andExpect(jsonPath("$.totalElements").value(0));
        }

        @Test
        @DisplayName("Should filter users by name")
        void shouldFilterUsersByName() throws Exception {
            // Given
            List<User> users = Arrays.asList(
                new User(1L, "John Doe", "john@example.com")
            );

            when(userService.searchUsers(eq("John"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(users));

            // When & Then
            mockMvc.perform(get("/api/users")
                    .param("name", "John"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("John Doe"));
        }
    }
}
```

## Service Testing Examples

### Service Layer with Business Logic

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private EmailService emailService;

    @Mock
    private AuditService auditService;

    @InjectMocks
    private UserService userService;

    @Captor
    private ArgumentCaptor<User> userCaptor;

    @Nested
    @DisplayName("Create User")
    class CreateUserTests {

        @Test
        @DisplayName("Should create user with valid data")
        void shouldCreateUserWithValidData() {
            // Given
            CreateUserRequest request = new CreateUserRequest("John Doe", "john@example.com");
            User savedUser = new User(1L, "John Doe", "john@example.com");

            when(userRepository.existsByEmail(request.getEmail())).thenReturn(false);
            when(userRepository.save(any(User.class))).thenReturn(savedUser);
            doNothing().when(emailService).sendWelcomeEmail(anyString());
            doNothing().when(auditService).logUserCreation(anyLong());

            // When
            User result = userService.createUser(request);

            // Then
            assertNotNull(result);
            assertEquals(1L, result.getId());
            assertEquals("John Doe", result.getName());
            assertEquals("john@example.com", result.getEmail());

            // Verify interactions
            verify(userRepository).existsByEmail("john@example.com");
            verify(userRepository).save(userCaptor.capture());
            verify(emailService).sendWelcomeEmail("john@example.com");
            verify(auditService).logUserCreation(1L);

            // Verify captured user
            User captured = userCaptor.getValue();
            assertEquals("John Doe", captured.getName());
            assertEquals("john@example.com", captured.getEmail());
            assertNotNull(captured.getCreatedAt());
        }

        @Test
        @DisplayName("Should throw exception when email already exists")
        void shouldThrowExceptionWhenEmailAlreadyExists() {
            // Given
            CreateUserRequest request = new CreateUserRequest("John", "john@example.com");
            when(userRepository.existsByEmail(request.getEmail())).thenReturn(true);

            // When & Then
            assertThrows(EmailAlreadyExistsException.class,
                () -> userService.createUser(request));

            verify(userRepository).existsByEmail("john@example.com");
            verify(userRepository, never()).save(any());
            verifyNoInteractions(emailService, auditService);
        }

        @Test
        @DisplayName("Should rollback when email sending fails")
        void shouldRollbackWhenEmailSendingFails() {
            // Given
            CreateUserRequest request = new CreateUserRequest("John", "john@example.com");
            User savedUser = new User(1L, "John", "john@example.com");

            when(userRepository.existsByEmail(anyString())).thenReturn(false);
            when(userRepository.save(any())).thenReturn(savedUser);
            doThrow(new EmailServiceException("Failed to send email"))
                .when(emailService).sendWelcomeEmail(anyString());

            // When & Then
            assertThrows(EmailServiceException.class,
                () -> userService.createUser(request));

            verify(emailService).sendWelcomeEmail("john@example.com");
            verifyNoInteractions(auditService);
        }
    }

    @Nested
    @DisplayName("Get User")
    class GetUserTests {

        @Test
        @DisplayName("Should return user when exists")
        void shouldReturnUserWhenExists() {
            // Given
            Long userId = 1L;
            User user = new User(userId, "John", "john@example.com");
            when(userRepository.findById(userId)).thenReturn(Optional.of(user));

            // When
            User result = userService.getUser(userId);

            // Then
            assertNotNull(result);
            assertEquals(userId, result.getId());
            assertEquals("John", result.getName());
            verify(userRepository).findById(userId);
        }

        @Test
        @DisplayName("Should throw exception when user not found")
        void shouldThrowExceptionWhenUserNotFound() {
            // Given
            Long userId = 999L;
            when(userRepository.findById(userId)).thenReturn(Optional.empty());

            // When & Then
            UserNotFoundException exception = assertThrows(
                UserNotFoundException.class,
                () -> userService.getUser(userId)
            );

            assertEquals("User not found with id: 999", exception.getMessage());
            verify(userRepository).findById(userId);
        }
    }

    @Nested
    @DisplayName("Update User")
    class UpdateUserTests {

        @Test
        @DisplayName("Should update user successfully")
        void shouldUpdateUserSuccessfully() {
            // Given
            Long userId = 1L;
            User existingUser = new User(userId, "John", "john@example.com");
            UpdateUserRequest request = new UpdateUserRequest("Jane Doe", "jane@example.com");

            when(userRepository.findById(userId)).thenReturn(Optional.of(existingUser));
            when(userRepository.existsByEmailAndIdNot("jane@example.com", userId))
                .thenReturn(false);
            when(userRepository.save(any(User.class))).thenAnswer(invocation ->
                invocation.getArgument(0));

            // When
            User result = userService.updateUser(userId, request);

            // Then
            assertEquals("Jane Doe", result.getName());
            assertEquals("jane@example.com", result.getEmail());
            assertNotNull(result.getUpdatedAt());

            verify(userRepository).save(userCaptor.capture());

            User captured = userCaptor.getValue();
            assertEquals(userId, captured.getId());
            assertEquals("Jane Doe", captured.getName());
        }

        @Test
        @DisplayName("Should throw exception when updating to existing email")
        void shouldThrowExceptionWhenUpdatingToExistingEmail() {
            // Given
            Long userId = 1L;
            User existingUser = new User(userId, "John", "john@example.com");
            UpdateUserRequest request = new UpdateUserRequest("John", "existing@example.com");

            when(userRepository.findById(userId)).thenReturn(Optional.of(existingUser));
            when(userRepository.existsByEmailAndIdNot("existing@example.com", userId))
                .thenReturn(true);

            // When & Then
            assertThrows(EmailAlreadyExistsException.class,
                () -> userService.updateUser(userId, request));

            verify(userRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Delete User")
    class DeleteUserTests {

        @Test
        @DisplayName("Should delete user successfully")
        void shouldDeleteUserSuccessfully() {
            // Given
            Long userId = 1L;
            User user = new User(userId, "John", "john@example.com");

            when(userRepository.findById(userId)).thenReturn(Optional.of(user));
            doNothing().when(userRepository).delete(user);
            doNothing().when(auditService).logUserDeletion(userId);

            // When
            userService.deleteUser(userId);

            // Then
            verify(userRepository).findById(userId);
            verify(userRepository).delete(user);
            verify(auditService).logUserDeletion(userId);
        }

        @Test
        @DisplayName("Should throw exception when deleting non-existent user")
        void shouldThrowExceptionWhenDeletingNonExistentUser() {
            // Given
            Long userId = 999L;
            when(userRepository.findById(userId)).thenReturn(Optional.empty());

            // When & Then
            assertThrows(UserNotFoundException.class,
                () -> userService.deleteUser(userId));

            verify(userRepository).findById(userId);
            verify(userRepository, never()).delete(any());
            verifyNoInteractions(auditService);
        }
    }

    @Nested
    @DisplayName("Business Logic")
    class BusinessLogicTests {

        @Test
        @DisplayName("Should deactivate inactive users")
        void shouldDeactivateInactiveUsers() {
            // Given
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(90);
            List<User> inactiveUsers = Arrays.asList(
                new User(1L, "User1", "user1@example.com"),
                new User(2L, "User2", "user2@example.com")
            );

            when(userRepository.findByLastLoginBefore(any(LocalDateTime.class)))
                .thenReturn(inactiveUsers);
            when(userRepository.saveAll(anyList())).thenReturn(inactiveUsers);

            // When
            int deactivated = userService.deactivateInactiveUsers();

            // Then
            assertEquals(2, deactivated);

            verify(userRepository).findByLastLoginBefore(argThat(date ->
                date.isBefore(LocalDateTime.now()) &&
                date.isAfter(LocalDateTime.now().minusDays(91))
            ));

            verify(userRepository).saveAll(argThat(users -> {
                List<User> userList = (List<User>) users;
                return userList.size() == 2 &&
                       userList.stream().allMatch(u -> !u.isActive());
            }));
        }

        @Test
        @DisplayName("Should calculate user statistics correctly")
        void shouldCalculateUserStatisticsCorrectly() {
            // Given
            when(userRepository.count()).thenReturn(100L);
            when(userRepository.countByActive(true)).thenReturn(75L);
            when(userRepository.countByActive(false)).thenReturn(25L);
            when(userRepository.countByCreatedAtAfter(any()))
                .thenReturn(10L);

            // When
            UserStatistics stats = userService.getUserStatistics();

            // Then
            assertEquals(100L, stats.getTotalUsers());
            assertEquals(75L, stats.getActiveUsers());
            assertEquals(25L, stats.getInactiveUsers());
            assertEquals(10L, stats.getNewUsersThisMonth());
            assertEquals(0.75, stats.getActivePercentage(), 0.01);
        }
    }
}
```

## Repository Testing Examples

### JPA Repository Tests

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
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

    @Autowired
    private TestEntityManager entityManager;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Nested
    @DisplayName("Save Operations")
    class SaveOperations {

        @Test
        @DisplayName("Should save user with auto-generated ID")
        void shouldSaveUserWithAutoGeneratedId() {
            // Given
            User user = new User("John Doe", "john@example.com");

            // When
            User saved = userRepository.save(user);

            // Then
            assertNotNull(saved.getId());
            assertEquals("John Doe", saved.getName());
            assertEquals("john@example.com", saved.getEmail());
            assertNotNull(saved.getCreatedAt());

            // Verify in database
            User found = entityManager.find(User.class, saved.getId());
            assertEquals("John Doe", found.getName());
        }

        @Test
        @DisplayName("Should update existing user")
        void shouldUpdateExistingUser() {
            // Given
            User user = new User("John", "john@example.com");
            User saved = userRepository.save(user);

            // When
            saved.setName("Jane Doe");
            saved.setEmail("jane@example.com");
            User updated = userRepository.save(saved);

            // Then
            assertEquals(saved.getId(), updated.getId());
            assertEquals("Jane Doe", updated.getName());
            assertEquals("jane@example.com", updated.getEmail());

            // Verify in database
            entityManager.flush();
            entityManager.clear();
            User found = userRepository.findById(saved.getId()).orElseThrow();
            assertEquals("Jane Doe", found.getName());
        }
    }

    @Nested
    @DisplayName("Find Operations")
    class FindOperations {

        @Test
        @DisplayName("Should find user by email")
        void shouldFindUserByEmail() {
            // Given
            User user = new User("John", "john@example.com");
            entityManager.persist(user);
            entityManager.flush();

            // When
            Optional<User> found = userRepository.findByEmail("john@example.com");

            // Then
            assertTrue(found.isPresent());
            assertEquals("John", found.get().getName());
        }

        @Test
        @DisplayName("Should return empty when email not found")
        void shouldReturnEmptyWhenEmailNotFound() {
            // When
            Optional<User> found = userRepository.findByEmail("nonexistent@example.com");

            // Then
            assertFalse(found.isPresent());
        }

        @Test
        @DisplayName("Should find users by active status")
        void shouldFindUsersByActiveStatus() {
            // Given
            User activeUser1 = new User("John", "john@example.com");
            activeUser1.setActive(true);
            User activeUser2 = new User("Jane", "jane@example.com");
            activeUser2.setActive(true);
            User inactiveUser = new User("Bob", "bob@example.com");
            inactiveUser.setActive(false);

            entityManager.persist(activeUser1);
            entityManager.persist(activeUser2);
            entityManager.persist(inactiveUser);
            entityManager.flush();

            // When
            List<User> activeUsers = userRepository.findByActive(true);

            // Then
            assertEquals(2, activeUsers.size());
            assertTrue(activeUsers.stream().allMatch(User::isActive));
        }
    }

    @Nested
    @DisplayName("Custom Queries")
    class CustomQueries {

        @Test
        @DisplayName("Should find users by name containing")
        void shouldFindUsersByNameContaining() {
            // Given
            entityManager.persist(new User("John Doe", "john@example.com"));
            entityManager.persist(new User("Jane Doe", "jane@example.com"));
            entityManager.persist(new User("Bob Smith", "bob@example.com"));
            entityManager.flush();

            // When
            List<User> users = userRepository.findByNameContainingIgnoreCase("doe");

            // Then
            assertEquals(2, users.size());
            assertTrue(users.stream()
                .allMatch(u -> u.getName().toLowerCase().contains("doe")));
        }

        @Test
        @DisplayName("Should find users created after date")
        void shouldFindUsersCreatedAfterDate() {
            // Given
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(7);

            User oldUser = new User("Old User", "old@example.com");
            oldUser.setCreatedAt(LocalDateTime.now().minusDays(10));

            User newUser = new User("New User", "new@example.com");
            newUser.setCreatedAt(LocalDateTime.now().minusDays(3));

            entityManager.persist(oldUser);
            entityManager.persist(newUser);
            entityManager.flush();

            // When
            List<User> recentUsers = userRepository.findByCreatedAtAfter(cutoffDate);

            // Then
            assertEquals(1, recentUsers.size());
            assertEquals("New User", recentUsers.get(0).getName());
        }

        @Test
        @DisplayName("Should count users by active status")
        void shouldCountUsersByActiveStatus() {
            // Given
            entityManager.persist(createActiveUser("User1"));
            entityManager.persist(createActiveUser("User2"));
            entityManager.persist(createInactiveUser("User3"));
            entityManager.flush();

            // When
            long activeCount = userRepository.countByActive(true);
            long inactiveCount = userRepository.countByActive(false);

            // Then
            assertEquals(2, activeCount);
            assertEquals(1, inactiveCount);
        }

        private User createActiveUser(String name) {
            User user = new User(name, name.toLowerCase() + "@example.com");
            user.setActive(true);
            return user;
        }

        private User createInactiveUser(String name) {
            User user = new User(name, name.toLowerCase() + "@example.com");
            user.setActive(false);
            return user;
        }
    }

    @Nested
    @DisplayName("Delete Operations")
    class DeleteOperations {

        @Test
        @DisplayName("Should delete user by ID")
        void shouldDeleteUserById() {
            // Given
            User user = new User("John", "john@example.com");
            entityManager.persist(user);
            entityManager.flush();
            Long userId = user.getId();

            // When
            userRepository.deleteById(userId);
            entityManager.flush();

            // Then
            User found = entityManager.find(User.class, userId);
            assertNull(found);
        }

        @Test
        @DisplayName("Should delete all users")
        void shouldDeleteAllUsers() {
            // Given
            entityManager.persist(new User("User1", "user1@example.com"));
            entityManager.persist(new User("User2", "user2@example.com"));
            entityManager.flush();

            // When
            userRepository.deleteAll();
            entityManager.flush();

            // Then
            assertEquals(0, userRepository.count());
        }
    }
}
```

## Integration Testing Examples

### Full Stack Integration Test

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
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
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Should create, retrieve, update, and delete user")
    void shouldPerformFullCRUDOperations() {
        // Create user
        CreateUserRequest createRequest = new CreateUserRequest("John Doe", "john@example.com");

        ResponseEntity<User> createResponse = restTemplate.postForEntity(
            "/api/users",
            createRequest,
            User.class
        );

        assertEquals(HttpStatus.CREATED, createResponse.getStatusCode());
        assertNotNull(createResponse.getBody());
        Long userId = createResponse.getBody().getId();

        // Retrieve user
        ResponseEntity<User> getResponse = restTemplate.getForEntity(
            "/api/users/" + userId,
            User.class
        );

        assertEquals(HttpStatus.OK, getResponse.getStatusCode());
        assertEquals("John Doe", getResponse.getBody().getName());

        // Update user
        UpdateUserRequest updateRequest = new UpdateUserRequest("Jane Doe", "jane@example.com");

        restTemplate.put("/api/users/" + userId, updateRequest);

        ResponseEntity<User> updatedResponse = restTemplate.getForEntity(
            "/api/users/" + userId,
            User.class
        );

        assertEquals("Jane Doe", updatedResponse.getBody().getName());
        assertEquals("jane@example.com", updatedResponse.getBody().getEmail());

        // Delete user
        restTemplate.delete("/api/users/" + userId);

        ResponseEntity<String> deletedResponse = restTemplate.getForEntity(
            "/api/users/" + userId,
            String.class
        );

        assertEquals(HttpStatus.NOT_FOUND, deletedResponse.getStatusCode());
    }

    @Test
    @DisplayName("Should enforce business rules across layers")
    void shouldEnforceBusinessRulesAcrossLayers() {
        // Given - Create first user
        CreateUserRequest request1 = new CreateUserRequest("John", "john@example.com");
        restTemplate.postForEntity("/api/users", request1, User.class);

        // When - Try to create user with same email
        CreateUserRequest request2 = new CreateUserRequest("Jane", "john@example.com");
        ResponseEntity<String> response = restTemplate.postForEntity(
            "/api/users",
            request2,
            String.class
        );

        // Then
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
        assertTrue(response.getBody().contains("Email already registered"));

        // Verify only one user exists
        assertEquals(1, userRepository.count());
    }
}
```

## REST Client Testing Examples

### External API Client Tests

```java
@RestClientTest(UserServiceClient.class)
class UserServiceClientTest {

    @Autowired
    private UserServiceClient client;

    @Autowired
    private MockRestServiceServer server;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("Should get user from external service")
    void shouldGetUserFromExternalService() throws JsonProcessingException {
        // Given
        User expectedUser = new User(1L, "John", "john@example.com");
        String responseBody = objectMapper.writeValueAsString(expectedUser);

        server.expect(requestTo("/api/users/1"))
            .andExpect(method(HttpMethod.GET))
            .andExpect(header("Accept", MediaType.APPLICATION_JSON_VALUE))
            .andRespond(withSuccess(responseBody, MediaType.APPLICATION_JSON));

        // When
        User user = client.getUser(1L);

        // Then
        assertEquals(1L, user.getId());
        assertEquals("John", user.getName());
        server.verify();
    }

    @Test
    @DisplayName("Should handle 404 response")
    void shouldHandle404Response() {
        // Given
        server.expect(requestTo("/api/users/999"))
            .andExpect(method(HttpMethod.GET))
            .andRespond(withStatus(HttpStatus.NOT_FOUND));

        // When & Then
        assertThrows(UserNotFoundException.class, () -> client.getUser(999L));

        server.verify();
    }

    @Test
    @DisplayName("Should create user via external service")
    void shouldCreateUserViaExternalService() throws JsonProcessingException {
        // Given
        CreateUserRequest request = new CreateUserRequest("John", "john@example.com");
        User createdUser = new User(1L, "John", "john@example.com");

        String requestBody = objectMapper.writeValueAsString(request);
        String responseBody = objectMapper.writeValueAsString(createdUser);

        server.expect(requestTo("/api/users"))
            .andExpect(method(HttpMethod.POST))
            .andExpect(content().json(requestBody))
            .andRespond(withCreatedEntity(URI.create("/api/users/1"))
                .body(responseBody)
                .contentType(MediaType.APPLICATION_JSON));

        // When
        User user = client.createUser(request);

        // Then
        assertEquals(1L, user.getId());
        assertEquals("John", user.getName());
        server.verify();
    }
}
```

## Security Testing Examples

### Authentication and Authorization Tests

```java
@WebMvcTest(UserController.class)
@Import(SecurityConfig.class)
class UserControllerSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    @DisplayName("Should deny access without authentication")
    void shouldDenyAccessWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "user@example.com", roles = "USER")
    @DisplayName("Should allow user to read their own profile")
    void shouldAllowUserToReadOwnProfile() throws Exception {
        // Given
        User user = new User(1L, "User", "user@example.com");
        when(userService.getCurrentUser()).thenReturn(user);

        // When & Then
        mockMvc.perform(get("/api/users/me"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("user@example.com"));
    }

    @Test
    @WithMockUser(roles = "USER")
    @DisplayName("Should deny user from deleting other users")
    void shouldDenyUserFromDeletingOthers() throws Exception {
        mockMvc.perform(delete("/api/users/1"))
            .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    @DisplayName("Should allow admin to delete users")
    void shouldAllowAdminToDeleteUsers() throws Exception {
        // Given
        doNothing().when(userService).deleteUser(1L);

        // When & Then
        mockMvc.perform(delete("/api/users/1"))
            .andExpect(status().isNoContent());

        verify(userService).deleteUser(1L);
    }
}
```

## Error Handling Examples

### Exception Handling Tests

```java
@WebMvcTest(UserController.class)
class UserControllerExceptionHandlingTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    @DisplayName("Should handle validation errors")
    void shouldHandleValidationErrors() throws Exception {
        // Given - Invalid request with multiple validation errors
        String invalidRequest = """
            {
                "name": "",
                "email": "invalid-email"
            }
            """;

        // When & Then
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidRequest))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors").isArray())
            .andExpect(jsonPath("$.errors[*].field",
                containsInAnyOrder("name", "email")))
            .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    @DisplayName("Should handle internal server errors")
    void shouldHandleInternalServerErrors() throws Exception {
        // Given
        when(userService.getUser(1L))
            .thenThrow(new RuntimeException("Database connection failed"));

        // When & Then
        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.error").value("Internal server error"))
            .andExpect(jsonPath("$.message").exists())
            .andExpect(jsonPath("$.timestamp").exists());
    }
}
```

## Async Testing Examples

### Asynchronous Operations Tests

```java
@SpringBootTest
class AsyncUserServiceTest {

    @Autowired
    private AsyncUserService asyncUserService;

    @MockBean
    private EmailService emailService;

    @Test
    @DisplayName("Should process users asynchronously")
    void shouldProcessUsersAsynchronously() throws Exception {
        // Given
        List<Long> userIds = Arrays.asList(1L, 2L, 3L);
        doNothing().when(emailService).sendEmail(anyString());

        // When
        CompletableFuture<Void> future = asyncUserService.processUsersAsync(userIds);

        // Wait for completion
        future.get(5, TimeUnit.SECONDS);

        // Then
        verify(emailService, times(3)).sendEmail(anyString());
    }

    @Test
    @DisplayName("Should handle async exceptions")
    void shouldHandleAsyncExceptions() {
        // Given
        doThrow(new RuntimeException("Email service down"))
            .when(emailService).sendEmail(anyString());

        // When
        CompletableFuture<Void> future = asyncUserService.processUsersAsync(Arrays.asList(1L));

        // Then
        assertThrows(ExecutionException.class, () ->
            future.get(5, TimeUnit.SECONDS));
    }
}
```

## Summary

These examples demonstrate:

**Controller Testing:**
- Complete CRUD operations with MockMvc
- Request validation
- Error handling
- Pagination and filtering

**Service Testing:**
- Business logic testing with mocks
- Transaction handling
- Exception scenarios
- Complex workflows

**Repository Testing:**
- Custom queries with TestContainers
- CRUD operations
- JPA-specific features

**Integration Testing:**
- End-to-end flows
- Multi-layer testing
- Business rule enforcement

**REST Client Testing:**
- External API mocking
- Response handling
- Error scenarios

**Security Testing:**
- Authentication
- Authorization
- Role-based access

**Error Handling:**
- Validation errors
- Business exceptions
- System errors

**Async Testing:**
- CompletableFuture testing
- Timeout handling
- Exception propagation

All examples follow Given-When-Then structure and demonstrate real-world testing scenarios.
