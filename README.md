# Coseller Migration POC — dbt Project

dbt transformation layer for the MongoDB to PostgreSQL migration proof of concept. This project transforms raw Airbyte-synced data from MongoDB into flat, relational tables compatible with Prisma and PostgreSQL.

## Data Flow

```
MongoDB (staging clone)          Airbyte Cloud              PostgreSQL (Render)
┌─────────────────────┐    ┌──────────────────────┐    ┌──────────────────────────────────┐
│ bvcrmwapp-staging    │───>│ Full refresh sync    │───>│ Schema: bvcrmwapp_airbyte        │
│                      │    │ BSON -> flat columns  │    │ (raw Airbyte tables)             │
│ - contacts           │    │ + embedded -> JSONB   │    │ - contacts                       │
│ - companies          │    │                      │    │ - companies                      │
│ - campaign_companies │    └──────────────────────┘    │ - campaign_companies             │
│ - campaign_company_  │                                │ - campaign_company_contacts       │
│   contacts           │                                │                                  │
└─────────────────────┘                                 │ Each table has:                  │
                                                        │ - Top-level fields as columns    │
                                                        │ - Embedded docs as JSONB columns │
                                                        │ - _airbyte_* metadata columns    │
                                                        └──────────────┬───────────────────┘
                                                                       │
                                                                  dbt build
                                                                       │
                                                                       v
                                                        ┌──────────────────────────────────┐
                                                        │ Schema: *_staging (views)        │
                                                        │ Staging layer:                   │
                                                        │ - Rename camelCase -> snake_case  │
                                                        │ - Extract JSONB -> flat columns   │
                                                        │ - Cast types (bool, int, ts)     │
                                                        │ - Fix type mismatches (see below)│
                                                        │ - Filter CDC soft deletes        │
                                                        └──────────────┬───────────────────┘
                                                                       │
                                                                  dbt build
                                                                       │
                                                                       v
                                                        ┌──────────────────────────────────┐
                                                        │ Schema: *_marts (tables)         │
                                                        │ Marts layer:                     │
                                                        │ - Final Prisma-compatible shape  │
                                                        │ - Indexed for query performance  │
                                                        │ - Real PK + FK constraints       │
                                                        │   (via dbt_constraints package)  │
                                                        └──────────────────────────────────┘
```

## Folder Structure

```
dbt-poc/
├── dbt_project.yml                          # Project config, materialization defaults, dbt_constraints vars
├── packages.yml                             # dbt packages (dbt_constraints for PK/FK enforcement)
├── models/
│   ├── staging/coseller/                    # Staging layer (materialized as views)
│   │   ├── _coseller__sources.yml           # Source definitions (bvcrmwapp_airbyte schema)
│   │   ├── _coseller__models.yml            # Staging tests (unique + not_null on PKs)
│   │   ├── stg_coseller__contacts.sql       # Staged contacts
│   │   ├── stg_coseller__companies.sql      # Staged companies
│   │   ├── stg_coseller__campaign_companies.sql
│   │   └── stg_coseller__campaign_company_contacts.sql
│   └── marts/                               # Marts layer (materialized as tables)
│       ├── _marts__models.yml               # Mart tests + PK/FK constraints (dbt_constraints)
│       ├── contacts.sql                     # Final contacts table
│       ├── companies.sql                    # Final companies table
│       ├── campaign_companies.sql           # Final campaign_companies table
│       └── campaign_company_contacts.sql    # Final campaign_company_contacts table
├── macros/                                  # Reusable SQL/Jinja macros (empty for now)
├── seeds/                                   # Static CSV data files (empty for now)
├── snapshots/                               # Slowly changing dimension snapshots (empty for now)
├── tests/                                   # Custom singular test queries (empty for now)
└── analyses/                                # Ad-hoc analytical queries (empty for now)
```

## File Types Explained

### `_coseller__sources.yml` — Source Definitions

Declares the raw Airbyte tables as dbt sources. This tells dbt where to find the data and enables the `{{ source() }}` function in SQL models. Also defines basic tests on source columns (e.g., `_id` is not null).

### `stg_*.sql` — Staging Models

One per source table. These are the **single entry point** for each raw table — no other model should read directly from `{{ source() }}`. Staging models:

- **Rename columns** from MongoDB camelCase to PostgreSQL snake_case (`firstName` -> `first_name`)
- **Extract embedded JSONB objects** into flat columns (`country->>'_id'` -> `country_id`)
- **Flatten nested audit fields** (`created->'by'->>'_id'` -> `created_by_id`, `(created->>'on')::timestamp` -> `created_at`)
- **Cast types** (`active::boolean`, `callAttempts::integer`)
- **Fix Airbyte type mismatches** (see section below)
- **Filter out CDC soft deletes** (`WHERE _ab_cdc_deleted_at IS NULL`)

Materialized as **views** — no data duplication, always reflects the latest Airbyte sync.

### `marts/*.sql` — Mart Models

Final tables that match the target Prisma PostgreSQL schema shape. These are what the application would query. Mart models:

- **Select the final column set** from staging views
- **Define PostgreSQL indexes** matching the current Prisma schema (`@@index` directives)
- **Are materialized as tables** — physical data for fast query performance

### `packages.yml` — dbt Packages

Declares external dbt packages. Currently includes:

- **`dbt_constraints`** (Snowflake-Labs) — generates real database-level `PRIMARY KEY` and `FOREIGN KEY` constraints from test definitions. Supports PostgreSQL.

### `_*__models.yml` — Model Tests and Constraints

YAML files defining data quality tests per model. In the marts layer, these tests also create real database constraints via `dbt_constraints`:

- **`dbt_constraints.primary_key`** — creates a real `PRIMARY KEY` constraint + validates uniqueness and not-null
- **`dbt_constraints.foreign_key`** — creates a real `FOREIGN KEY` constraint + validates referential integrity
- **`not_null`** — ensures required fields are present

Run with `dbt test` or `dbt build`.

### `dbt_project.yml` — Project Configuration

Top-level config: project name, directory paths, default materialization per layer, and `dbt_constraints` variables:

- `models/staging/` -> `+materialized: view`
- `models/marts/` -> `+materialized: table`
- `dbt_constraints_enabled: true` — enables constraint generation
- `dbt_constraints_pk_enabled: true` — enables primary key constraints
- `dbt_constraints_fk_enabled: true` — enables foreign key constraints

## Key Transformations

### Embedded Documents to Flat Columns

MongoDB stores nested objects inline. dbt extracts them into discrete columns:

```
MongoDB (JSONB in Airbyte):                  PostgreSQL (after dbt):
{                                            country_id    = 'SE'
  "country": {                               country_name  = 'Sweden'
    "_id": "SE",
    "name": "Sweden"
  }
}

{                                            created_at      = 2022-02-10 08:55:35
  "created": {                               created_by_id   = 'EhZceJDDMQmckSdZ3'
    "on": "2022-02-10T08:55:35.831Z",       created_by_name = 'Timo Jarvinen'
    "by": {
      "_id": "EhZceJDDMQmckSdZ3",
      "name": "Timo Jarvinen"
    }
  }
}
```

### Airbyte Type Mismatches

Airbyte infers column types from the first batch of documents. When MongoDB documents have inconsistent types for the same field (common in Meteor-era data), Airbyte falls back to `jsonb`. The staging models handle these:

| Table | Column | Expected type | Airbyte type | Staging fix |
|---|---|---|---|---|
| `contacts` | `linkedinUrl` | varchar | jsonb | `"linkedinUrl" #>>'{}'` (extract text from jsonb) |
| `campaign_company_contacts` | `campaignId` | varchar | jsonb | `"campaignId" #>>'{}'` |
| `companies` | `zipcode` | single column | two columns: `zipCode` (3 rows) + `zipcode_1` (377K rows) | `zipcode_1 as zipcode` |

### Arrays Kept as JSONB

Some fields (`activities`, `fiscal`, `prio`, `fields`) remain as JSONB columns because they are either:
- Rarely queried by individual elements
- Variable-length arrays better suited for JSONB storage
- Configuration blobs read as a whole

### CDC Soft Delete Filtering

Airbyte CDC adds `_ab_cdc_deleted_at` to track documents deleted in MongoDB. Staging models filter these out so only active records flow to marts.

## Database Constraints

The `dbt_constraints` package creates real database-level constraints on the mart tables:

**Primary Keys:**
- `contacts.id`
- `companies.id`
- `campaign_companies.id`
- `campaign_company_contacts.id`

**Foreign Keys:**
- `campaign_companies.company_id` -> `companies.id`
- `campaign_company_contacts.contact_id` -> `contacts.id`
- `campaign_company_contacts.company_id` -> `companies.id`

These are enforced at the PostgreSQL level — invalid inserts/updates are rejected by the database.

## Commands

```bash
dbt deps                   # Install packages (dbt_constraints)
dbt build                  # Run + test all models in dependency order (recommended)
dbt run                    # Build all models (staging views + mart tables)
dbt test                   # Run all data quality tests + create constraints
dbt run --select staging   # Build only staging views
dbt run --select marts     # Build only mart tables
dbt compile                # Preview compiled SQL without executing
```

## Schemas

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| Source | `bvcrmwapp_airbyte` | -- (raw Airbyte tables) | Data as-is from MongoDB |
| Staging | `*_staging` | Views | Renamed, typed, flattened |
| Marts | `*_marts` | Tables with indexes + PK/FK constraints | Final Prisma-compatible shape |

*Exact schema names depend on the dbt target/profile config (e.g., `public_staging`, `public_marts`).*
