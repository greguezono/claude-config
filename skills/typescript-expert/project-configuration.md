# TypeScript Project Configuration & Tooling

## Overview

Complete guide to configuring TypeScript projects with optimal tsconfig.json settings, module resolution strategies, build tooling (esbuild, SWC, Vite), ESLint, Prettier, and monorepo configurations with path aliases and project references.

## tsconfig.json Configuration

### Base Configuration for All Projects

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
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "incremental": true,
    "noImplicitOverride": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

### Node.js Projects

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

**Use when:**
- Building Node.js libraries or applications
- Need future-proof module resolution
- Want to respect `.mts`/`.cts` file extensions

### Library Projects

```json
{
  "compilerOptions": {
    "declaration": true,
    "declarationMap": true,
    "emitDeclarationOnly": false,
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "target": "ES2020"
  }
}
```

**Use when:**
- Publishing to npm
- Need `.d.ts` files for consumers
- Building reusable packages

### Bundler Projects (React, Vue, etc.)

```json
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true
  }
}
```

**Use when:**
- Using Webpack, Vite, esbuild, Rollup
- Building React, Vue, Svelte applications
- Transpilation handled by bundler

## Module Resolution Strategies

### NodeNext (Recommended for Node.js Libraries)

```json
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext"
  }
}
```

**Characteristics:**
- Future-proof: automatically uses latest Node.js algorithm
- Respects `.mts` and `.cts` file extensions
- Enforces file extensions in imports
- Prevents emitting ESM that only works in bundlers

**Example:**
```typescript
// Must include .js extension (even for .ts files)
import { add } from './math.js';
```

### Bundler (For Web Projects)

```json
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "bundler"
  }
}
```

**Characteristics:**
- Works with Vite, esbuild, Webpack, Rollup
- No file extensions required on relative imports
- Supports package.json "imports" and "exports" fields
- Best for frontend applications

**Example:**
```typescript
// No extension needed
import { Button } from './components/Button';
```

### Comparison Table

| Strategy | Use Case | Extensions Required | Future Updates |
|----------|----------|---------------------|----------------|
| NodeNext | Node.js libraries | Yes | Automatic |
| Node16 | Legacy Node 16 | Yes | Fixed |
| Bundler | Web apps | No | N/A |

## Build Tooling

### Speed Comparison (2025)

| Tool | Relative Speed | Written In | Type Checking |
|------|----------------|------------|---------------|
| esbuild | Baseline (fastest) | Go | No |
| SWC | ~2x slower | Rust | No |
| tsc | ~100x slower | TypeScript | Yes |

### esbuild (Ultra-Fast Transpiling)

```bash
npm install --save-dev esbuild
```

```json
// package.json
{
  "scripts": {
    "build": "esbuild src/index.ts --bundle --outfile=dist/bundle.js --target=es2022 --minify",
    "build:watch": "esbuild src/index.ts --bundle --outfile=dist/bundle.js --watch"
  }
}
```

**esbuild.config.js:**
```javascript
import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  outfile: 'dist/bundle.js',
  target: 'es2022',
  format: 'esm',
  minify: true,
  sourcemap: true,
});
```

**Pros:**
- 10-100x faster than tsc
- Minimal configuration
- Built-in bundling and minification

**Cons:**
- No type checking (run tsc separately)
- Limited to code transformation

### SWC (Rust-Based, Used by Next.js)

```bash
npm install --save-dev @swc/cli @swc/core
```

**.swcrc:**
```json
{
  "jsc": {
    "parser": {
      "syntax": "typescript",
      "tsx": true,
      "decorators": true
    },
    "transform": {
      "react": {
        "runtime": "automatic"
      }
    },
    "target": "es2022"
  },
  "module": {
    "type": "es6"
  }
}
```

**package.json:**
```json
{
  "scripts": {
    "build": "swc src -d dist"
  }
}
```

**Pros:**
- 20x faster than Babel
- Major framework adoption (Next.js, Parcel)
- Better decorators support than esbuild

**Cons:**
- Smaller ecosystem than esbuild
- No type checking

### Vite (Dev Server + Rollup)

```bash
npm install --save-dev vite @vitejs/plugin-react
```

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2022',
    minify: 'terser',
    sourcemap: true,
  },
  resolve: {
    alias: {
      '@': '/src',
    },
  },
});
```

**Pros:**
- Lightning-fast HMR (Hot Module Replacement)
- Native ES modules in dev
- Great DX with plugins

**Cons:**
- Requires bundler-compatible code
- Different behavior in dev vs production

### Hybrid Approach (Recommended)

```json
{
  "scripts": {
    "build": "npm run build:types && npm run build:js",
    "build:types": "tsc --emitDeclarationOnly",
    "build:js": "esbuild src/index.ts --bundle --outfile=dist/index.js --format=esm --target=es2022",
    "dev": "tsc --watch --noEmit & esbuild src/index.ts --bundle --outfile=dist/index.js --watch",
    "type-check": "tsc --noEmit"
  }
}
```

**Benefits:**
- Use `tsc` for type checking and `.d.ts` generation
- Use `esbuild` or `swc` for fast transpilation
- Combines type safety + performance

## ESLint Configuration

### Modern ESLint Setup (v9+ Flat Config)

```bash
npm install --save-dev eslint @eslint/js typescript-eslint
```

```javascript
// eslint.config.js
import js from '@eslint/js';
import ts from 'typescript-eslint';

export default [
  js.configs.recommended,
  ...ts.configs.recommendedTypeChecked,
  {
    files: ['src/**/*.{ts,tsx}'],
    languageOptions: {
      parser: ts.parser,
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/explicit-function-return-type': 'warn',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/consistent-type-imports': 'error',
    },
  },
];
```

### ESLint for Monorepos

```javascript
// eslint.config.js (root)
import ts from 'typescript-eslint';

export default [
  ...ts.configs.recommendedTypeChecked,
  {
    files: ['packages/*/src/**/*.ts'],
    languageOptions: {
      parserOptions: {
        project: [
          './tsconfig.json',
          './packages/*/tsconfig.json',
        ],
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
];
```

### Performance Optimization

```json
{
  "scripts": {
    "lint": "eslint --cache --cache-location .eslintcache src/",
    "lint:fix": "eslint --cache --fix src/"
  }
}
```

**Tips:**
- Use `--cache` flag to speed up linting
- Create `tsconfig.eslint.json` including all paths (src, test, tools)
- In monorepos, use Nx or Turborepo to lint only affected packages

## Prettier Configuration

### Standard Configuration

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "printWidth": 100,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

### .prettierignore

```
dist/
node_modules/
coverage/
*.min.js
*.d.ts
```

### Prettier + ESLint Integration

```bash
npm install --save-dev eslint-plugin-prettier eslint-config-prettier
```

```javascript
// eslint.config.js
import prettier from 'eslint-plugin-prettier';
import prettierConfig from 'eslint-config-prettier';

export default [
  // ... other configs
  prettierConfig,
  {
    plugins: { prettier },
    rules: {
      'prettier/prettier': 'error',
    },
  },
];
```

### Monorepo Setup

```json
// Root .prettierrc (applies to all packages)
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "printWidth": 100
}
```

```json
{
  "scripts": {
    "format": "prettier --write \"packages/**/src/**/*.ts\"",
    "format:check": "prettier --check \"packages/**/src/**/*.ts\""
  }
}
```

## Path Aliases & Monorepo Configuration

### Path Aliases in tsconfig.json

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@components/*": ["src/components/*"],
      "@utils/*": ["src/utils/*"],
      "@types/*": ["types/*"]
    }
  }
}
```

### ESLint with Path Aliases

```bash
npm install --save-dev eslint-import-resolver-typescript
```

```javascript
// eslint.config.js
export default [
  {
    settings: {
      'import/resolver': {
        typescript: {
          alwaysTryTypes: true,
          project: './tsconfig.json',
        },
      },
    },
  },
];
```

### Monorepo with Project References

```
monorepo/
├── tsconfig.json (root)
├── packages/
│   ├── shared/
│   │   ├── tsconfig.json
│   │   └── src/
│   ├── api/
│   │   ├── tsconfig.json
│   │   └── src/
│   └── web/
│       ├── tsconfig.json
│       └── src/
```

**Root tsconfig.json:**
```json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true,
    "baseUrl": ".",
    "paths": {
      "@shared/*": ["packages/shared/src/*"],
      "@api/*": ["packages/api/src/*"],
      "@web/*": ["packages/web/src/*"]
    }
  },
  "references": [
    { "path": "./packages/shared" },
    { "path": "./packages/api" },
    { "path": "./packages/web" }
  ],
  "files": []
}
```

**packages/api/tsconfig.json:**
```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "references": [
    { "path": "../shared" }
  ],
  "include": ["src"]
}
```

### Build Monorepo

```json
{
  "scripts": {
    "build": "tsc --build",
    "build:clean": "tsc --build --clean",
    "build:watch": "tsc --build --watch"
  }
}
```

## Production-Ready Project Template

### Directory Structure

```
project/
├── tsconfig.json
├── tsconfig.eslint.json
├── eslint.config.js
├── .prettierrc
├── .prettierignore
├── vite.config.ts
├── package.json
├── src/
│   ├── index.ts
│   ├── types/
│   ├── utils/
│   └── components/
├── dist/
└── node_modules/
```

### Complete package.json Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc --emitDeclarationOnly && esbuild src/index.ts --bundle --outfile=dist/index.js",
    "type-check": "tsc --noEmit",
    "lint": "eslint --cache src/",
    "lint:fix": "eslint --cache --fix src/",
    "format": "prettier --write src/",
    "format:check": "prettier --check src/",
    "test": "vitest",
    "test:coverage": "vitest --coverage",
    "type-coverage": "type-coverage --at-least 85"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "esbuild": "^0.19.0",
    "eslint": "^9.0.0",
    "prettier": "^3.1.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "vitest": "^1.0.0"
  }
}
```

### Pre-commit Hooks (husky + lint-staged)

```bash
npm install --save-dev husky lint-staged
npx husky init
```

**.husky/pre-commit:**
```bash
#!/bin/sh
npx lint-staged
```

**package.json:**
```json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ]
  }
}
```

## Key Takeaways

### Configuration Best Practices

1. **Always enable `strict: true`** and additional strictness options
2. **Use `incremental: true`** for faster rebuilds
3. **Use `verbatimModuleSyntax: true`** for better tree-shaking
4. **Choose module resolution** based on target (NodeNext for Node.js, bundler for web)
5. **Use project references** for monorepos to improve build times

### Tooling Strategy

1. **Hybrid build approach**: tsc for types + esbuild/swc for code
2. **Use flat config** for ESLint (v9+)
3. **Integrate Prettier** with ESLint to avoid conflicts
4. **Enable caching** for ESLint to speed up linting
5. **Use pre-commit hooks** to enforce code quality

### Monorepo Setup

1. **Use TypeScript project references** for incremental builds
2. **Create dedicated `tsconfig.eslint.json`** files
3. **Share configurations** from root (Prettier, ESLint base)
4. **Use path aliases** for clean imports
5. **Leverage build tools** like Nx or Turborepo for affected builds

## Quick Reference

### tsconfig.json Essentials

```json
{
  "compilerOptions": {
    "strict": true,                    // Enable all strict checks
    "skipLibCheck": true,              // Skip lib checking (faster)
    "incremental": true,               // Enable incremental compilation
    "verbatimModuleSyntax": true,      // Better tree-shaking
    "noUncheckedIndexedAccess": true,  // Safer array access
    "module": "NodeNext",              // Node.js libraries
    "moduleResolution": "NodeNext"     // Future-proof resolution
  }
}
```

### Build Tool Decision Tree

```
Need type checking?
├─ Yes → Use tsc (or hybrid with esbuild)
└─ No → Choose based on speed
   ├─ Fastest → esbuild
   ├─ Framework support → SWC (Next.js) or Vite (React)
   └─ Traditional → Webpack with ts-loader
```

### Module Resolution Decision

```
What are you building?
├─ Node.js library → NodeNext
├─ Web app with bundler → bundler
├─ Legacy Node 16 → Node16
└─ Universal package → Dual publish (NodeNext + bundler)
```
