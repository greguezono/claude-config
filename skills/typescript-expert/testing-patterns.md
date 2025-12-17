# TypeScript Testing Patterns

## Overview

Comprehensive testing strategies for TypeScript including framework selection, type-safe mocking, testing generics and complex types, integration testing patterns, and type coverage validation. Covers Vitest, Jest, MSW, and modern testing approaches.

## Testing Framework Selection

### Vitest (Recommended for Modern Projects)

**When to Choose Vitest:**
- New TypeScript projects
- Projects using Vite, Remix, or modern build tools
- Need for fast watch mode (10-20x faster than Jest)
- Zero-config TypeScript support desired

**Setup:**

```bash
npm install --save-dev vitest @vitest/ui
```

```typescript
// vite.config.ts
import { defineConfig } from 'vite';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      lines: 80,
    },
  },
});
```

**Key Advantages:**
- Native ESM support
- Zero-config TypeScript, JSX, PostCSS
- Compatible with Jest API (easy migration)
- Fast performance in watch mode

### Jest (For Legacy & React Native)

**When to Choose Jest:**
- React Native projects (required)
- Large legacy codebases with existing Jest setup
- Team has deep Jest expertise
- Need for mature plugin ecosystem

**Setup:**

```bash
npm install --save-dev jest ts-jest @types/jest
```

```javascript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  collectCoverageFrom: ['src/**/*.ts'],
  coverageThreshold: {
    global: {
      lines: 80,
      statements: 80,
    },
  },
};
```

## Type-Safe Mocking Strategies

### 1. Partial Mock Pattern

```typescript
// Type-safe partial mock helper
function mockPartially<T>(partial: Partial<T>): T {
  return new Proxy(partial as T, {
    get: (target, prop) => {
      if (prop in target) {
        return target[prop as keyof T];
      }
      throw new Error(`Mock missing property: ${String(prop)}`);
    },
  });
}

// Usage
interface UserService {
  getUser(id: string): Promise<User>;
  updateUser(id: string, data: Partial<User>): Promise<User>;
  deleteUser(id: string): Promise<void>;
}

describe('UserController', () => {
  it('should fetch user', async () => {
    const mockService = mockPartially<UserService>({
      getUser: async (id: string) => ({ id, name: 'John', email: 'john@example.com' }),
    });

    const controller = new UserController(mockService);
    const user = await controller.getById('123');

    expect(user.name).toBe('John');
  });
});
```

### 2. Class-Based Mock Architecture

```typescript
// Reusable mock service class
class UserServiceMock implements UserService {
  private users: Map<string, User> = new Map();
  private callHistory: Array<{ method: string; args: unknown[] }> = [];

  constructor(initialUsers: User[] = []) {
    initialUsers.forEach(user => this.users.set(user.id, user));
  }

  async getUser(id: string): Promise<User> {
    this.recordCall('getUser', [id]);
    const user = this.users.get(id);
    if (!user) throw new Error(`User ${id} not found`);
    return user;
  }

  async updateUser(id: string, data: Partial<User>): Promise<User> {
    this.recordCall('updateUser', [id, data]);
    const user = this.users.get(id);
    if (!user) throw new Error(`User ${id} not found`);
    const updated = { ...user, ...data };
    this.users.set(id, updated);
    return updated;
  }

  async deleteUser(id: string): Promise<void> {
    this.recordCall('deleteUser', [id]);
    this.users.delete(id);
  }

  // Test helpers
  getCallHistory() {
    return this.callHistory;
  }

  wasCalledWith(method: string, ...args: unknown[]) {
    return this.callHistory.some(
      call => call.method === method && JSON.stringify(call.args) === JSON.stringify(args)
    );
  }

  private recordCall(method: string, args: unknown[]) {
    this.callHistory.push({ method, args });
  }
}

// Usage
describe('UserController Integration', () => {
  let mockService: UserServiceMock;
  let controller: UserController;

  beforeEach(() => {
    mockService = new UserServiceMock([
      { id: '1', name: 'Alice', email: 'alice@example.com' },
    ]);
    controller = new UserController(mockService);
  });

  it('should update user and record call', async () => {
    await controller.updateUser('1', { name: 'Alice Updated' });

    expect(mockService.wasCalledWith('updateUser', '1', { name: 'Alice Updated' })).toBe(true);
    const user = await mockService.getUser('1');
    expect(user.name).toBe('Alice Updated');
  });
});
```

### 3. Mock Service Worker (MSW) for API Mocking

```typescript
// API mocking at network level
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

const server = setupServer(
  http.get('/api/users/:id', ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      id,
      name: 'John Doe',
      email: 'john@example.com',
    });
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: '123', ...body },
      { status: 201 }
    );
  }),
);

// Setup/teardown
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Test
it('should fetch user from API', async () => {
  const response = await fetch('/api/users/1');
  const user = await response.json();

  expect(user.name).toBe('John Doe');
});
```

### 4. Vitest/Jest Factory Functions

```typescript
// Type-safe mock with Vitest
import { vi } from 'vitest';

function createMockUserService(): UserService {
  return {
    getUser: vi.fn<[string], Promise<User>>(),
    updateUser: vi.fn<[string, Partial<User>], Promise<User>>(),
    deleteUser: vi.fn<[string], Promise<void>>(),
  };
}

// Usage
describe('UserController', () => {
  it('should call service with correct params', async () => {
    const mockService = createMockUserService();
    mockService.getUser.mockResolvedValue({
      id: '1',
      name: 'John',
      email: 'john@example.com',
    });

    const controller = new UserController(mockService);
    await controller.getById('1');

    expect(mockService.getUser).toHaveBeenCalledWith('1');
  });
});
```

## Testing Generics and Complex Types

### 1. Type-Level Testing

```typescript
// Helper types for type testing
type Expect<T extends true> = T;
type Equal<X, Y> = (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2
  ? true
  : false;

// Test generic function types
function createArray<T>(value: T, length: number): T[] {
  return Array(length).fill(value);
}

// Type tests
type TestNumberArray = Expect<Equal<ReturnType<typeof createArray<number>>, number[]>>;
type TestStringArray = Expect<Equal<ReturnType<typeof createArray<string>>, string[]>>;

// Test type inference
const numbers = createArray(42, 3);
type TestInference = Expect<Equal<typeof numbers, number[]>>;
```

### 2. Runtime Testing of Generics

```typescript
// Generic repository pattern
interface Entity {
  id: string;
}

class Repository<T extends Entity> {
  private store: Map<string, T> = new Map();

  create(item: T): T {
    this.store.set(item.id, item);
    return item;
  }

  find(id: string): T | undefined {
    return this.store.get(id);
  }

  getAll(): T[] {
    return Array.from(this.store.values());
  }
}

// Test with specific entity types
interface Product extends Entity {
  name: string;
  price: number;
}

describe('Repository<Product>', () => {
  let repo: Repository<Product>;

  beforeEach(() => {
    repo = new Repository<Product>();
  });

  it('should work with Product type', () => {
    const product: Product = {
      id: '1',
      name: 'Widget',
      price: 9.99,
    };

    repo.create(product);
    const found = repo.find('1');

    expect(found).toEqual(product);
    expect(found?.price).toBeCloseTo(9.99);
  });

  it('should maintain type safety', () => {
    const products = repo.getAll();

    // TypeScript ensures products is Product[]
    expect(Array.isArray(products)).toBe(true);
    products.forEach(p => {
      expect(p).toHaveProperty('name');
      expect(p).toHaveProperty('price');
    });
  });
});
```

### 3. Negative Type Tests

```typescript
// Use @ts-expect-error for negative cases
describe('Type Safety', () => {
  it('should reject invalid types', () => {
    const repo = new Repository<Product>();

    // @ts-expect-error - missing required properties
    repo.create({ id: '1' });

    // @ts-expect-error - wrong property type
    repo.create({ id: '1', name: 'Widget', price: 'free' });
  });
});
```

## Integration Testing Patterns

### Testing Diamond Approach (Recommended 2025)

```
         E2E (3-10 total)
        Integration (selective)
       Component/Contract (foundation)
      Unit (complex logic only)
```

### Integration Test Example

```typescript
describe('UserService Integration', () => {
  let service: UserService;
  let db: Database;

  beforeAll(async () => {
    db = await Database.connect({
      host: 'localhost',
      database: 'test_db',
    });
    await db.migrate();
    service = new UserService(db);
  });

  afterAll(async () => {
    await db.close();
  });

  afterEach(async () => {
    await db.query('DELETE FROM users');
  });

  it('should create and retrieve user', async () => {
    const userData = {
      name: 'John Doe',
      email: 'john@example.com',
    };

    const created = await service.create(userData);
    expect(created.id).toBeDefined();

    const retrieved = await service.getById(created.id);
    expect(retrieved).toEqual(created);
  });

  it('should handle all side effects', async () => {
    // Test the "five exit doors" of a backend service

    // 1. API Response
    const response = await service.create({ name: 'Jane', email: 'jane@example.com' });
    expect(response.id).toBeDefined();

    // 2. Database state
    const dbUser = await db.query('SELECT * FROM users WHERE id = ?', [response.id]);
    expect(dbUser).toHaveLength(1);

    // 3. External service calls (mocked)
    expect(emailServiceMock.sendWelcome).toHaveBeenCalled();

    // 4. Message queues (mocked)
    expect(queueMock.publish).toHaveBeenCalledWith('user.created', expect.any(Object));

    // 5. Observability (logs, metrics)
    expect(loggerMock.info).toHaveBeenCalledWith(expect.stringContaining('User created'));
  });
});
```

## Test Organization & Structure

### Directory Structure

```
src/
├── __tests__/
│   ├── unit/
│   │   ├── services/
│   │   │   └── user.service.test.ts
│   │   └── utils/
│   │       └── validators.test.ts
│   ├── integration/
│   │   ├── repositories/
│   │   │   └── user.repository.integration.test.ts
│   │   └── workflows/
│   │       └── user-signup.integration.test.ts
│   ├── e2e/
│   │   └── api.e2e.test.ts
│   └── fixtures/
│       ├── users.fixture.ts
│       └── mocks.ts
├── services/
│   └── user.service.ts
└── config/
    └── test-setup.ts
```

### File Naming Convention

```typescript
// user.service.test.ts

describe('UserService', () => {
  describe('create', () => {
    it('should create user with valid data', () => {
      // Arrange
      const input = { name: 'John', email: 'john@example.com' };

      // Act
      const result = service.create(input);

      // Assert
      expect(result.id).toBeDefined();
      expect(result.name).toBe('John');
    });

    describe('validation', () => {
      it('should reject empty email', () => {
        expect(() => service.create({ name: 'John', email: '' })).toThrow('Email required');
      });

      it('should reject invalid email format', () => {
        expect(() => service.create({ name: 'John', email: 'invalid' })).toThrow(
          'Invalid email'
        );
      });
    });
  });
});
```

### Fixture/Factory Pattern

```typescript
// fixtures/users.fixture.ts
export const userFactory = {
  createUser: (overrides?: Partial<User>): User => ({
    id: Math.random().toString(36).substring(7),
    name: 'John Doe',
    email: 'john@example.com',
    createdAt: new Date(),
    ...overrides,
  }),

  createAdmin: (overrides?: Partial<User>): User =>
    userFactory.createUser({
      role: 'admin',
      ...overrides,
    }),

  bulkCreate: (count: number, overrides?: Partial<User>): User[] =>
    Array.from({ length: count }, (_, i) =>
      userFactory.createUser({
        id: `user-${i}`,
        email: `user${i}@example.com`,
        ...overrides,
      })
    ),
};

// Usage
describe('UserService', () => {
  it('should handle multiple users', () => {
    const users = userFactory.bulkCreate(10);
    expect(users).toHaveLength(10);
    expect(users[0].email).toBe('user0@example.com');
  });
});
```

## Type Coverage Validation

### Type Coverage Tool

```bash
# Install
npm install --save-dev type-coverage

# Check coverage
npx type-coverage

# With threshold
npx type-coverage --at-least 85

# Generate HTML report
npx type-coverage --reporter=html
```

### Configuration

```json
// package.json
{
  "scripts": {
    "type-coverage": "type-coverage",
    "type-coverage:report": "type-coverage --reporter=html",
    "ci:type-check": "tsc --noEmit && type-coverage --at-least 85"
  },
  "typeCoverage": {
    "atLeast": 85,
    "ignoreCatch": true,
    "ignoreFiles": [
      "**/*.test.ts",
      "**/fixtures/**"
    ]
  }
}
```

### Identifying Uncovered Types

```typescript
// type-coverage reports specific locations with 'any'
// Output example:
// src/services/user.service.ts:42:8 - variable 'result' has type 'any'

// Fix by adding explicit types
function processData(input: unknown): ProcessedData {
  // Before: result has type 'any'
  const result = JSON.parse(input);

  // After: result has explicit type
  const result: unknown = JSON.parse(input);
  if (isProcessedData(result)) {
    return result;
  }
  throw new Error('Invalid data');
}
```

## Best Practices Summary

### Testing Strategy

1. **Target 80-90% code coverage** (not 100% - diminishing returns)
2. **Use testing diamond** approach (component tests as foundation)
3. **Mock at boundaries** (APIs, databases, external services)
4. **Test behavior, not implementation**
5. **Write type-safe mocks** aligned with real interfaces

### Type Safety

1. **Enable type coverage** checking in CI/CD
2. **Focus on public APIs** - type-safe exports before internals
3. **Use `unknown` instead of `any`** for better type safety
4. **Write type-level tests** for generic functions
5. **Use `@ts-expect-error`** for negative test cases

### Test Organization

1. **Follow naming conventions** (*.test.ts, *.spec.ts)
2. **Use descriptive test names** (should/when/given format)
3. **Arrange-Act-Assert** pattern for clarity
4. **Use factories** for test data generation
5. **Keep tests independent** (no shared state)

## Quick Reference

### Test Setup Checklist

- [ ] Framework installed (Vitest or Jest)
- [ ] TypeScript configuration working
- [ ] Coverage thresholds set (80%+)
- [ ] Type coverage tool installed
- [ ] Test directory structure created
- [ ] Fixtures and factories defined
- [ ] CI/CD integration configured
- [ ] Mock strategies documented

### Mocking Decision Tree

```
Need to mock?
├─ External API → Use MSW
├─ Database → Use in-memory or TestContainers
├─ Service dependency → Use class-based mock or factory
└─ Complex interface → Use partial mock pattern
```

### Coverage Targets

- **Code Coverage**: 80-90%
- **Type Coverage**: 85%+
- **Branch Coverage**: 75%+
- **Focus Areas**: Public APIs, business logic, error handling
