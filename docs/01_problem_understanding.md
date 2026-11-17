
# Urban Company Home Services Database
## Problem Understanding

**Team:** T0074  
**Section:** E  
**Database:** PostgreSQL  
**Schema:** uc

## 1. Problem Statement

The project focuses on designing a relational database
for an Urban Company-style home services platform.

The platform connects customers with service professionals
for services such as cleaning, repairs and other home
maintenance activities.

The database must manage customers, professionals,
services, bookings, availability, reschedules, reviews
and professional payouts.

## 2. Project Objectives

- Store customer and professional information.
- Organize services and service categories.
- Track professional skills and availability.
- Manage customer bookings and reschedules.
- Record service reviews and ratings.
- Maintain professional payout information.
- Support reliable transactional operations.
- Support analytical queries for business reporting.

## 3. Stakeholders

### Customers
Customers search for services, place bookings,
reschedule appointments and provide reviews.

### Service Professionals
Professionals maintain their profiles, skills,
availability and service history.

### Platform Administrators
Administrators manage service categories, services,
professionals and customer-related operations.

### Finance Team
The finance team uses payout and earnings information
to monitor professional payments and commissions.

### Business Analysts
Analysts study booking trends, service demand,
customer behavior and professional performance.

## 4. Customer-Facing and Operational Requirements

The database should support:

- Customer registration and profile management.
- Service and category lookup.
- Professional discovery and availability.
- Booking creation and status tracking.
- Booking rescheduling.
- Review and rating management.
- Professional payout records.

These operations require reliable and consistent
transaction processing.

## 5. Reporting and Analytical Requirements

The database should support analysis of:

- Booking volumes and booking statuses.
- Service and category demand.
- City-wise booking trends.
- Professional ratings and performance.
- Customer activity.
- Cancellation patterns.
- Professional earnings and payouts.
- Payment method distribution.

## 6. Main Entities

The database contains the following 11 entities:

1. Cities
2. Service Categories
3. Services
4. Professionals
5. Professional Skills
6. Professional Availability
7. Customers
8. Bookings
9. Reschedules
10. Reviews
11. Payouts

## 7. Assumptions

- Every customer belongs to one city.
- Every professional belongs to one city.
- Each service belongs to one service category.
- A professional can possess multiple service skills.
- A professional can have availability records for
  multiple work dates.
- A customer can create multiple bookings.
- A booking can have multiple reschedule records.
- A booking can have at most one review.
- A professional can receive multiple payouts.
- A booking may not have an assigned professional yet.
- Some booking timestamps and customer information
  can be NULL when not applicable or unavailable.

## 8. Data Integrity Requirements

- Primary keys uniquely identify records.
- Foreign keys maintain relationships between tables.
- CHECK constraints enforce valid business values.
- UNIQUE constraints prevent duplicate key combinations.
- Nullable fields represent information that is not
  always available at the time of record creation.

## 9. Expected Outcome

The expected outcome is a normalized relational
database that maintains data integrity and supports
the operational and analytical requirements of
the home services platform.
