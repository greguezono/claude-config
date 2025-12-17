# Spring Security Patterns

## Overview

Spring Security 6 introduces a modernized configuration approach using `SecurityFilterChain` beans instead of the deprecated `WebSecurityConfigurerAdapter`. This guide covers authentication, authorization, JWT, and OAuth2 patterns for Spring Boot 3.x.

## Modern Security Configuration

### Basic Security Filter Chain

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // Enables @PreAuthorize, @PostAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())  // Disable for stateless JWT APIs
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/api/v1/public/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/v1/users/**").hasAnyRole("USER", "ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/v1/users/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.decoder(jwtDecoder()))
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

## JWT Authentication

### JWT Configuration

```java
@Configuration
public class JwtConfig {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.expiration:86400000}")  // 24 hours
    private long jwtExpiration;

    @Bean
    public JwtDecoder jwtDecoder() {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        return NimbusJwtDecoder.withSecretKey(key).build();
    }

    @Bean
    public JwtEncoder jwtEncoder() {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        return new NimbusJwtEncoder(new ImmutableSecret<>(key));
    }
}
```

### JWT Service

```java
@Service
public class JwtService {
    private final JwtEncoder jwtEncoder;
    private final long jwtExpiration;

    public JwtService(JwtEncoder jwtEncoder,
                     @Value("${jwt.expiration:86400000}") long jwtExpiration) {
        this.jwtEncoder = jwtEncoder;
        this.jwtExpiration = jwtExpiration;
    }

    public String generateToken(UserDetails userDetails) {
        Instant now = Instant.now();
        Instant expiration = now.plusMillis(jwtExpiration);

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer("self")
            .issuedAt(now)
            .expiresAt(expiration)
            .subject(userDetails.getUsername())
            .claim("roles", userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .toList())
            .build();

        return jwtEncoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
    }
}
```

### Authentication Controller

```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final UserService userService;

    @PostMapping("/login")
    public ResponseEntity<JwtResponse> login(@Valid @RequestBody LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.username(), request.password())
        );

        SecurityContextHolder.getContext().setAuthentication(authentication);
        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        String jwt = jwtService.generateToken(userDetails);

        return ResponseEntity.ok(new JwtResponse(jwt));
    }

    @PostMapping("/register")
    public ResponseEntity<UserDTO> register(@Valid @RequestBody RegisterRequest request) {
        UserDTO user = userService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(user);
    }
}

public record LoginRequest(@NotBlank String username, @NotBlank String password) {}
public record JwtResponse(String token) {}
```

## OAuth2 Resource Server

### Configuration

```properties
# application.properties
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://auth-server.com
# OR
spring.security.oauth2.resourceserver.jwt.jwk-set-uri=https://auth-server.com/.well-known/jwks.json
```

```java
@Configuration
@EnableWebSecurity
public class OAuth2Config {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/public/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter()))
            );

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthConverter() {
        JwtGrantedAuthoritiesConverter authConverter =
            new JwtGrantedAuthoritiesConverter();
        authConverter.setAuthoritiesClaimName("roles");
        authConverter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authConverter);
        return converter;
    }
}
```

## Method Security

```java
@Service
public class UserService {

    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(Long id) {
        userRepository.deleteById(id);
    }

    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public UserDTO getUser(Long id) {
        return userRepository.findById(id).map(this::toDTO)
            .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    @PreAuthorize("#id == authentication.principal.id or hasRole('ADMIN')")
    public UserDTO updateUser(Long id, UpdateUserRequest request) {
        // Users can update themselves, admins can update anyone
        return doUpdate(id, request);
    }

    @PostAuthorize("returnObject.email == authentication.principal.username or hasRole('ADMIN')")
    public UserDTO getUserDetails(Long id) {
        // Check after execution
        return userRepository.findById(id).map(this::toDTO)
            .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    @PreAuthorize("@userSecurity.canAccess(#id)")
    public UserDTO getUser(Long id) {
        // Custom security check
        return findById(id);
    }
}

@Component("userSecurity")
public class UserSecurity {
    public boolean canAccess(Long userId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        // Custom authorization logic
        return true;
    }
}
```

## UserDetailsService Implementation

```java
@Service
public class CustomUserDetailsService implements UserDetailsService {
    private final UserRepository userRepository;

    public CustomUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findByEmail(username)
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));

        return org.springframework.security.core.userdetails.User.builder()
            .username(user.getEmail())
            .password(user.getPassword())
            .authorities(user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.getName()))
                .toList())
            .accountExpired(!user.isActive())
            .accountLocked(user.isLocked())
            .disabled(!user.isActive())
            .build();
    }
}
```

## Password Encoding

```java
@Service
public class UserService {
    private final PasswordEncoder passwordEncoder;

    public UserDTO register(RegisterRequest request) {
        User user = new User();
        user.setEmail(request.email());
        user.setPassword(passwordEncoder.encode(request.password()));

        return toDTO(userRepository.save(user));
    }

    public void changePassword(Long userId, String oldPassword, String newPassword) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            throw new BadCredentialsException("Incorrect password");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }
}
```

## CORS Configuration

```java
@Configuration
public class CorsConfig {

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:3000", "https://app.example.com"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        config.setExposedHeaders(List.of("Authorization"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}

// Add to SecurityFilterChain
http.cors(cors -> cors.configurationSource(corsConfigurationSource()))
```

## Best Practices

### ✅ DO

- Use `SecurityFilterChain` bean (not deprecated `WebSecurityConfigurerAdapter`)
- Use Spring's OAuth2 Resource Server for JWT
- Store secrets in environment variables
- Use `BCryptPasswordEncoder` for passwords
- Enable method security with `@EnableMethodSecurity`
- Use stateless sessions for JWT APIs
- Configure CORS properly
- Set reasonable JWT expiration times
- Implement token refresh

### ❌ DON'T

- Use `WebSecurityConfigurerAdapter` (deprecated)
- Use `@EnableGlobalMethodSecurity` (deprecated, use `@EnableMethodSecurity`)
- Store passwords in plain text
- Use weak JWT secrets (<256 bits)
- Store secrets in code or version control
- Allow CORS from all origins in production
- Disable CSRF for session-based auth
- Use symmetric keys (HMAC) for multi-service JWT

## Common Pitfalls

**Authority Prefix:**
- `hasRole('ADMIN')` checks for `ROLE_ADMIN` authority
- Spring Security expects `ROLE_` prefix

**CSRF:**
- Only disable for stateless APIs (JWT)
- Keep enabled for session-based authentication

**Password Encoding:**
- Encode passwords before storing: `passwordEncoder.encode()`
- Validate with: `passwordEncoder.matches(raw, encoded)`

## Further Reading

- [Spring Security Reference](https://docs.spring.io/spring-security/reference/)
- [OAuth 2.0 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
