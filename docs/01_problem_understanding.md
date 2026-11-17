# Urban Company Home Services: Problem Understanding

## 1. Problem statement

Urban Company coordinates home-service bookings between customers and trained professionals across multiple cities. The supplied data export covers service categories and services, professional skills and daily availability, customers, bookings, reschedules, reviews, and weekly payouts. The project brief identifies slow customer-app, partner-app, dispatch, support, quality, finance, and planning workloads, alongside expected booking growth. The database project therefore reconstructs a constrained PostgreSQL schema from the exports and supports the specified operational and analytical workload.

## 2. Project objectives

- Represent the supplied data in the 11 relations defined by the project schema.
- Enforce identifiers, relationships, and the domain and value checks supported by the schema and data.
- Support booking and service operations as well as partner, quality, finance, and planning analysis.
- Preserve query results while later project phases measure and improve execution time and assess scalability.

## 3. Stakeholders and requirements

| Problem | Stakeholder and need | Workload class |
|---|---|---|
| P1: Service menu and slot picker | Customers need service information and dispatch needs skill, availability, and conflicting-job information for slot selection. | Customer-facing / real-time |
| P2: My bookings, booking details, phone lookups | Customers and support need responsive booking history, details, and customer lookups. | Customer-facing / real-time |
| P3: Today's jobs, weekly earnings, job completion | Service professionals (partners) need timely job and earnings information and completion updates. | Customer-facing / real-time |
| P4: Unassigned jobs approaching start time | Dispatch and operations need to identify jobs needing assignment promptly. | Customer-facing / real-time |
| P5: Professionals with no customer cancellations | Partner success needs a useful partner-rewards list; the brief reports the current result is always empty. | Reporting / analytics |
| P6: Late starts, no-shows, low ratings, complaints, unskilled jobs | Quality needs timely service-quality and compliance reports. | Reporting / analytics |
| P7: Payouts, Plus savings, cancellation fees, GMV | Finance and the UC Plus team need financial and membership-related reports. | Reporting / analytics |
| P8: Reschedules, demand heat-map, pincodes, retention, utilisation, city report; 20× booking growth | Operations and city-expansion stakeholders need planning reports that remain useful as data volume grows. | Reporting / analytics |

## 4. Customer-facing and operational requirements

The customer and support workloads include browsing services, checking candidate slots, retrieving bookings and booking details, and finding customer records by phone. Partner and dispatch workloads include viewing a professional's jobs and earnings, completing jobs, and finding unassigned bookings due to start. Slot selection must be able to use service/category, professional skill, availability, and bookings to assess a candidate; the brief does not define the precise assignment or clash-resolution policy.

## 5. Reporting and analytical requirements

The specified reports concern partner rewards and cancellations; late starts, no-shows, ratings, complaints, and skill suitability; payouts, Plus discounts/savings, cancellation fees, and gross merchandise value (GMV); and reschedules, demand by location, pincode coverage, customer retention, professional utilisation, and city-level activity. The schema contains fields relevant to these subjects, but does not by itself define every report's calculation or business metric.

## 6. Main entities and responsibilities

The schema's 11 tables are: `cities` (service locations); `service_categories` (service groupings); `services` (bookable offerings, duration, and base price); `professionals` (partner profile, city, status, and rating); `pro_skills` (professional-to-category certification); `pro_availability` (professional working hours by date); `customers` (customer profile and Plus-validity date); `bookings` (customer request, service, location, schedule, status, and charges); `reschedules` (booking schedule changes and requester/reason); `reviews` (ratings/comments associated with a booking); and `payouts` (weekly professional earnings, commission, and payment status).

## 7. Business assumptions

- The supplied CSV exports are the source of the modeled attributes and values; the brief describes their coverage as 10 cities, 10 categories, 60 services, 2,500 professionals, 5,000 skill records, 70,407 availability records, 40,000 customers, 150,000 bookings, 5,391 reschedules, 76,539 reviews, and 27,015 payouts.
- Identifiers in the schema identify records as declared. The schema declares one review per booking, one availability record per professional and work date, and one payout per professional and week.
- `plus_valid_until` is modeled as a date; the schema does not define eligibility or the formula for Plus savings. Similarly, no pricing, cancellation, dispatch, review-eligibility, or payout-calculation policy is inferred beyond explicit schema checks and exported fields.
- The project brief says that availability is published per working day and that professionals may be skilled in one or more categories. The schema's particular key and column structure are recorded as implementation choices, not proof of additional business rules.

## 8. Data integrity requirements

Each entity needs its declared primary key; foreign keys must connect services, professionals, customers, bookings, reschedules, reviews, skills, availability, and payouts to existing related records. Required attributes must be non-null, while fields declared optional (such as contact email, ratings, event timestamps, comments, and tip) may be null. The schema restricts status, gender, payment method, and reschedule requester values; checks positive service duration, rating and non-negative monetary/count ranges, valid schedule ordering, discount not exceeding price, Monday payout week starts, and payout arithmetic; and enforces the declared composite and alternate unique keys. These are database constraints, not assumptions about unmodeled policies.

## 9. Expected database outcomes

The outcome is a PostgreSQL representation of the supplied exports with traceable entity relationships and enforceable constraints. It should provide a sound basis for the specified operational queries and reports, and for later baseline timing, optimization, and growth testing. Performance improvements must preserve the results of the required workload; this problem-understanding phase does not claim that such performance targets have already been met.