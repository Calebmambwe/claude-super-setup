# Full-Stack Generation Specification

## Goal

Generate complete, production-ready full-stack applications from a single prompt or spec. Every generated app includes auth, database, API, frontend, testing, and deployment configuration.

## Stack Decisions

### Default Full-Stack (SaaS template)
- **Framework:** Next.js 15 (App Router, Server Components)
- **Styling:** Tailwind CSS v4 + shadcn/ui
- **Auth:** Clerk (fastest) or NextAuth v5 (self-hosted)
- **Database:** PostgreSQL + Drizzle ORM
- **Email:** Resend + React Email
- **Payments:** Stripe (Checkout + Billing Portal)
- **File Storage:** Supabase Storage or S3
- **Real-time:** Supabase Realtime or Pusher
- **Testing:** Vitest (unit) + Playwright (E2E)
- **Deployment:** Vercel (frontend) + Railway/Supabase (database)

### API-Only Stack
- **Framework:** Hono (edge) or FastAPI (Python)
- **Database:** PostgreSQL + Drizzle/SQLAlchemy
- **Auth:** JWT + refresh tokens
- **Testing:** Vitest/Pytest + Supertest/httpx

### Mobile Stack
- **Framework:** Expo 54 + React Native
- **UI:** Gluestack v3 + NativeWind v4
- **Navigation:** Expo Router v4
- **Auth:** Clerk (React Native SDK)
- **State:** Zustand + React Query

## Generation Layers

### Layer 1: Database Schema

From a description, generate:
```sql
-- users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user', 'viewer')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
```

Plus Drizzle schema:
```typescript
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: varchar('email', { length: 255 }).unique().notNull(),
  name: varchar('name', { length: 100 }).notNull(),
  role: text('role').notNull().default('user'),
  avatarUrl: text('avatar_url'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
```

### Layer 2: API Layer

Server Actions (Next.js) or API routes:
```typescript
// actions/users.ts
'use server'

import { db } from '@/lib/db';
import { users } from '@/lib/schema';
import { auth } from '@clerk/nextjs/server';
import { eq } from 'drizzle-orm';
import { z } from 'zod';

const updateProfileSchema = z.object({
  name: z.string().min(2).max(100),
  avatarUrl: z.string().url().optional(),
});

export async function updateProfile(input: z.infer<typeof updateProfileSchema>) {
  const { userId } = await auth();
  if (!userId) throw new Error('Unauthorized');

  const validated = updateProfileSchema.parse(input);

  const [updated] = await db
    .update(users)
    .set({ ...validated, updatedAt: new Date() })
    .where(eq(users.id, userId))
    .returning();

  return updated;
}
```

### Layer 3: Frontend Pages

For each entity, generate:
- List page with pagination, search, filters
- Detail page with full entity display
- Create/Edit form with Zod validation
- Delete confirmation dialog

### Layer 4: Auth Integration

Clerk setup:
```typescript
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server';

const isProtectedRoute = createRouteMatcher(['/dashboard(.*)', '/settings(.*)']);

export default clerkMiddleware(async (auth, req) => {
  if (isProtectedRoute(req)) await auth.protect();
});

export const config = { matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'] };
```

### Layer 5: Payment Integration

Stripe Checkout + Billing Portal:
```typescript
// actions/billing.ts
'use server'

import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function createCheckoutSession(priceId: string) {
  const { userId } = await auth();
  if (!userId) throw new Error('Unauthorized');

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_URL}/dashboard?success=true`,
    cancel_url: `${process.env.NEXT_PUBLIC_URL}/pricing`,
    metadata: { userId },
  });

  return { url: session.url };
}
```

### Layer 6: Email Templates

React Email + Resend:
```typescript
// emails/welcome.tsx
import { Html, Head, Body, Container, Text, Button } from '@react-email/components';

export function WelcomeEmail({ name }: { name: string }) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'Inter, sans-serif' }}>
        <Container>
          <Text>Welcome, {name}!</Text>
          <Button href={`${process.env.NEXT_PUBLIC_URL}/dashboard`}>
            Go to Dashboard
          </Button>
        </Container>
      </Body>
    </Html>
  );
}
```

## Generation Quality Checks

For every generated full-stack app:
- [ ] Auth flow works end-to-end (sign up → sign in → protected page)
- [ ] Database migrations run without errors
- [ ] All API endpoints return correct response shapes
- [ ] Forms validate input and show errors
- [ ] Empty states shown when no data
- [ ] Loading states shown during data fetching
- [ ] Error states shown on API failures
- [ ] Responsive at all breakpoints
- [ ] No TypeScript errors
- [ ] No console errors
- [ ] E2E tests pass for critical flows
