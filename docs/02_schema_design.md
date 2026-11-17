# Urban Company Home Services Database
## Schema Design Documentation

**Team Number:** T0074  
**Section:** E  
**Database:** PostgreSQL  
**Database Name:** urban_company_db  
**Schema Name:** uc

---

## 1. Introduction

The project focuses on designing a relational database for an Urban Company-style home services platform.

The database manages customers, service professionals, service categories, services, professional skills, availability, bookings, reschedules, reviews and payouts.

The objective is to maintain data consistency, reduce redundancy and support both operational transactions and analytical queries.

## 2. Database Overview

The database consists of 11 relational tables:

| No. | Table | Purpose |
|---|---|---|
| 1 | cities | Stores city and state information |
| 2 | service_categories | Stores service category details |
| 3 | services | Stores individual services and their prices |
| 4 | professionals | Stores professional profiles |
| 5 | pro_skills | Maps professionals to service categories |
| 6 | pro_availability | Stores professional working availability |
| 7 | customers | Stores customer profiles |
| 8 | bookings | Stores customer service bookings |
| 9 | reschedules | Stores booking reschedule history |
| 10 | reviews | Stores booking reviews and ratings |
| 11 | payouts | Stores professional weekly payout information |

## 3. Table Design and Attributes

### 3.1 Cities

**Purpose:** Stores the cities in which the platform operates.

| Attribute | Data type | Constraint |
|---|---|---|
| city_id | INTEGER | Primary Key, NOT NULL |
| city_name | VARCHAR(100) | NOT NULL |
| state | VARCHAR(100) | NOT NULL |

### 3.2 Service Categories

**Purpose:** Stores categories under which services are organized.

| Attribute | Data type | Constraint |
|---|---|---|
| category_id | INTEGER | Primary Key, NOT NULL |
| category_name | VARCHAR(100) | NOT NULL |

### 3.3 Services

**Purpose:** Stores the services offered by the platform.

| Attribute | Data type | Constraint |
|---|---|---|
| service_id | INTEGER | Primary Key |
| category_id | INTEGER | Foreign Key |
| service_name | VARCHAR(150) | NOT NULL |
| duration_min | INTEGER | NOT NULL, CHECK > 0 |
| base_price | NUMERIC(10,2) | NOT NULL, CHECK >= 0 |
| is_active | BOOLEAN | NOT NULL |

### 3.4 Professionals

**Purpose:** Stores professional profiles and verification information.

| Attribute | Data type | Constraint |
|---|---|---|
| pro_id | INTEGER | Primary Key |
| full_name | VARCHAR(150) | NOT NULL |
| phone | VARCHAR(20) | NOT NULL |
| city_id | INTEGER | Foreign Key |
| gender | CHAR(1) | CHECK: M or F |
| joined_on | DATE | NOT NULL |
| rating | NUMERIC(3,2) | Nullable, CHECK 0–5 |
| kyc_verified | BOOLEAN | NOT NULL |
| status | VARCHAR(20) | CHECK: ACTIVE, SUSPENDED, OFFBOARDED |

### 3.5 Professional Skills

**Purpose:** Represents the many-to-many relationship between professionals and service categories.

| Attribute | Data type | Constraint |
|---|---|---|
| pro_id | INTEGER | Composite Primary Key, Foreign Key |
| category_id | INTEGER | Composite Primary Key, Foreign Key |
| certified_on | DATE | NOT NULL |

Composite Primary Key: (pro_id, category_id).

### 3.6 Professional Availability

**Purpose:** Stores the working availability of professionals.

| Attribute | Data type | Constraint |
|---|---|---|
| pro_id | INTEGER | Composite Primary Key, Foreign Key |
| work_date | DATE | Composite Primary Key |
| start_time | TIME | NOT NULL |
| end_time | TIME | NOT NULL |

Composite Primary Key: (pro_id, work_date).

CHECK constraint: end_time must be greater than start_time.

### 3.7 Customers

**Purpose:** Stores customer account information.

| Attribute | Data type | Constraint |
|---|---|---|
| customer_id | INTEGER | Primary Key |
| full_name | VARCHAR(150) | NOT NULL |
| phone | VARCHAR(20) | NOT NULL |
| email | VARCHAR(255) | Nullable |
| city_id | INTEGER | Foreign Key |
| plus_valid_until | DATE | Nullable |
| created_at | TIMESTAMPTZ | NOT NULL |

### 3.8 Bookings

**Purpose:** Stores service booking and transaction information.

| Attribute | Data type | Constraint |
|---|---|---|
| booking_id | BIGINT | Primary Key |
| customer_id | INTEGER | Foreign Key |
| service_id | INTEGER | Foreign Key |
| pro_id | INTEGER | Nullable Foreign Key |
| city_id | INTEGER | Foreign Key |
| pincode | VARCHAR(10) | NOT NULL |
| booked_at | TIMESTAMPTZ | NOT NULL |
| scheduled_start | TIMESTAMPTZ | NOT NULL |
| scheduled_end | TIMESTAMPTZ | NOT NULL |
| started_at | TIMESTAMPTZ | Nullable |
| completed_at | TIMESTAMPTZ | Nullable |
| status | VARCHAR(30) | NOT NULL, CHECK |
| price | NUMERIC(10,2) | NOT NULL |
| discount | NUMERIC(10,2) | NOT NULL |
| cancellation_fee | NUMERIC(10,2) | NOT NULL |
| tip | NUMERIC(10,2) | Nullable |
| payment_method | VARCHAR(20) | NOT NULL, CHECK |

Additional checks include:
- scheduled_end must be later than scheduled_start.
- Price, discount and cancellation fee cannot be negative.
- Discount cannot exceed price.
- Payment method and booking status must belong to the permitted values defined in the schema.

### 3.9 Reschedules

**Purpose:** Maintains the history of booking reschedules.

| Attribute | Data type | Constraint |
|---|---|---|
| reschedule_id | INTEGER | Primary Key |
| booking_id | BIGINT | Foreign Key |
| old_start | TIMESTAMPTZ | NOT NULL |
| new_start | TIMESTAMPTZ | NOT NULL |
| requested_by | VARCHAR(20) | NOT NULL, CHECK |
| reason | TEXT | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

### 3.10 Reviews

**Purpose:** Stores customer and professional feedback associated with bookings.

| Attribute | Data type | Constraint |
|---|---|---|
| booking_id | BIGINT | Primary Key, Foreign Key |
| rating_for_pro | SMALLINT | Nullable, CHECK 1–5 |
| comment | TEXT | Nullable |
| rating_for_customer | SMALLINT | Nullable, CHECK 1–5 |
| created_at | TIMESTAMPTZ | NOT NULL |

The booking_id primary key ensures at most one review record per booking.

### 3.11 Payouts

**Purpose:** Stores weekly earnings and payout details for professionals.

| Attribute | Data type | Constraint |
|---|---|---|
| payout_id | BIGINT | Primary Key |
| pro_id | INTEGER | Foreign Key |
| week_start | DATE | NOT NULL |
| jobs | INTEGER | NOT NULL, CHECK >= 0 |
| gross_earnings | NUMERIC(12,2) | NOT NULL, CHECK >= 0 |
| commission | NUMERIC(12,2) | NOT NULL, CHECK >= 0 |
| net_payout | NUMERIC(12,2) | NOT NULL, CHECK >= 0 |
| status | VARCHAR(20) | CHECK: PAID or PENDING |
| paid_at | TIMESTAMPTZ | Nullable |

Additional constraints:
- (pro_id, week_start) must be unique.
- week_start must be a Monday.
- net_payout must equal gross_earnings minus commission.

---

## 4. Primary Key Design

Primary keys uniquely identify records in each relation.

| Table | Primary Key |
|---|---|
| cities | city_id |
| service_categories | category_id |
| services | service_id |
| professionals | pro_id |
| pro_skills | (pro_id, category_id) |
| pro_availability | (pro_id, work_date) |
| customers | customer_id |
| bookings | booking_id |
| reschedules | reschedule_id |
| reviews | booking_id |
| payouts | payout_id |

## 5. Foreign Key Relationships

| Child Table | Foreign Key | Referenced Table |
|---|---|---|
| services | category_id | service_categories |
| professionals | city_id | cities |
| pro_skills | pro_id | professionals |
| pro_skills | category_id | service_categories |
| pro_availability | pro_id | professionals |
| customers | city_id | cities |
| bookings | customer_id | customers |
| bookings | service_id | services |
| bookings | pro_id | professionals |
| bookings | city_id | cities |
| reschedules | booking_id | bookings |
| reviews | booking_id | bookings |
| payouts | pro_id | professionals |

These relationships maintain referential integrity between related records.

## 6. Relationship Cardinalities

1. One city can have multiple professionals.
2. One city can have multiple customers.
3. One city can have multiple bookings.
4. One service category can contain multiple services.
5. One professional can possess multiple skills.
6. One service category can be associated with multiple professionals.
7. One professional can have multiple availability records.
8. One customer can create multiple bookings.
9. One service can appear in multiple bookings.
10. One professional can handle multiple bookings.
11. One booking can have multiple reschedule records.
12. One booking can have at most one review.
13. One professional can receive multiple payouts.

## 7. Composite Keys and Unique Constraints

The following composite and alternate keys are implemented:

- pro_skills: (pro_id, category_id) as the composite primary key.
- pro_availability: (pro_id, work_date) as the composite primary key.
- payouts: (pro_id, week_start) as an additional unique key.

These prevent duplicate records for the corresponding business combinations.

## 8. Nullable Attributes

Some attributes are intentionally nullable because the source dataset contains missing values.

Examples include:

- professionals.rating
- customers.email
- customers.plus_valid_until
- bookings.pro_id
- bookings.started_at
- bookings.completed_at
- bookings.tip
- reviews.comment
- reviews.rating_for_customer
- payouts.paid_at

NULL values represent unavailable or not-yet-applicable information.

## 9. Integrity Constraints

The database uses:

- PRIMARY KEY constraints to uniquely identify records.
- FOREIGN KEY constraints to preserve relationships.
- NOT NULL constraints for mandatory attributes.
- UNIQUE constraints to prevent duplicate combinations.
- CHECK constraints to enforce valid values and business rules.

All constraints must be validated against the supplied seed data.

## 10. Entity Relationship Diagram

The database ER diagram is provided in:

- `diagrams/er_diagram.mmd` — editable Mermaid source.
- `diagrams/er_diagram.png` — exported diagram image.

The diagram represents all 11 entities and their relationships.

## 11. Data Integrity Validation

The seed-data inspection identified zero invalid references across the 13 tested foreign-key relationships.

Additional database integrity checks are documented separately in `docs/04_integrity_checks.md`, once their execution results have been verified.

## 12. Conclusion

The database schema separates the major entities of the home services platform into individual relations.

Primary keys, foreign keys, composite keys, unique constraints and check constraints provide the structural foundation for maintaining consistency and supporting operational and analytical database queries.

The normalization analysis is documented separately in `docs/03_normalization.md`.
