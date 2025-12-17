# TypeScript Type System & Advanced Patterns

## Overview

Master the TypeScript type system with modern best practices, advanced patterns, and anti-patterns to avoid. Covers types vs interfaces, generics, strict mode, type narrowing, utility types, and TypeScript 5.0+ features.

## Types vs Interfaces

### When to Use Each

**Use `type` for:**
- Unions and intersections
- Tuples and primitives
- Mapped types and complex transformations
- Template literal types

**Use `interface` for:**
- Object shapes that may be extended
- Class contracts
- API definitions that need declaration merging

```typescript
// Good: Type for unions
type Status = 'active' | 'inactive' | 'pending';
type Result<T> =
  | { status: 'success'; data: T }
  | { status: 'error'; message: string };

// Good: Interface for objects
interface User {
  id: string;
  name: string;
  email: string;
}

// Interface can be extended
interface AdminUser extends User {
  permissions: string[];
}
```

### Key Differences

- **Interfaces** can be merged (declaration merging), **types** cannot
- **Types** support unions, **interfaces** don't
- **Interfaces** create flat object types (better error messages)
- **Types** are more flexible for complex transformations

## Generics with Constraints

### Basic Constraints

Always constrain generics to prevent overly broad types:

```typescript
// Good: Constrained generic
function merge<T extends Record<string, unknown>>(
  obj1: T,
  obj2: Partial<T>,
): T {
  return { ...obj1, ...obj2 };
}

// Avoid: Unconstrained generic
function process<T>(data: T): T {
  return data; // Too broad, no guarantees
}
```

### Multiple Constraints

```typescript
// Constrain to specific interface
interface Entity {
  id: number;
}

function findById<T extends Entity>(
  items: T[],
  id: number,
): T | undefined {
  return items.find(item => item.id === id);
}

// Works with any type that has id
interface Product extends Entity {
  name: string;
  price: number;
}

const product = findById<Product>(products, 1);
```

### Generic Defaults

```typescript
// Set sensible defaults
function createArray<T = string>(
  length: number,
  value: T,
): T[] {
  return Array(length).fill(value);
}

// Uses default type
const strings = createArray(3, 'hello'); // T is string
```

## Strict Mode & Compiler Options

### Essential Strict Settings

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### What Each Option Does

- **`strict`**: Enables all strict type-checking options
- **`noUncheckedIndexedAccess`**: Adds `undefined` to indexed access (`arr[0]` becomes `T | undefined`)
- **`noImplicitOverride`**: Requires `override` keyword when overriding methods
- **`noPropertyAccessFromIndexSignature`**: Forces bracket notation for index signatures
- **`exactOptionalPropertyTypes`**: Prevents treating `undefined` as valid for optional properties

### Impact Example

```typescript
// With noUncheckedIndexedAccess
const arr: string[] = ['a', 'b', 'c'];
const first = arr[0]; // Type: string | undefined
if (first) {
  console.log(first.toUpperCase()); // Safe
}

// With exactOptionalPropertyTypes
interface Config {
  port?: number;
}

const config: Config = {
  port: undefined, // Error with exactOptionalPropertyTypes
};
```

## Type Narrowing & Guards

### Built-in Type Guards

```typescript
// typeof guard
function processValue(value: string | number): string {
  if (typeof value === 'string') {
    return value.toUpperCase();
  }
  return value.toString();
}

// instanceof guard
function handleError(error: Error | string): string {
  if (error instanceof Error) {
    return error.message;
  }
  return error;
}

// in operator
interface Dog {
  bark: () => void;
}
interface Cat {
  meow: () => void;
}

function makeSound(animal: Dog | Cat): void {
  if ('bark' in animal) {
    animal.bark();
  } else {
    animal.meow();
  }
}
```

### Custom Type Predicates

```typescript
// User-defined type guard
interface User {
  id: number;
  name: string;
}

function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value &&
    typeof (value as User).id === 'number' &&
    typeof (value as User).name === 'string'
  );
}

// Usage
function processData(data: unknown): void {
  if (isUser(data)) {
    console.log(data.name); // data is narrowed to User
  }
}
```

### Discriminated Unions

```typescript
// Best practice for multi-state types
type ApiResponse<T> =
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; code: string; message: string };

function handleResponse<T>(response: ApiResponse<T>): void {
  // TypeScript narrows based on status
  switch (response.status) {
    case 'loading':
      console.log('Loading...');
      break;
    case 'success':
      console.log(response.data); // data is available
      break;
    case 'error':
      console.log(response.message); // message is available
      break;
  }
}
```

## Utility Types

### Built-in Utility Types

```typescript
interface User {
  id: number;
  name: string;
  email: string;
  age: number;
}

// Partial: All properties optional
type PartialUser = Partial<User>;
// { id?: number; name?: string; email?: string; age?: number; }

// Required: All properties required
type RequiredUser = Required<PartialUser>;

// Readonly: All properties readonly
type ReadonlyUser = Readonly<User>;

// Pick: Select specific properties
type UserBasic = Pick<User, 'id' | 'name'>;
// { id: number; name: string; }

// Omit: Exclude specific properties
type UserWithoutAge = Omit<User, 'age'>;
// { id: number; name: string; email: string; }

// Record: Create object type with specific keys
type UserMap = Record<number, User>;
// { [key: number]: User; }

// ReturnType: Extract return type
function getUser(): User {
  return { id: 1, name: 'John', email: 'john@example.com', age: 30 };
}
type UserType = ReturnType<typeof getUser>; // User

// Parameters: Extract parameter types
type GetUserParams = Parameters<typeof getUser>; // []
```

### Custom Utility Types

```typescript
// Make specific properties required
type RequireFields<T, K extends keyof T> = T & Required<Pick<T, K>>;

interface Config {
  apiUrl?: string;
  timeout?: number;
  retries?: number;
}

type RequiredConfig = RequireFields<Config, 'apiUrl'>;
// { apiUrl: string; timeout?: number; retries?: number; }

// Deep Partial
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};
```

## Advanced Type Patterns

### Mapped Types

```typescript
// Create getters from interface
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

interface User {
  id: number;
  name: string;
}

type UserGetters = Getters<User>;
// {
//   getId: () => number;
//   getName: () => string;
// }

// Create setters
type Setters<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: (value: T[K]) => void;
};

type UserSetters = Setters<User>;
// {
//   setId: (value: number) => void;
//   setName: (value: string) => void;
// }
```

### Conditional Types

```typescript
// Flatten array type
type Flatten<T> = T extends Array<infer U> ? U : T;

type Str = Flatten<string[]>; // string
type Num = Flatten<number>; // number

// Unwrap promises
type Awaited<T> = T extends Promise<infer U> ? U : T;

type Result = Awaited<Promise<string>>; // string

// Filter union types
type NonNullable<T> = T extends null | undefined ? never : T;

type Value = string | null | undefined;
type NonNull = NonNullable<Value>; // string
```

### Template Literal Types

```typescript
// Event system
type EventMap = {
  'user:created': { userId: string };
  'user:updated': { userId: string; changes: Record<string, unknown> };
  'user:deleted': { userId: string };
};

type EventKey = keyof EventMap;

function emit<K extends EventKey>(
  event: K,
  data: EventMap[K],
): void {
  console.log(`Event: ${event}`, data);
}

// Type-safe event emission
emit('user:created', { userId: '123' }); // ✓
emit('user:created', { userId: 123 }); // ✗ Error

// CSS classes
type Color = 'primary' | 'secondary' | 'danger';
type Size = 'sm' | 'md' | 'lg';
type ButtonClass = `btn-${Color}-${Size}`;

const className: ButtonClass = 'btn-primary-lg'; // ✓
```

## The `satisfies` Operator (TypeScript 4.9+)

### Validate Without Widening

```typescript
// Problem: Type assertion loses precision
const config1 = {
  port: 3000,
  host: 'localhost',
} as Record<string, string | number>;

// config1.port is number (widened from 3000)
const port1: 3000 = config1.port; // ✗ Error

// Solution: satisfies preserves literal types
const config2 = {
  port: 3000,
  host: 'localhost',
} satisfies Record<string, string | number>;

// config2.port is still 3000 (literal)
const port2: 3000 = config2.port; // ✓ Works
```

### Validate Structure

```typescript
type RGB = [number, number, number];

const colors = {
  red: [255, 0, 0],
  green: [0, 255, 0],
  blue: [0, 0, 255],
  invalid: [255, 0], // ✗ Error with satisfies
} satisfies Record<string, RGB>;

// colors.red is [255, 0, 0], not RGB
const firstColor = colors.red[0]; // Type: 255
```

## Common Anti-Patterns

### Anti-Pattern 1: Overusing `any`

```typescript
// ✗ Avoid
function process(data: any): any {
  return data.transform();
}

// ✓ Better
function process<T>(data: T): T {
  if (typeof data === 'object' && data !== null && 'transform' in data) {
    return (data as { transform: () => T }).transform();
  }
  return data;
}

// ✓ Best: Use unknown
function process(data: unknown): unknown {
  if (
    typeof data === 'object' &&
    data !== null &&
    'transform' in data &&
    typeof (data as { transform: () => unknown }).transform === 'function'
  ) {
    return (data as { transform: () => unknown }).transform();
  }
  return data;
}
```

### Anti-Pattern 2: Loose Union Types

```typescript
// ✗ Avoid: Ambiguous unions
type Value = string | number | boolean | null | undefined;

// ✓ Prefer: Discriminated unions
type ApiResult<T> =
  | { status: 'success'; data: T }
  | { status: 'loading'; progress: number }
  | { status: 'error'; code: string; message: string };
```

### Anti-Pattern 3: Not Using `as const`

```typescript
// ✗ Avoid: Lost literal types
const colors = ['red', 'green', 'blue']; // string[]
const theme = { light: '#fff', dark: '#000' }; // { light: string; dark: string }

// ✓ Prefer: Preserve literals
const colors = ['red', 'green', 'blue'] as const; // readonly ["red", "green", "blue"]
const theme = { light: '#fff', dark: '#000' } as const; // { readonly light: "#fff"; readonly dark: "#000" }
```

### Anti-Pattern 4: Missing Type Narrowing

```typescript
// ✗ Avoid: Accessing optional without check
interface User {
  name: string;
  nickname?: string;
}

function greet(user: User): string {
  return `Hi ${user.nickname.toUpperCase()}`; // ✗ Error: possibly undefined
}

// ✓ Better: Explicit narrowing
function greet(user: User): string {
  return `Hi ${user.nickname?.toUpperCase() ?? user.name}`;
}
```

### Anti-Pattern 5: Type Assertions Instead of Type Guards

```typescript
// ✗ Avoid: Unsafe type assertion
function processUser(data: unknown): void {
  const user = data as User; // No runtime safety
  console.log(user.name);
}

// ✓ Better: Type guard
function processUser(data: unknown): void {
  if (isUser(data)) {
    console.log(data.name); // Type-safe
  }
}
```

## Modern TypeScript Features (5.0+)

### Const Type Parameters (5.0+)

```typescript
// Preserves literal types in generic contexts
function createConstArray<const T extends readonly unknown[]>(
  items: T,
): T {
  return items;
}

const arr = createConstArray([1, 'two', true] as const);
// arr is [1, 'two', true], not (string | number | boolean)[]
```

### Using Declaration (5.2+)

```typescript
// Automatic disposal with using keyword
{
  using resource = getResource();
  // resource.dispose() called automatically at end of block
}
```

### Decorator Metadata (5.2+)

```typescript
// Enhanced decorator support
function logMethod(
  target: any,
  propertyKey: string,
  descriptor: PropertyDescriptor,
) {
  const original = descriptor.value;
  descriptor.value = function (...args: any[]) {
    console.log(`Calling ${propertyKey}`);
    return original.apply(this, args);
  };
}

class Service {
  @logMethod
  getData() {
    return 'data';
  }
}
```

## Best Practices Summary

1. **Enable strict mode** with additional strictness options
2. **Use `type` for unions**, `interface` for objects
3. **Constrain generics** to prevent overly broad types
4. **Use discriminated unions** for multi-state data
5. **Prefer `unknown` over `any`** for unknown values
6. **Use type guards** for runtime validation
7. **Leverage utility types** to reduce boilerplate
8. **Use `satisfies`** to validate without widening
9. **Use `as const`** to preserve literal types
10. **Avoid type assertions** (`as`); use type guards instead

## Quick Reference

### Type Operations

```typescript
// Union
type A = string | number;

// Intersection
type B = { a: string } & { b: number };

// Conditional
type C<T> = T extends string ? string : number;

// Mapped
type D<T> = { [K in keyof T]: T[K] };

// Template Literal
type E = `prefix-${string}`;

// Index Access
type F = User['name'];

// keyof
type G = keyof User;
```

### Type Narrowing Checklist

- [ ] Use `typeof` for primitives
- [ ] Use `instanceof` for classes
- [ ] Use `in` for discriminated unions
- [ ] Create custom type guards with `is`
- [ ] Use `switch` on discriminant property
- [ ] Use optional chaining (`?.`) for safety
- [ ] Use nullish coalescing (`??`) for defaults
