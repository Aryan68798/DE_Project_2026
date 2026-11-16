
-- Urban Company DBMS Project
-- Team: T0074 | Section: E
-- Database: urban_company_db
-- PostgreSQL 16.16
-- Phase 2: Schema creation
-- No performance-tuning indexes are created in this phase.

CREATE SCHEMA IF NOT EXISTS uc;
SET search_path TO uc;

-- 1. Cities
CREATE TABLE cities (
    city_id INTEGER PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL
);

-- 2. Service categories
CREATE TABLE service_categories (
    category_id INTEGER PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

-- 3. Services
CREATE TABLE services (
    service_id INTEGER PRIMARY KEY,
    category_id INTEGER NOT NULL
        REFERENCES service_categories(category_id),
    service_name VARCHAR(150) NOT NULL,
    duration_min INTEGER NOT NULL CHECK (duration_min > 0),
    base_price NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
    is_active BOOLEAN NOT NULL
);

-- 4. Professionals
CREATE TABLE professionals (
    pro_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    city_id INTEGER NOT NULL REFERENCES cities(city_id),
    gender CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
    joined_on DATE NOT NULL,
    rating NUMERIC(3,2)
        CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    kyc_verified BOOLEAN NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'OFFBOARDED'))
);

-- 5. Professional skills
CREATE TABLE pro_skills (
    pro_id INTEGER NOT NULL REFERENCES professionals(pro_id),
    category_id INTEGER NOT NULL
        REFERENCES service_categories(category_id),
    certified_on DATE NOT NULL,
    PRIMARY KEY (pro_id, category_id)
);

-- 6. Professional availability
CREATE TABLE pro_availability (
    pro_id INTEGER NOT NULL REFERENCES professionals(pro_id),
    work_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    PRIMARY KEY (pro_id, work_date),
    CHECK (end_time > start_time)
);

-- 7. Customers
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    city_id INTEGER NOT NULL REFERENCES cities(city_id),
    plus_valid_until DATE,
    created_at TIMESTAMPTZ NOT NULL
);

-- 8. Bookings
CREATE TABLE bookings (
    booking_id BIGINT PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    service_id INTEGER NOT NULL REFERENCES services(service_id),
    pro_id INTEGER REFERENCES professionals(pro_id),
    city_id INTEGER NOT NULL REFERENCES cities(city_id),
    pincode VARCHAR(10) NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL,
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL CHECK (
        status IN (
            'COMPLETED',
            'NO_SHOW',
            'CANCELLED_BY_PRO',
            'CANCELLED_BY_CUSTOMER',
            'ASSIGNED',
            'REQUESTED',
            'IN_PROGRESS'
        )
    ),
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    discount NUMERIC(10,2) NOT NULL CHECK (discount >= 0),
    cancellation_fee NUMERIC(10,2) NOT NULL
        CHECK (cancellation_fee >= 0),
    tip NUMERIC(10,2) CHECK (tip IS NULL OR tip >= 0),
    payment_method VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('UPI', 'CASH', 'CARD', 'WALLET')),
    CHECK (scheduled_end > scheduled_start),
    CHECK (discount <= price)
);

-- 9. Reschedules
CREATE TABLE reschedules (
    reschedule_id INTEGER PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES bookings(booking_id),
    old_start TIMESTAMPTZ NOT NULL,
    new_start TIMESTAMPTZ NOT NULL,
    requested_by VARCHAR(20) NOT NULL
        CHECK (requested_by IN ('CUSTOMER', 'PRO')),
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

-- 10. Reviews
CREATE TABLE reviews (
    booking_id BIGINT PRIMARY KEY REFERENCES bookings(booking_id),
    rating_for_pro SMALLINT
        CHECK (rating_for_pro IS NULL OR rating_for_pro BETWEEN 1 AND 5),
    comment TEXT,
    rating_for_customer SMALLINT
        CHECK (
            rating_for_customer IS NULL
            OR rating_for_customer BETWEEN 1 AND 5
        ),
    created_at TIMESTAMPTZ NOT NULL
);

-- 11. Payouts
CREATE TABLE payouts (
    payout_id BIGINT PRIMARY KEY,
    pro_id INTEGER NOT NULL REFERENCES professionals(pro_id),
    week_start DATE NOT NULL,
    jobs INTEGER NOT NULL CHECK (jobs >= 0),
    gross_earnings NUMERIC(12,2) NOT NULL CHECK (gross_earnings >= 0),
    commission NUMERIC(12,2) NOT NULL CHECK (commission >= 0),
    net_payout NUMERIC(12,2) NOT NULL CHECK (net_payout >= 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('PAID', 'PENDING')),
    paid_at TIMESTAMPTZ,
    UNIQUE (pro_id, week_start),
    CHECK (EXTRACT(ISODOW FROM week_start) = 1),
    CHECK (net_payout = gross_earnings - commission)
);
