# TypeScript Performance Optimization

## Overview

Comprehensive guide to optimizing TypeScript compilation speed, type checking performance, bundle size, and runtime performance. Includes incremental builds, project references, diagnostic tools, and common performance pitfalls.

## Compilation Speed Optimization

### Enable Incremental Compilation

```json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": "./.tsbuildinfo"
  }
}
```

**Impact:**
- Reduces compilation time by 20-80% in large projects
- Only recompiles modified files and their dependents
- Stores build information in `.tsbuildinfo` file

**Example:**
```bash
# First build: 45 seconds
tsc

# Subsequent builds with no changes: 2 seconds
tsc

# After modifying one file: 5 seconds
tsc
```

### Use Project References

Break large codebases into smaller, independently buildable projects:

```json
// Root tsconfig.json
{
  "compilerOptions": { "composite": true },
  "references": [
    { "path": "./packages/core" },
    { "path": "./packages/utils" },
    { "path": "./packages/api" }
  ],
  "files": []
}
```

**Benefits:**
- Limits file loading per project
- Groups frequently-edited files together
- Enables parallel type-checking
- Clear dependency boundaries

**Recommended Structure:**
- Break into 5-20 separate projects (not too many)
- Group related files together
- Separate test code from product code

### Optimize tsconfig.json

```json
{
  "compilerOptions": {
    "skipLibCheck": true,           // Significant speed improvement
    "isolatedModules": true,        // Enables faster transpilers
    "types": [],                    // Prevent auto-including all @types
    "target": "ES2022",             // Modern target reduces transpilation
    "module": "ESNext",             // Less transformation needed
    "moduleResolution": "bundler"   // Faster than Node16
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", ".*"]
}
```

**Key Options:**

- **`skipLibCheck`**: Skip type-checking `.d.ts` files (50%+ faster)
- **`types: []`**: Exclude unused `@types` packages
- **Modern target**: Less transpilation = faster compilation
- **Explicit exclude**: Prevents scanning unnecessary directories

### Exclude Unnecessary Files

```json
{
  "exclude": [
    "node_modules",
    "dist",
    "build",
    "coverage",
    ".*",              // Hidden files/folders
    "**/*.spec.ts",    // Test files (if not needed)
    "scripts"
  ]
}
```

## Type Checking Performance

### Write Efficient Types

#### Use Interfaces Over Intersections

```typescript
// Slow: Creates complex intersection type
type User = {
  id: string;
  name: string;
} & {
  email: string;
} & {
  age: number;
};

// Fast: Flat interface
interface User {
  id: string;
  name: string;
  email: string;
  age: number;
}
```

**Why:**
- Interfaces create flat object types
- Detect conflicts faster
- Better error messages

#### Avoid Large Union Types

```typescript
// Slow: Exponential comparison checks
type Status =
  | 'pending'
  | 'processing'
  | 'validating'
  | 'approved'
  | 'rejected'
  | 'cancelled'
  | 'completed'
  | 'failed'
  | 'timeout'
  | 'retrying'
  | 'paused'
  | 'resumed'
  | 'archived'; // 13 elements

// Better: Limit to smaller unions or use enums
const enum Status {
  Pending = 'pending',
  Processing = 'processing',
  Completed = 'completed',
  Failed = 'failed',
}
```

**Rule of thumb:**
- Limit unions to 8-12 elements
- Use discriminated unions for complex states
- Consider enums for large sets

#### Avoid Complex Conditional Types

```typescript
// Slow: Complex recursion
type DeepFlatten<T> = T extends Array<infer U>
  ? U extends Array<infer V>
    ? V extends Array<infer W>
      ? DeepFlatten<W>
      : V
    : U
  : T;

// Better: Explicit, simple types
type Flat = string | number;
```

**Issues:**
- Recursive generics cause exponential complexity
- Complex mapped types slow down type checking
- Conditional types with multiple branches increase CPU load

### Add Explicit Type Annotations

```typescript
// Reduces inference work
function processItems(items: Item[]): ProcessedItem[] {
  return items.map(item => transform(item));
}

// Instead of forcing inference
function processItems(items) {
  return items.map(item => transform(item));
}
```

**Benefits:**
- Compiler doesn't need to infer types
- Faster type checking
- Better error messages
- Self-documenting code

### Replace `any` with Specific Types

```typescript
// Slow: `any` prevents optimizations
function process(data: any): any {
  return data.transform();
}

// Fast: Explicit types enable optimizations
function process<T>(data: T): T {
  return data as T;
}
```

**Impact:**
- Using `any` reduces optimization opportunities
- Documented 15% speed improvement by eliminating `any`

## Bundle Size Optimization

### Use Type-Only Imports

```typescript
// Type definitions removed from output
import type { User, Product } from './types';
import type { ApiResponse } from './api';

export function processUser(data: User): Product {
  // Implementation
}
```

**Benefits:**
- Types completely erased at runtime
- Reduces bundle size
- Clearer intent (type vs value import)

### Prefer const enums

```typescript
// Standard enum: Generates lookup objects (adds to bundle)
enum Status {
  Active = 'active',
  Inactive = 'inactive',
}
// Compiled output includes Status object

// const enum: Inlined and disappears from output
const enum Status {
  Active = 'active',
  Inactive = 'inactive',
}
// Compiled output: 'active' and 'inactive' directly
```

**Trade-off:**
- `const enum` reduces bundle size but loses runtime reflection
- Use for internal constants, avoid for public APIs

### Compiler Options for Bundle Optimization

```json
{
  "compilerOptions": {
    "removeComments": true,         // Remove all comments
    "importHelpers": true,          // Reuse helpers from tslib
    "verbatimModuleSyntax": true,   // Better tree-shaking
    "target": "ES2022",             // Use native features
    "module": "ESNext"              // Modern modules
  }
}
```

**Impact:**

- **`importHelpers`**: Reuses helper functions instead of duplicating
- **`verbatimModuleSyntax`**: Preserves imports for tree-shaking
- **Modern target**: Uses native JavaScript features without polyfills

## Incremental Builds & Project References

### Enable Incremental Type Checking

```bash
# Enable incremental builds
tsc --incremental

# Subsequent builds dramatically faster
tsc --incremental
```

**Results:**
- First build: Full compilation time
- Subsequent builds: 20-80% faster
- Only recompiles changed files and dependents

### Separate Concerns with Project References

```
packages/
├── core/
│   ├── tsconfig.json (composite: true)
│   └── src/
├── utils/
│   ├── tsconfig.json (composite: true)
│   └── src/
└── app/
    ├── tsconfig.json (references: [core, utils])
    └── src/
```

**Build Command:**
```bash
# Build all referenced projects
tsc --build

# Clean build
tsc --build --clean

# Watch mode for development
tsc --build --watch
```

**Benefits:**
- Each project loads only its own files
- Parallel type-checking opportunity
- Incremental compilation per project
- Clear dependency boundaries

## Diagnostic & Investigation Tools

### Identify Bottlenecks

```bash
# Show time spent in each compilation phase
tsc --extendedDiagnostics

# Output example:
# Files:            1234
# Lines:            456789
# Nodes:            789012
# I/O Read time:    0.50s
# Parse time:       1.23s
# Bind time:        0.45s
# Check time:       3.67s
# Emit time:        0.89s
# Total time:       6.74s
```

### List All Included Files

```bash
# Detect unintended includes
tsc --listFilesOnly

# Example output:
# /project/src/index.ts
# /project/src/utils.ts
# /project/node_modules/@types/node/index.d.ts
# ... (should not include unnecessary files)
```

### Generate Trace for Analysis

```bash
# Generate detailed trace
tsc --generateTrace ./trace

# Analyze with Chrome DevTools
# 1. Open chrome://tracing
# 2. Load trace/trace.json
# 3. View flame graph of type checking
```

### Debug Module Resolution

```bash
# See how TypeScript resolves modules
tsc --traceResolution

# Output shows resolution steps for each import
```

## Common Performance Pitfalls

### Pitfall 1: Large Union Types (>12 elements)

**Problem:**
```typescript
type Status = 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'g' | 'h' | 'i' | 'j' | 'k' | 'l' | 'm';
// Causes exponential type checking
```

**Solution:**
```typescript
// Use enum or smaller unions
const enum Status {
  A = 'a',
  B = 'b',
  // ...
}
```

### Pitfall 2: Complex Generics with Conditionals

**Problem:**
```typescript
type ComplexType<T> = T extends Array<infer U>
  ? U extends { id: infer V }
    ? V extends string
      ? string[]
      : number[]
    : never
  : never;
```

**Solution:**
```typescript
// Simplify or use named intermediate types
type ExtractId<T> = T extends { id: infer V } ? V : never;
type ArrayElement<T> = T extends Array<infer U> ? U : never;
```

### Pitfall 3: Not Excluding node_modules

**Problem:**
```json
{
  "include": ["**/*"]  // Scans everything including node_modules
}
```

**Solution:**
```json
{
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

### Pitfall 4: Skipping Explicit Type Annotations

**Problem:**
```typescript
// Forces compiler to infer everything
function process(data) {
  return data.map(item => item.value);
}
```

**Solution:**
```typescript
function process(data: Item[]): number[] {
  return data.map(item => item.value);
}
```

### Pitfall 5: Using transpileOnly Everywhere

**Problem:**
```json
{
  "scripts": {
    "dev": "ts-node --transpileOnly src/index.ts"  // Skips type checking
  }
}
```

**Solution:**
```json
{
  "scripts": {
    "dev": "ts-node src/index.ts",
    "build": "tsc --noEmit && esbuild src/index.ts --bundle"
  }
}
```

## Alternative Tools for Speed

### Faster Transpilers

| Tool | Speed vs tsc | Type Checking | Use Case |
|------|--------------|---------------|----------|
| Babel | 83% faster | No | Development builds |
| SWC | 96% faster | No | Production builds |
| esbuild | 100x faster | No | Fast bundling |

**Recommendation:**
Use hybrid approach - tsc for type checking + fast transpiler for code:

```json
{
  "scripts": {
    "build": "tsc --noEmit && esbuild src/index.ts --bundle --outfile=dist/index.js"
  }
}
```

### Native TypeScript (2025 Preview)

Microsoft is developing a native `tsc` implementation in Rust:

- **Expected**: Mid-2025 preview
- **Performance**: 10x faster than current tsc
- **Impact**: Major shift in TypeScript tooling ecosystem

## Actionable Optimization Roadmap

### Immediate (< 1 hour)

1. Enable `incremental: true` in tsconfig.json
2. Add `skipLibCheck: true`
3. Set `types: []` if not using many @types packages
4. Exclude unnecessary directories

```json
{
  "compilerOptions": {
    "incremental": true,
    "skipLibCheck": true,
    "types": []
  },
  "exclude": ["node_modules", "dist", ".*"]
}
```

### Short-term (< 1 day)

1. Use type-only imports (`import type`)
2. Replace `any` with proper types
3. Audit large unions (>12 elements)
4. Add explicit function return types

```typescript
// Before
import { User } from './types';
function process(data: any) { ... }

// After
import type { User } from './types';
function process(data: unknown): ProcessedData { ... }
```

### Medium-term (< 1 week)

1. Implement project references for monorepos
2. Extract complex types to named aliases
3. Use `const enum` for internal constants
4. Set up hybrid build (tsc + esbuild)

```json
// Root tsconfig.json
{
  "references": [
    { "path": "./packages/core" },
    { "path": "./packages/utils" }
  ]
}
```

### Long-term (Q1-Q2 2025)

1. Evaluate native TypeScript implementation (when available)
2. Consider SWC for specific build steps
3. Implement comprehensive type coverage monitoring
4. Regular performance audits with `--extendedDiagnostics`

## Performance Monitoring

### Establish Baselines

```bash
# Record baseline build time
time tsc > /dev/null

# Track over time
echo "$(date), $(time tsc 2>&1 | grep real)" >> build-times.log
```

### Set Performance Budgets

```json
{
  "scripts": {
    "build": "tsc",
    "build:check-time": "time npm run build | grep 'real.*[0-9]s' && echo 'Build time OK' || echo 'Build too slow!'"
  }
}
```

### Continuous Monitoring

```typescript
// CI/CD check
if (buildTime > 30000) {
  console.warn('Build time exceeded 30s threshold');
  // Alert or fail build
}
```

## Best Practices Summary

### Compilation Speed

1. **Enable incremental builds** (`incremental: true`)
2. **Use project references** for large codebases
3. **Skip lib checks** (`skipLibCheck: true`)
4. **Exclude unnecessary files** explicitly
5. **Use modern target** (ES2022) to reduce transpilation

### Type Checking Performance

1. **Use interfaces over intersections** for object types
2. **Limit union types** to 8-12 elements
3. **Avoid complex recursive generics**
4. **Add explicit type annotations** for function signatures
5. **Replace `any` with specific types**

### Bundle Size

1. **Use type-only imports** (`import type`)
2. **Prefer `const enum`** for internal constants
3. **Enable `importHelpers`** to reuse helpers
4. **Use `verbatimModuleSyntax`** for tree-shaking
5. **Target modern JavaScript** (ES2022)

### Tools & Diagnostics

1. **Use `--extendedDiagnostics`** to identify bottlenecks
2. **Generate traces** for deep analysis (`--generateTrace`)
3. **Monitor build times** in CI/CD
4. **Use hybrid approach** (tsc + esbuild/swc)
5. **Set performance budgets** for builds

## Quick Reference

### Performance Checklist

- [ ] `incremental: true` enabled
- [ ] `skipLibCheck: true` set
- [ ] `types: []` configured (if applicable)
- [ ] Unnecessary files excluded
- [ ] Modern target (ES2022) used
- [ ] Type-only imports used
- [ ] Large unions (>12) avoided
- [ ] Explicit function types added
- [ ] Project references set up (for monorepos)
- [ ] Build times monitored in CI/CD

### Diagnostic Commands

```bash
# Show compilation stats
tsc --extendedDiagnostics

# List all files being compiled
tsc --listFilesOnly

# Generate performance trace
tsc --generateTrace ./trace

# Debug module resolution
tsc --traceResolution
```

### Build Time Targets

| Project Size | Target Build Time | Incremental Build |
|--------------|-------------------|-------------------|
| Small (<10k LOC) | <5s | <2s |
| Medium (10-50k LOC) | <15s | <5s |
| Large (50-100k LOC) | <30s | <10s |
| Very Large (>100k LOC) | <60s | <20s |
