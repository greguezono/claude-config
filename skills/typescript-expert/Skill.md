---
name: typescript-expert
description: Senior TypeScript engineer specializing in type-safe patterns, modern TypeScript features (5.0+), testing strategies, project configuration, and framework integration. Expert in type system best practices, strict mode, generics, utility types, performance optimization, and full-stack TypeScript development with React, Node.js, Next.js/Remix, tRPC, and modern ORMs.
---

# TypeScript Expert Skill

## Overview

The TypeScript Expert skill provides comprehensive expertise for building production-grade TypeScript applications with modern best practices, type-safe patterns, and optimal tooling configurations. It covers the TypeScript type system, advanced type patterns, testing strategies, project setup, performance optimization, and integration with modern frameworks and libraries.

This skill consolidates proven patterns from TypeScript 5.0+ features, industry best practices, and real-world production systems. It emphasizes type safety, developer experience, and performance while avoiding common anti-patterns.

Whether building new TypeScript projects, migrating from JavaScript, optimizing existing codebases, or integrating with modern frameworks, this skill provides the patterns, anti-patterns, and decision-making frameworks needed for effective TypeScript development.

## When to Use

Use this skill when you need to:

- Design type-safe APIs and data structures
- Configure TypeScript projects with optimal compiler settings
- Implement advanced type patterns (generics, mapped types, conditional types)
- Set up testing infrastructure with type-safe mocking
- Optimize TypeScript compilation and runtime performance
- Integrate TypeScript with React, Node.js, Next.js, Remix, or other frameworks
- Choose and configure ORMs, API clients, and build tooling
- Debug type errors and improve type inference

## Core Capabilities

### 1. Type System & Advanced Patterns

Design robust type-safe systems using modern TypeScript features including strict mode, generics with constraints, discriminated unions, mapped types, conditional types, and template literal types. Avoid common anti-patterns and leverage TypeScript 5.0+ features.

See [type-system-patterns.md](type-system-patterns.md) for complete guidance on types, interfaces, generics, narrowing, and advanced patterns.

### 2. Testing Strategies

Implement comprehensive testing strategies with Vitest or Jest, including type-safe mocking, testing generics and complex types, integration testing, and type coverage validation. Use modern testing patterns like the testing diamond approach.

See [testing-patterns.md](testing-patterns.md) for testing frameworks, mocking strategies, and test organization.

### 3. Project Configuration & Tooling

Configure TypeScript projects with optimal tsconfig.json settings, module resolution strategies, build tooling (esbuild, SWC, Vite), ESLint, Prettier, and monorepo setups with path aliases and project references.

See [project-configuration.md](project-configuration.md) for configuration patterns and tooling setup.

### 4. Performance Optimization

Optimize TypeScript compilation speed, type checking performance, bundle size, and runtime performance. Use incremental builds, project references, and identify bottlenecks with diagnostic tools.

See [performance-optimization.md](performance-optimization.md) for optimization strategies.

### 5. Framework & Library Integration

Integrate TypeScript with modern frameworks (React 19, Node.js, Next.js, Remix) and libraries (tRPC, GraphQL, Prisma, Drizzle). Implement type-safe patterns for full-stack development with end-to-end type safety.

See [framework-integration.md](framework-integration.md) for framework-specific patterns.

## Quick Start Workflows

### Creating a Type-Safe Function

1. Define input and output types explicitly
2. Add constraints to generic parameters
3. Use type narrowing for conditional logic
4. Return discriminated unions for multi-state results
5. Add JSDoc comments with @param and @returns

```typescript
/**
 * Fetches user data from the API
 * @param id - User ID
 * @returns Result with user data or error
 */
function fetchUser(id: string): Promise<Result<User, ApiError>> {
  // Implementation
}

type Result<T, E> =
  | { status: 'success'; data: T }
  | { status: 'error'; error: E };
```

### Setting Up a New TypeScript Project

1. Initialize with `npm init -y` and install TypeScript
2. Create tsconfig.json with strict mode and modern settings
3. Configure ESLint with typescript-eslint
4. Set up Prettier for formatting
5. Add build scripts using esbuild or Vite
6. Configure testing with Vitest or Jest

```json
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true,
    "outDir": "./dist",
    "incremental": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

## Core Principles

### 1. Enable Strict Mode Always

Always use `"strict": true` in tsconfig.json and enable additional strictness options like `noUncheckedIndexedAccess`, `noImplicitOverride`, and `exactOptionalPropertyTypes`. Strict mode catches bugs at compile time.

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### 2. Use Types for Unions, Interfaces for Objects

Use `type` for unions, tuples, primitives, and complex type operations. Use `interface` for object shapes that may be extended. This follows TypeScript community conventions.

```typescript
// Types for unions
type Status = 'active' | 'inactive' | 'pending';
type Result<T> = { success: true; data: T } | { success: false; error: string };

// Interfaces for objects
interface User {
  id: string;
  name: string;
  email: string;
}
```

### 3. Avoid `any`, Prefer `unknown`

Never use `any` unless absolutely necessary. Use `unknown` for values of unknown type and narrow them with type guards. `unknown` forces type checking while `any` bypasses it.

```typescript
// Good: Use unknown and narrow
function process(value: unknown): string {
  if (typeof value === 'string') {
    return value.toUpperCase();
  }
  return String(value);
}

// Avoid: Using any
function process(value: any): string {
  return value.toUpperCase(); // No type safety
}
```

### 4. Leverage Type Inference

Let TypeScript infer types when possible, but add explicit types for function parameters, return values, and exported APIs. Use `satisfies` to validate types without widening inference.

```typescript
// Good: Explicit parameters and return type
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Good: Use satisfies to preserve literals
const config = {
  port: 3000,
  host: 'localhost',
} satisfies Record<string, string | number>;
// config.port is still 3000, not number
```

### 5. Use Discriminated Unions for State

Model multi-state data with discriminated unions instead of optional properties. This provides exhaustive type checking and clearer intent.

```typescript
// Good: Discriminated union
type ApiResponse<T> =
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; message: string };

// Avoid: Optional properties
type ApiResponse<T> = {
  status: 'loading' | 'success' | 'error';
  data?: T;
  message?: string;
};
```

## Resource References

For detailed guidance on specific operations, see:

- **[type-system-patterns.md](type-system-patterns.md)**: Types, interfaces, generics, narrowing, and advanced patterns
- **[testing-patterns.md](testing-patterns.md)**: Testing strategies, mocking, and type coverage
- **[project-configuration.md](project-configuration.md)**: tsconfig.json, tooling, ESLint, Prettier setup
- **[performance-optimization.md](performance-optimization.md)**: Compilation speed, type checking, and bundle optimization
- **[framework-integration.md](framework-integration.md)**: React, Node.js, Next.js, Remix, tRPC, ORMs
- **[examples/](examples/)**: Complete project examples
- **[templates/](templates/)**: Type-safe templates and starter configurations

## Success Criteria

TypeScript development is effective when:

- All code compiles with `strict: true` enabled with no errors
- Type inference works correctly without excessive explicit annotations
- Generic functions have proper constraints
- `any` is eliminated or minimized with documented justification
- API boundaries use explicit types (function parameters, return values, exports)
- Tests include type-safe mocking and type coverage validation
- Build process is fast with incremental compilation
- Bundle size is optimized with proper tree-shaking
- Type errors are clear and actionable

## Next Steps

1. Review [type-system-patterns.md](type-system-patterns.md) for type system fundamentals
2. Study [testing-patterns.md](testing-patterns.md) for testing strategies
3. Configure projects using [project-configuration.md](project-configuration.md)
4. Optimize performance with [performance-optimization.md](performance-optimization.md)
5. Integrate frameworks using [framework-integration.md](framework-integration.md)

This skill evolves based on usage and TypeScript updates. When you discover patterns, gotchas, or improvements, update the relevant sections.
