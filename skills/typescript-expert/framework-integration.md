# TypeScript Framework & Library Integration

## Overview

Complete guide to integrating TypeScript with modern frameworks (React 19, Node.js, Next.js, Remix) and libraries (tRPC, GraphQL, Prisma, Drizzle). Covers type-safe patterns for full-stack development with end-to-end type safety.

## React with TypeScript

### Component Props Typing

```typescript
// Use 'type' for component props (React convention)
type ButtonProps = {
  label: string;
  onClick: (event: React.MouseEvent<HTMLButtonElement>) => void;
  variant?: 'primary' | 'secondary' | 'danger';
  disabled?: boolean;
  children?: React.ReactNode;
};

// Functional component
const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  variant = 'primary',
  disabled = false,
}) => {
  return (
    <button
      className={`btn-${variant}`}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  );
};

// Alternative: Direct function type (more flexible)
function Button({ label, onClick, variant = 'primary' }: ButtonProps) {
  return <button onClick={onClick}>{label}</button>;
}
```

### Hooks Typing

```typescript
// useState
const [count, setCount] = useState<number>(0);
const [user, setUser] = useState<User | null>(null);

// useRef
const inputRef = useRef<HTMLInputElement>(null);
const timerRef = useRef<NodeJS.Timeout | null>(null);

// useEffect (no special typing needed)
useEffect(() => {
  // Effect logic
  return () => {
    // Cleanup
  };
}, [dependencies]);

// Custom hook
function useUser(userId: string): [User | null, boolean, Error | null] {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetchUser(userId)
      .then(setUser)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [userId]);

  return [user, loading, error];
}

// Better: Return object for clarity
function useUser(userId: string) {
  // ... same logic
  return { user, loading, error };
}
```

### React 19 Updates (2025)

```typescript
// Refs no longer require forwardRef wrapper
type InputProps = {
  placeholder: string;
  ref?: React.Ref<HTMLInputElement>;
};

function Input({ placeholder, ref }: InputProps) {
  return <input ref={ref} placeholder={placeholder} />;
}

// Action functions with useActionState
import { useActionState } from 'react';

async function submitForm(prevState: State, formData: FormData): Promise<State> {
  // Server action
  const name = formData.get('name') as string;
  return { success: true, message: 'Submitted' };
}

function Form() {
  const [state, action] = useActionState(submitForm, { success: false, message: '' });
  return <form action={action}>...</form>;
}
```

### Event Handlers

```typescript
// Mouse events
const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
  event.preventDefault();
  console.log('Clicked');
};

// Form events
const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
  event.preventDefault();
  const formData = new FormData(event.currentTarget);
  // Process form data
};

// Input events
const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
  console.log(event.target.value);
};

// Keyboard events
const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
  if (event.key === 'Enter') {
    // Handle Enter key
  }
};
```

## Node.js with TypeScript

### Fastify (Recommended for 2025)

**Setup:**
```bash
npm install fastify @types/node
```

**Type-Safe Routes:**
```typescript
import Fastify, { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

const fastify: FastifyInstance = Fastify({ logger: true });

// Route with typed params
fastify.get<{
  Params: { id: string };
  Querystring: { filter?: string };
  Reply: User;
}>('/user/:id', async (request, reply) => {
  const { id } = request.params; // Typed as string
  const { filter } = request.query; // Typed as string | undefined

  const user = await getUserById(id, filter);
  return user; // Typed as User
});

// Route with typed body
fastify.post<{
  Body: CreateUserRequest;
  Reply: User;
}>('/user', async (request, reply) => {
  const userData = request.body; // Typed as CreateUserRequest
  const user = await createUser(userData);
  reply.code(201).send(user);
});

// Start server
fastify.listen({ port: 3000 }, (err, address) => {
  if (err) throw err;
  console.log(`Server running at ${address}`);
});
```

**Plugin Pattern:**
```typescript
import { FastifyPluginAsync } from 'fastify';

const userRoutes: FastifyPluginAsync = async (fastify, opts) => {
  fastify.get('/users', async (request, reply) => {
    return await fastify.db.user.findMany();
  });
};

export default userRoutes;
```

**Performance:** Handles 70,000-80,000 req/sec vs Express's 20,000-30,000

### Express with TypeScript

**Setup:**
```bash
npm install express
npm install --save-dev @types/express @types/node
```

**Type-Safe Routes:**
```typescript
import express, { Request, Response, NextFunction } from 'express';

const app = express();

// Typed request and response
interface UserParams {
  id: string;
}

interface UserResponse {
  id: string;
  name: string;
}

app.get('/user/:id', (
  req: Request<UserParams>,
  res: Response<UserResponse>
) => {
  const { id } = req.params;
  res.json({ id, name: 'John' });
});

// Typed middleware
const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Auth logic
  next();
};

app.use(authMiddleware);

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

**Decision:** Choose Fastify for new projects (better TypeScript support, faster). Choose Express for legacy or enterprise projects with existing Express expertise.

## Next.js with TypeScript

### Setup

```bash
npx create-next-app@latest --typescript
```

### Page Components

```typescript
// app/page.tsx (App Router)
export default function Home() {
  return <div>Home Page</div>;
}

// With async data fetching
async function getData(): Promise<Product[]> {
  const res = await fetch('https://api.example.com/products');
  if (!res.ok) throw new Error('Failed to fetch');
  return res.json();
}

export default async function ProductsPage() {
  const products = await getData();
  return (
    <div>
      {products.map(product => (
        <div key={product.id}>{product.name}</div>
      ))}
    </div>
  );
}
```

### API Routes

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const users = await db.user.findMany();
  return NextResponse.json(users);
}

export async function POST(request: NextRequest) {
  const body: CreateUserRequest = await request.json();
  const user = await db.user.create({ data: body });
  return NextResponse.json(user, { status: 201 });
}

// Dynamic route: app/api/users/[id]/route.ts
type Params = {
  params: { id: string };
};

export async function GET(request: NextRequest, { params }: Params) {
  const user = await db.user.findUnique({ where: { id: params.id } });
  if (!user) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
  return NextResponse.json(user);
}
```

### Server Actions

```typescript
// app/actions.ts
'use server';

import { z } from 'zod';

const UserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

export async function createUser(formData: FormData) {
  const validatedFields = UserSchema.safeParse({
    name: formData.get('name'),
    email: formData.get('email'),
  });

  if (!validatedFields.success) {
    return { error: 'Invalid fields' };
  }

  const user = await db.user.create({ data: validatedFields.data });
  return { success: true, user };
}
```

**Best for:** Static sites, e-commerce, SEO-heavy projects, content + interactivity

## Remix with TypeScript

### Setup

```bash
npx create-remix@latest --typescript
```

### Route Loaders

```typescript
// app/routes/products.$id.tsx
import { json, LoaderFunctionArgs } from '@remix-run/node';
import { useLoaderData } from '@remix-run/react';

type LoaderData = {
  product: Product;
};

export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.product.findUnique({
    where: { id: params.id },
  });

  if (!product) {
    throw new Response('Not Found', { status: 404 });
  }

  return json<LoaderData>({ product });
}

export default function ProductPage() {
  const { product } = useLoaderData<typeof loader>();

  return (
    <div>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
    </div>
  );
}
```

### Route Actions

```typescript
import { ActionFunctionArgs, redirect } from '@remix-run/node';
import { Form } from '@remix-run/react';

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const name = formData.get('name') as string;
  const email = formData.get('email') as string;

  await db.user.create({ data: { name, email } });

  return redirect('/users');
}

export default function NewUser() {
  return (
    <Form method="post">
      <input type="text" name="name" required />
      <input type="email" name="email" required />
      <button type="submit">Create User</button>
    </Form>
  );
}
```

**Best for:** Full-stack interactive apps, real-time data-driven dashboards, smaller initial JS payload (30% smaller than Next.js)

## API Client Typing

### tRPC (Recommended for TypeScript Monorepos)

**Setup:**
```bash
npm install @trpc/server @trpc/client @trpc/react-query
```

**Server (Backend):**
```typescript
import { initTRPC } from '@trpc/server';
import { z } from 'zod';

const t = initTRPC.create();

const appRouter = t.router({
  user: t.router({
    get: t.procedure
      .input(z.object({ id: z.string() }))
      .query(async ({ input }) => {
        return db.user.findUnique({ where: { id: input.id } });
      }),

    create: t.procedure
      .input(z.object({
        name: z.string(),
        email: z.string().email(),
      }))
      .mutation(async ({ input }) => {
        return db.user.create({ data: input });
      }),
  }),
});

export type AppRouter = typeof appRouter;
```

**Client (Frontend):**
```typescript
import { createTRPCProxyClient, httpBatchLink } from '@trpc/client';
import type { AppRouter } from './server';

const client = createTRPCProxyClient<AppRouter>({
  links: [
    httpBatchLink({
      url: 'http://localhost:3000/trpc',
    }),
  ],
});

// Fully typed automatically!
const user = await client.user.get.query({ id: '123' });
// user is typed as User

const newUser = await client.user.create.mutate({
  name: 'John',
  email: 'john@example.com',
});
```

**Benefits:**
- End-to-end type safety without code generation
- Zero boilerplate
- Perfect for monorepos (Next.js, Remix, Vite)

**Limitations:**
- TypeScript-only (not ideal for public APIs)
- No automatic OpenAPI generation

### GraphQL with TypeScript

**Setup:**
```bash
npm install graphql @apollo/client
npm install --save-dev @graphql-codegen/cli @graphql-codegen/typescript
```

**Code Generation Config:**
```yaml
# codegen.yml
schema: http://localhost:4000/graphql
generates:
  ./src/generated/graphql.ts:
    plugins:
      - typescript
      - typescript-operations
      - typescript-react-apollo
```

**Usage:**
```typescript
import { useQuery, gql } from '@apollo/client';
import { GetUserQuery, GetUserQueryVariables } from './generated/graphql';

const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
    }
  }
`;

function UserProfile({ userId }: { userId: string }) {
  const { data, loading, error } = useQuery<GetUserQuery, GetUserQueryVariables>(
    GET_USER,
    { variables: { id: userId } }
  );

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return <div>{data?.user?.name}</div>;
}
```

**Best for:** Complex data relationships, mature tooling, multi-client support

## ORM & Database Typing

### Drizzle (2025 Winner for Performance)

**Setup:**
```bash
npm install drizzle-orm pg
npm install --save-dev drizzle-kit @types/pg
```

**Schema Definition:**
```typescript
import { pgTable, serial, text, timestamp, integer } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').unique().notNull(),
  age: integer('age'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  content: text('content').notNull(),
  authorId: integer('author_id').references(() => users.id),
  createdAt: timestamp('created_at').defaultNow(),
});
```

**Queries:**
```typescript
import { drizzle } from 'drizzle-orm/node-postgres';
import { eq, and, gt } from 'drizzle-orm';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const db = drizzle(pool);

// Select - fully typed
const allUsers = await db.select().from(users);
// allUsers: { id: number; name: string; email: string; ... }[]

// Where clause
const user = await db.select().from(users).where(eq(users.id, 1));

// Joins
const postsWithAuthors = await db
  .select()
  .from(posts)
  .leftJoin(users, eq(posts.authorId, users.id));

// Insert
const newUser = await db
  .insert(users)
  .values({ name: 'John', email: 'john@example.com' })
  .returning();

// Update
await db
  .update(users)
  .set({ name: 'Jane' })
  .where(eq(users.id, 1));

// Delete
await db.delete(users).where(eq(users.id, 1));
```

**Benefits:**
- Only 7.4kb minified+gzipped
- Fastest ORM for NestJS apps (2025)
- Full TypeScript inference
- SQL-like API

### Prisma (2025 Runner-up)

**Setup:**
```bash
npm install prisma @prisma/client
npx prisma init
```

**Schema Definition:**
```prisma
// prisma/schema.prisma
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
}

model Post {
  id        Int      @id @default(autoincrement())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  Int
}
```

**Generate Client:**
```bash
npx prisma generate
```

**Queries:**
```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Select all
const users = await prisma.user.findMany();

// Select with relations
const userWithPosts = await prisma.user.findUnique({
  where: { id: 1 },
  include: { posts: true },
});

// Create
const newUser = await prisma.user.create({
  data: {
    name: 'John',
    email: 'john@example.com',
    posts: {
      create: [{ title: 'First Post', content: 'Hello World' }],
    },
  },
});

// Update
await prisma.user.update({
  where: { id: 1 },
  data: { name: 'Jane' },
});

// Delete
await prisma.user.delete({ where: { id: 1 } });
```

**Benefits:**
- Full-featured ORM with powerful tooling
- Broad database support
- Generated client with full type safety
- Excellent migration system

### Comparison

| Feature | Drizzle | Prisma |
|---------|---------|--------|
| Bundle Size | 7.4kb | ~30kb |
| Type Safety | Excellent | Excellent |
| SQL Control | High | Medium |
| Performance | Fastest | Fast |
| Learning Curve | Moderate | Low |

**Recommendation:** Use **Drizzle** for new projects requiring raw SQL control, type safety, and minimal runtime overhead. Use **Prisma** for abstracted workflows and broader tooling ecosystem.

## End-to-End Type Safety Stack

### Full-Stack TypeScript Stack (Recommended 2025)

```
Frontend: React 19 + TypeScript
Framework: Next.js 16+ or Remix 2+
API Layer: tRPC (monorepo) or REST with OpenAPI
Backend: Fastify with TypeScript
Database: Drizzle ORM
Validation: Zod
Result: Complete type safety from database to UI
```

**Example Flow:**
```typescript
// 1. Database schema (Drizzle)
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').unique().notNull(),
});

// 2. API endpoint (tRPC)
const appRouter = t.router({
  user: {
    create: t.procedure
      .input(z.object({
        name: z.string(),
        email: z.string().email(),
      }))
      .mutation(async ({ input }) => {
        return db.insert(users).values(input).returning();
      }),
  },
});

// 3. Frontend (React)
function CreateUser() {
  const createUser = trpc.user.create.useMutation();

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    await createUser.mutate({
      name: formData.get('name') as string,
      email: formData.get('email') as string,
    });
  };

  return <form onSubmit={handleSubmit}>...</form>;
}
```

**Type Safety:**
- Database schema defines types
- API layer validates and transforms
- Frontend gets automatic type inference
- No manual type definitions needed

## Best Practices Summary

### React

1. Use `type` for component props (convention)
2. Destructure props with default values
3. Type event handlers explicitly
4. Use custom hooks for reusable logic
5. Leverage React 19 features (refs as props)

### Node.js

1. Choose Fastify for new projects (better TypeScript + performance)
2. Type request/response bodies explicitly
3. Use plugin pattern for modularity
4. Handle errors with proper types
5. Validate input with Zod or similar

### API Clients

1. Use tRPC for TypeScript monorepos (zero boilerplate)
2. Use GraphQL for complex data relationships
3. Use OpenAPI for public/polyglot APIs
4. Always validate API responses
5. Implement proper error handling

### ORMs

1. Choose Drizzle for raw SQL control + type safety
2. Choose Prisma for abstraction + tooling
3. Always use migrations for schema changes
4. Type database queries explicitly
5. Use transactions for multi-step operations

## Quick Reference

### Framework Decision Tree

```
What are you building?
├─ API only → Fastify
├─ Full-stack web app
│  ├─ SEO important → Next.js
│  ├─ Smaller bundle → Remix
│  └─ Complex forms → Remix
├─ Real-time app → Remix (better SSR)
└─ Static site → Next.js (ISR)
```

### API Client Decision

```
Choose tRPC if:
- TypeScript monorepo
- Internal APIs
- Want zero boilerplate

Choose GraphQL if:
- Complex data relationships
- Multiple clients
- Established GraphQL expertise

Choose REST + OpenAPI if:
- Public API
- Multi-language support
- OpenAPI ecosystem
```

### ORM Decision

```
Choose Drizzle if:
- Need raw SQL control
- Want minimal bundle size
- Performance critical

Choose Prisma if:
- Want abstraction layer
- Need comprehensive tooling
- Rapid development priority
```
