---
name: db-migrate
description: Create a database migration using the project's detected ORM or migration tool
---
Create a database migration: $ARGUMENTS

## Step 1: Detect ORM / Migration Tool

Check for:
- **Prisma** (prisma/schema.prisma) → use `prisma migrate`
- **Drizzle** (drizzle.config.ts) → use `drizzle-kit generate`
- **Knex** (knexfile.ts) → use `knex migrate:make`
- **Alembic** (alembic.ini) → use `alembic revision --autogenerate`
- **SQLAlchemy** → use Alembic
- **Django** → use `python manage.py makemigrations`
- **Raw SQL** → create timestamped .sql files in migrations/

If no tool is detected, ask the user which to set up.

## Step 2: Understand the Change

From the arguments, determine:
- Tables to create/alter/drop
- Columns to add/modify/remove
- Indexes to create
- Foreign key relationships
- Default values and constraints

## Step 3: Generate Migration

### Prisma
1. Update `prisma/schema.prisma` with the changes
2. Run `npx prisma migrate dev --name <migration-name>`

### Drizzle
1. Update the schema file (src/db/schema.ts)
2. Run `npx drizzle-kit generate`

### Knex
1. Run `npx knex migrate:make <migration-name>`
2. Fill in the `up` and `down` functions

### Alembic
1. Update SQLAlchemy models
2. Run `uv run alembic revision --autogenerate -m "<description>"`
3. Review the generated migration for accuracy

### Raw SQL
1. Create `migrations/<timestamp>_<description>.sql`
2. Include both UP and DOWN sections

## Step 4: Verify

- Check the generated migration file for correctness
- Ensure DOWN/rollback migration reverses all changes
- Verify foreign keys point to existing tables
- Check index names don't conflict

## Rules
- ALWAYS include a rollback (down) migration
- ALWAYS use descriptive migration names (e.g., "add_user_email_index" not "update")
- NEVER put data transforms in the same migration as schema changes
- NEVER drop columns in production without a deprecation period
- ALWAYS add NOT NULL constraints with a default value for existing rows
