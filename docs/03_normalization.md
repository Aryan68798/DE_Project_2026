# Functional Dependency and Normalization Analysis

## 1. Introduction

The Urban Company Home Services database contains 11 relations.
The objective of normalization is to reduce redundant data,
avoid insertion, deletion and update anomalies, and maintain
data integrity.

This analysis uses the primary keys, composite keys and unique
constraints declared in the PostgreSQL schema.

## 2. Functional Dependencies

A functional dependency X -> Y means that the attributes in X
uniquely determine the attributes in Y.

### 2.1 Cities

Primary key: city_id

Functional dependency:
city_id -> city_name, state

### 2.2 Service Categories

Primary key: category_id

Functional dependency:
category_id -> category_name

### 2.3 Services

Primary key: service_id

Functional dependency:
service_id -> category_id, service_name, duration_min,
              base_price, is_active

### 2.4 Professionals

Primary key: pro_id

Functional dependency:
pro_id -> full_name, phone, city_id, gender, joined_on,
          rating, kyc_verified, status

### 2.5 Professional Skills

Composite primary key: (pro_id, category_id)

Functional dependency:
(pro_id, category_id) -> certified_on

Neither pro_id nor category_id alone determines certified_on
under the declared key constraints.

### 2.6 Professional Availability

Composite primary key: (pro_id, work_date)

Functional dependency:
(pro_id, work_date) -> start_time, end_time

### 2.7 Customers

Primary key: customer_id

Functional dependency:
customer_id -> full_name, phone, email, city_id,
              plus_valid_until, created_at

### 2.8 Bookings

Primary key: booking_id

Functional dependency:
booking_id -> customer_id, service_id, pro_id, city_id,
              pincode, booked_at, scheduled_start,
              scheduled_end, started_at, completed_at,
              status, price, discount, cancellation_fee,
              tip, payment_method

### 2.9 Reschedules

Primary key: reschedule_id

Functional dependency:
reschedule_id -> booking_id, old_start, new_start,
                 requested_by, reason, created_at

### 2.10 Reviews

Primary key: booking_id

Functional dependency:
booking_id -> rating_for_pro, comment,
              rating_for_customer, created_at

### 2.11 Payouts

Primary key: payout_id

Functional dependency:
payout_id -> pro_id, week_start, jobs, gross_earnings,
             commission, net_payout, status, paid_at

Additional declared unique key:
(pro_id, week_start)

Therefore:
(pro_id, week_start) -> jobs, gross_earnings,
                        commission, net_payout,
                        status, paid_at

## 3. Candidate Key Analysis

The declared candidate keys are:

| Relation | Declared key |
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
| payouts | (pro_id, week_start) |

No additional candidate keys are assumed without supporting
UNIQUE constraints or verified business rules.

## 4. First Normal Form (1NF)

A relation satisfies 1NF when:
- Each attribute contains a single value.
- Each row can be uniquely identified.
- There are no repeating groups or multivalued attributes.

The database stores individual values in separate columns.
The many-to-many relationship between professionals and
service categories is represented by pro_skills.

The relations are designed to satisfy 1NF.

## 5. Second Normal Form (2NF)

A relation satisfies 2NF when:
- It satisfies 1NF.
- Every non-prime attribute is fully dependent on the
  entire candidate key.

The relations with single-column primary keys do not have
partial dependencies on a subset of their primary keys.

For pro_skills, certified_on depends on the complete
(pro_id, category_id) key.

For pro_availability, start_time and end_time depend on
the complete (pro_id, work_date) key.

Therefore, no partial dependency is identified from the
declared functional dependencies.

## 6. Third Normal Form (3NF)

A relation satisfies 3NF when, for every non-trivial
functional dependency X -> A, either:
- X is a superkey, or
- A is a prime attribute.

The declared key-based functional dependencies have
candidate keys as their determinants.

No additional non-key-to-non-key functional dependencies
have been established from the available schema.

Therefore, the declared dependencies do not show a
3NF violation.

## 7. Boyce-Codd Normal Form (BCNF)

A relation satisfies BCNF when every non-trivial
functional dependency has a superkey as its determinant.

Based on the declared key-based dependencies, the
relations satisfy BCNF.

The additional unique key in payouts,
(pro_id, week_start), is also a candidate key and
therefore does not introduce a BCNF violation.

This conclusion is limited to the functional dependencies
identified from the declared schema. Additional business
rules could reveal further dependencies.

## 8. Composite Key Justification

### pro_skills
A professional can possess multiple service categories,
and a category can be associated with multiple professionals.
The pair (pro_id, category_id) identifies each skill record.

### pro_availability
A professional has one availability record per work_date
under the declared primary key (pro_id, work_date).

### payouts
The unique constraint on (pro_id, week_start) prevents
duplicate payout records for the same professional and week.

## 9. Normalization Conclusion

The database uses primary keys, composite keys, foreign keys
and unique constraints to organize its data.

Based on the declared functional dependencies, no partial
or transitive dependencies have been identified, and the
relations satisfy the key-based tests for 3NF and BCNF.

A complete theoretical proof would additionally require
confirmation of all real-world business functional
dependencies, not only the declared database constraints.
