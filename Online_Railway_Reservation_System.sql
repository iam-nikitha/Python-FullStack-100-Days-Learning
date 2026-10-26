-- ============================================================================
-- PROJECT     : Online Railway Reservation System
-- DATABASE    : railway_reservation_db
-- RDBMS       : MySQL 8.0.16+
-- ----------------------------------------------------------------------------
-- DESCRIPTION : A comprehensive relational database system engineered to 
--               manage end-to-end railway operations. The architecture 
--               seamlessly handles passenger bookings, seat allocations, 
--               financial transactions (payments and cancellations), and 
--               operational scheduling with strict data integrity.
-- ----------------------------------------------------------------------------
-- ARCHITECTURE COMPONENTS:
--   • Schema        : 15 normalized tables with enforced referential integrity.
--   • Seed Data     : Dummy data for users, trains, routes, and transactions.
--   • Performance   : 10 strategic indexes for optimized query execution.
--   • Reporting     : 5 analytical views for business intelligence.
--   • Automation    : 9 triggers for constraint enforcement & audit logging.
--   • Business Logic: 3 stored procedures for transactional workflows.
-- ============================================================================

DROP DATABASE IF EXISTS railway_reservation_db;
CREATE DATABASE railway_reservation_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE railway_reservation_db;

-- ============================================================================
-- SECTION 1 — TABLES
-- ============================================================================

-- 1. Users — account records for customers
CREATE TABLE Users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    phone         VARCHAR(15)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Passengers — travellers who can be booked on tickets
CREATE TABLE Passengers (
    passenger_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    age          INT NOT NULL,
    gender       ENUM('Male','Female','Other') NOT NULL,
    phone        VARCHAR(15)  NULL,
    email        VARCHAR(100) NULL,
    CONSTRAINT chk_passenger_age CHECK (age BETWEEN 1 AND 120)
);

-- 3. Stations — master list of railway stations
CREATE TABLE Stations (
    station_id   INT AUTO_INCREMENT PRIMARY KEY,
    station_code VARCHAR(10)  NOT NULL UNIQUE,
    station_name VARCHAR(100) NOT NULL,
    city         VARCHAR(100) NOT NULL,
    state        VARCHAR(100) NOT NULL
);

-- 4. Trains — master list of trains
CREATE TABLE Trains (
    train_id     INT AUTO_INCREMENT PRIMARY KEY,
    train_number VARCHAR(10)  NOT NULL UNIQUE,
    train_name   VARCHAR(100) NOT NULL,
    train_type   ENUM('Express','Superfast','Shatabdi','Rajdhani','Other') NOT NULL
);

-- 5. Train_Routes — stop-by-stop schedule for each train
CREATE TABLE Train_Routes (
    route_id             INT AUTO_INCREMENT PRIMARY KEY,
    train_id             INT NOT NULL,
    station_id           INT NOT NULL,
    stop_number          INT NOT NULL,
    arrival_time         TIME NULL,
    departure_time       TIME NULL,
    distance_from_source DECIMAL(8,2) NOT NULL,
    FOREIGN KEY (train_id)   REFERENCES Trains(train_id)     ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (station_id) REFERENCES Stations(station_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (train_id, stop_number),
    UNIQUE (train_id, station_id),
    CONSTRAINT chk_stop_number    CHECK (stop_number > 0),
    CONSTRAINT chk_route_distance CHECK (distance_from_source >= 0)
);

-- 6. Train_Schedules — dated runs of a train
CREATE TABLE Train_Schedules (
    schedule_id        INT AUTO_INCREMENT PRIMARY KEY,
    train_id           INT NOT NULL,
    journey_date       DATE NOT NULL,
    departure_datetime DATETIME NOT NULL,
    arrival_datetime   DATETIME NOT NULL,
    schedule_status    ENUM('On-Time','Delayed','Cancelled') NOT NULL DEFAULT 'On-Time',
    FOREIGN KEY (train_id) REFERENCES Trains(train_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (train_id, journey_date),
    CONSTRAINT chk_schedule_times CHECK (arrival_datetime > departure_datetime)
);

-- 7. Coaches — physical coaches attached to a train
CREATE TABLE Coaches (
    coach_id     INT AUTO_INCREMENT PRIMARY KEY,
    train_id     INT NOT NULL,
    coach_number VARCHAR(10) NOT NULL,
    coach_type   ENUM('Sleeper','AC1','AC2','AC3','Chair Car','General') NOT NULL,
    total_seats  INT NOT NULL,
    FOREIGN KEY (train_id) REFERENCES Trains(train_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (train_id, coach_number),
    CONSTRAINT chk_total_seats CHECK (total_seats > 0)
);

-- 8. Seats — individual seats within a coach
CREATE TABLE Seats (
    seat_id     INT AUTO_INCREMENT PRIMARY KEY,
    coach_id    INT NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    berth_type  ENUM('Lower','Middle','Upper','Side Lower','Side Upper',
                     'Window','Aisle','Seater') NULL,
    FOREIGN KEY (coach_id) REFERENCES Coaches(coach_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (coach_id, seat_number)
);

-- 9. Bookings — main ticket / PNR record
CREATE TABLE Bookings (
    booking_id             INT AUTO_INCREMENT PRIMARY KEY,
    pnr                    VARCHAR(20) NOT NULL UNIQUE,
    user_id                INT NOT NULL,
    schedule_id            INT NOT NULL,
    source_station_id      INT NOT NULL,
    destination_station_id INT NOT NULL,
    booking_date           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_fare             DECIMAL(10,2) NOT NULL,
    booking_status         ENUM('Confirmed','Waitlist','Cancelled') NOT NULL DEFAULT 'Confirmed',
    FOREIGN KEY (user_id)                REFERENCES Users(user_id) ON UPDATE CASCADE,
    FOREIGN KEY (schedule_id)            REFERENCES Train_Schedules(schedule_id) ON UPDATE CASCADE,
    FOREIGN KEY (source_station_id)      REFERENCES Stations(station_id),
    FOREIGN KEY (destination_station_id) REFERENCES Stations(station_id),
    CONSTRAINT chk_total_fare         CHECK (total_fare >= 0),
    CONSTRAINT chk_different_stations CHECK (source_station_id <> destination_station_id)
);

-- 10. Booking_Passengers — links individual passengers to a booking
CREATE TABLE Booking_Passengers (
    booking_passenger_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id           INT NOT NULL,
    passenger_id         INT NOT NULL,
    passenger_fare       DECIMAL(10,2) NOT NULL,
    passenger_status     ENUM('Confirmed','Waitlist','Cancelled') NOT NULL DEFAULT 'Confirmed',
    FOREIGN KEY (booking_id)   REFERENCES Bookings(booking_id)     ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (passenger_id) REFERENCES Passengers(passenger_id) ON UPDATE CASCADE,
    UNIQUE (booking_id, passenger_id),
    CONSTRAINT chk_passenger_fare CHECK (passenger_fare >= 0)
);

-- 11. Seat_Allocations — seat assigned to a passenger for a stop range
CREATE TABLE Seat_Allocations (
    allocation_id        INT AUTO_INCREMENT PRIMARY KEY,
    schedule_id          INT NOT NULL,
    seat_id              INT NOT NULL,
    booking_passenger_id INT NOT NULL,
    source_stop          INT NOT NULL,
    destination_stop     INT NOT NULL,
    allocated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (schedule_id)          REFERENCES Train_Schedules(schedule_id)      ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (seat_id)              REFERENCES Seats(seat_id)                    ON UPDATE CASCADE,
    FOREIGN KEY (booking_passenger_id) REFERENCES Booking_Passengers(booking_passenger_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (schedule_id, seat_id, booking_passenger_id),
    CONSTRAINT chk_allocation_stops
        CHECK (source_stop > 0 AND destination_stop > source_stop)
);

-- 12. Payments — financial transactions per booking
CREATE TABLE Payments (
    payment_id            INT AUTO_INCREMENT PRIMARY KEY,
    booking_id            INT NOT NULL,
    amount                DECIMAL(10,2) NOT NULL,
    payment_method        ENUM('UPI','Card','Net Banking','Wallet','Cash') NOT NULL,
    payment_status        ENUM('Pending','Success','Failed','Refunded') NOT NULL DEFAULT 'Pending',
    transaction_reference VARCHAR(100) NULL UNIQUE,
    payment_date          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount CHECK (amount >= 0)
);

-- 13. Cancellations — cancellation record for a booking
CREATE TABLE Cancellations (
    cancellation_id     INT AUTO_INCREMENT PRIMARY KEY,
    booking_id          INT NOT NULL,
    cancellation_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancellation_reason VARCHAR(255) NULL,
    cancellation_status ENUM('Pending','Processed','Rejected') NOT NULL DEFAULT 'Pending',
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id) ON UPDATE CASCADE
);

-- 14. Refunds — refund linked to a payment and a cancellation
CREATE TABLE Refunds (
    refund_id        INT AUTO_INCREMENT PRIMARY KEY,
    payment_id       INT NOT NULL,
    cancellation_id  INT NOT NULL,
    refund_amount    DECIMAL(10,2) NOT NULL,
    refund_status    ENUM('Pending','Processed','Failed') NOT NULL DEFAULT 'Pending',
    refund_date      DATETIME NULL,
    FOREIGN KEY (payment_id)      REFERENCES Payments(payment_id)         ON UPDATE CASCADE,
    FOREIGN KEY (cancellation_id) REFERENCES Cancellations(cancellation_id) ON UPDATE CASCADE,
    CONSTRAINT chk_refund_amount CHECK (refund_amount >= 0)
);

-- 15. Booking_Audit — history of booking status changes
CREATE TABLE Booking_Audit (
    audit_id    INT AUTO_INCREMENT PRIMARY KEY,
    booking_id  INT NOT NULL,
    old_status  ENUM('Confirmed','Waitlist','Cancelled') NULL,
    new_status  ENUM('Confirmed','Waitlist','Cancelled') NULL,
    action_type ENUM('INSERT','UPDATE') NOT NULL,
    action_note VARCHAR(255) NULL,
    changed_by  VARCHAR(100) DEFAULT (CURRENT_USER()),
    changed_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id) ON DELETE RESTRICT
);

-- ============================================================================
-- SECTION 2 — SAMPLE DATA
-- ============================================================================

INSERT INTO Users (full_name, email, phone, password_hash) VALUES
('Nikitha','nikitha@gmail.com','9000000001','hash_nikitha'),
('Rahul','rahul@gmail.com','9000000002','hash_rahul'),
('Priya','priya@gmail.com','9000000003','hash_priya'),
('Arjun','arjun@gmail.com','9000000004','hash_arjun'),
('Sneha','sneha@gmail.com','9000000005','hash_sneha'),
('Ravi Teja','ravi@gmail.com','9000000006','hash_ravi');

INSERT INTO Passengers (full_name, age, gender, phone, email) VALUES
('Nikitha',22,'Female','9100000001','nikitha@gmail.com'),
('Rahul',25,'Male','9100000002','rahul@gmail.com'),
('Priya',21,'Female','9100000003','priya@gmail.com'),
('Arjun',28,'Male','9100000004','arjun@gmail.com'),
('Sneha',24,'Female','9100000005','sneha@gmail.com'),
('Kiran',35,'Male',NULL,NULL),
('Ananya',19,'Female',NULL,'ananya@gmail.com'),
('Vikram',42,'Male','9100000008',NULL),
('Meena',60,'Female',NULL,NULL),
('Rohit',12,'Male','9100000010',NULL);

INSERT INTO Stations (station_code, station_name, city, state) VALUES
('VSKP','Visakhapatnam','Visakhapatnam','Andhra Pradesh'),
('RJY','Rajahmundry','Rajahmundry','Andhra Pradesh'),
('BZA','Vijayawada Junction','Vijayawada','Andhra Pradesh'),
('GNT','Guntur Junction','Guntur','Andhra Pradesh'),
('SC','Secunderabad Junction','Hyderabad','Telangana'),
('HYB','Hyderabad Deccan','Hyderabad','Telangana'),
('MAS','Chennai Central','Chennai','Tamil Nadu'),
('TPTY','Tirupati','Tirupati','Andhra Pradesh'),
('BNC','Bengaluru Cantt','Bengaluru','Karnataka'),
('MYS','Mysuru Junction','Mysuru','Karnataka');

INSERT INTO Trains (train_number, train_name, train_type) VALUES
('12728','Godavari Express','Express'),
('12718','Ratnachal Express','Superfast'),
('12759','Charminar Express','Superfast'),
('12007','Shatabdi Express','Shatabdi'),
('12805','Janmabhoomi Express','Express');

INSERT INTO Train_Routes
(train_id, station_id, stop_number, arrival_time, departure_time, distance_from_source) VALUES
(1,1,1,NULL,'17:20:00',0),
(1,2,2,'19:00:00','19:05:00',150),
(1,3,3,'21:00:00',NULL,350),
(2,5,1,NULL,'17:30:00',0),
(2,4,2,'19:00:00','19:05:00',100),
(2,3,3,'20:00:00','20:05:00',150),
(2,1,4,'23:00:00',NULL,350),
(3,7,1,NULL,'18:00:00',0),
(3,3,2,'22:00:00','22:05:00',350),
(3,5,3,'06:00:00',NULL,700),
(4,7,1,NULL,'06:00:00',0),
(4,8,2,'10:00:00','10:05:00',140),
(4,9,3,'14:00:00',NULL,360),
(5,9,1,NULL,'18:00:00',0),
(5,10,2,'22:00:00',NULL,450);

-- Seed schedules (ids 1-5) dated 2026-11-01 to 2026-11-05
INSERT INTO Train_Schedules
(train_id, journey_date, departure_datetime, arrival_datetime, schedule_status) VALUES
(1,'2026-11-01','2026-11-01 17:20:00','2026-11-01 21:00:00','On-Time'),
(2,'2026-11-02','2026-11-02 17:30:00','2026-11-02 23:00:00','On-Time'),
(3,'2026-11-03','2026-11-03 18:00:00','2026-11-04 06:00:00','Delayed'),
(4,'2026-11-04','2026-11-04 06:00:00','2026-11-04 14:00:00','On-Time'),
(5,'2026-11-05','2026-11-05 18:00:00','2026-11-05 22:00:00','Cancelled');

-- Future schedules (ids 6-10) dated 2027-06-01 to 2027-06-05
-- These are used by the smoke tests in Section 9
INSERT INTO Train_Schedules
(train_id, journey_date, departure_datetime, arrival_datetime, schedule_status) VALUES
(1,'2027-06-01','2027-06-01 17:20:00','2027-06-01 21:00:00','On-Time'),
(2,'2027-06-02','2027-06-02 17:30:00','2027-06-02 23:00:00','On-Time'),
(3,'2027-06-03','2027-06-03 18:00:00','2027-06-04 06:00:00','On-Time'),
(4,'2027-06-04','2027-06-04 06:00:00','2027-06-04 14:00:00','On-Time'),
(5,'2027-06-05','2027-06-05 18:00:00','2027-06-05 22:00:00','On-Time');

INSERT INTO Coaches (train_id, coach_number, coach_type, total_seats) VALUES
(1,'S1','Sleeper',10),
(1,'B1','AC3',10),
(2,'S1','Sleeper',10),
(2,'B1','AC3',10),
(3,'S1','Sleeper',10),
(3,'A1','AC2',10),
(4,'C1','Chair Car',10),
(4,'B1','AC3',10),
(5,'S1','Sleeper',10),
(5,'C1','Chair Car',10);

-- Generate 10 seats per coach (100 total). The ORDER BY gives each coach a
-- fixed contiguous seat_id range (coach 1 = 1-10, coach 2 = 11-20, ...).
INSERT INTO Seats (coach_id, seat_number, berth_type)
SELECT c.coach_id, CAST(n.seat_no AS CHAR(10)),
    CASE
        WHEN c.coach_type IN ('Chair Car','General') THEN 'Seater'
        WHEN n.seat_no IN (1,4,7,10) THEN 'Lower'
        WHEN n.seat_no IN (2,5,8)    THEN 'Middle'
        ELSE 'Upper'
    END
FROM Coaches c
CROSS JOIN (
    SELECT 1 AS seat_no UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
    UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10
) n
ORDER BY c.coach_id, n.seat_no;

INSERT INTO Bookings
(pnr, user_id, schedule_id, source_station_id, destination_station_id,
 booking_date, total_fare, booking_status) VALUES
('PNR100000001',1,1,1,3,'2026-10-20 10:00:00', 700.00,'Confirmed'),
('PNR100000002',2,2,5,1,'2026-10-20 11:00:00', 900.00,'Confirmed'),
('PNR100000003',3,3,7,5,'2026-10-20 12:00:00',1200.00,'Confirmed'),
('PNR100000004',4,4,7,9,'2026-10-20 13:00:00', 800.00,'Cancelled'),
('PNR100000005',5,5,9,10,'2026-10-20 14:00:00',400.00,'Cancelled');

INSERT INTO Booking_Passengers
(booking_id, passenger_id, passenger_fare, passenger_status) VALUES
(1,1, 700.00,'Confirmed'),
(2,2, 900.00,'Confirmed'),
(3,3,1200.00,'Confirmed'),
(4,4, 800.00,'Cancelled'),
(5,5, 400.00,'Cancelled');

-- Seat allocations are looked up by train / coach / seat number so they
-- remain correct even if the seed order changes.
INSERT INTO Seat_Allocations
(schedule_id, seat_id, booking_passenger_id, source_stop, destination_stop)
SELECT 1, s.seat_id, 1, 1, 3 FROM Seats s
JOIN Coaches c ON s.coach_id = c.coach_id
JOIN Trains  t ON c.train_id = t.train_id
WHERE t.train_number='12728' AND c.coach_number='S1' AND s.seat_number='1';

INSERT INTO Seat_Allocations
(schedule_id, seat_id, booking_passenger_id, source_stop, destination_stop)
SELECT 2, s.seat_id, 2, 1, 4 FROM Seats s
JOIN Coaches c ON s.coach_id = c.coach_id
JOIN Trains  t ON c.train_id = t.train_id
WHERE t.train_number='12718' AND c.coach_number='S1' AND s.seat_number='1';

INSERT INTO Seat_Allocations
(schedule_id, seat_id, booking_passenger_id, source_stop, destination_stop)
SELECT 3, s.seat_id, 3, 1, 3 FROM Seats s
JOIN Coaches c ON s.coach_id = c.coach_id
JOIN Trains  t ON c.train_id = t.train_id
WHERE t.train_number='12759' AND c.coach_number='S1' AND s.seat_number='1';

INSERT INTO Payments
(booking_id, amount, payment_method, payment_status, transaction_reference, payment_date) VALUES
(1, 700.00,'UPI','Success','TXN1001','2026-10-20 10:05:00'),
(2, 900.00,'Card','Success','TXN1002','2026-10-20 11:05:00'),
(3,1200.00,'Net Banking','Success','TXN1003','2026-10-20 12:05:00'),
(4, 800.00,'UPI','Refunded','TXN1004','2026-10-20 13:05:00'),
(5, 400.00,'Card','Refunded','TXN1005','2026-10-20 14:05:00');

INSERT INTO Cancellations
(booking_id, cancellation_date, cancellation_reason, cancellation_status) VALUES
(4,'2026-10-22 11:30:00','Change in travel plan','Processed'),
(5,'2026-10-22 12:00:00','Train service cancelled','Processed');

INSERT INTO Refunds
(payment_id, cancellation_id, refund_amount, refund_status, refund_date) VALUES
(4,1,800.00,'Processed','2026-10-22 12:00:00'),
(5,2,400.00,'Processed','2026-10-22 12:30:00');

-- ============================================================================
-- SECTION 3 — INDEXES
-- ============================================================================

CREATE INDEX idx_bookings_date     ON Bookings(booking_date);
CREATE INDEX idx_bookings_status   ON Bookings(booking_status);
CREATE INDEX idx_schedules_date    ON Train_Schedules(journey_date);
CREATE INDEX idx_schedules_status  ON Train_Schedules(schedule_status);
CREATE INDEX idx_payments_status   ON Payments(payment_status);
CREATE INDEX idx_stations_name     ON Stations(station_name);
CREATE INDEX idx_stations_city     ON Stations(city);
CREATE INDEX idx_passengers_name   ON Passengers(full_name);
CREATE INDEX idx_audit_booking     ON Booking_Audit(booking_id);
CREATE INDEX idx_audit_time        ON Booking_Audit(changed_at);

-- ============================================================================
-- SECTION 4 — VIEWS
-- ============================================================================

-- Full booking details — one row per passenger
CREATE VIEW vw_BookingDetails AS
SELECT
    b.booking_id, b.pnr,
    u.full_name AS booked_by, u.email AS user_email,
    t.train_number, t.train_name, ts.journey_date,
    src.station_name  AS source_station,
    dest.station_name AS destination_station,
    p.passenger_id, p.full_name AS passenger_name, p.age AS passenger_age,
    bp.passenger_fare, bp.passenger_status,
    c.coach_number, s.seat_number,
    b.total_fare, b.booking_status, b.booking_date,
    pay.payment_status, pay.total_paid
FROM Bookings b
JOIN Users u                    ON b.user_id = u.user_id
JOIN Train_Schedules ts         ON b.schedule_id = ts.schedule_id
JOIN Trains t                   ON ts.train_id = t.train_id
JOIN Stations src               ON b.source_station_id = src.station_id
JOIN Stations dest              ON b.destination_station_id = dest.station_id
LEFT JOIN Booking_Passengers bp ON b.booking_id = bp.booking_id
LEFT JOIN Passengers p          ON bp.passenger_id = p.passenger_id
LEFT JOIN Seat_Allocations sa   ON bp.booking_passenger_id = sa.booking_passenger_id
LEFT JOIN Seats s               ON sa.seat_id = s.seat_id
LEFT JOIN Coaches c             ON s.coach_id = c.coach_id
LEFT JOIN (
    SELECT booking_id,
           GROUP_CONCAT(DISTINCT payment_status ORDER BY payment_status) AS payment_status,
           SUM(CASE WHEN payment_status IN ('Success','Refunded')
                    THEN amount ELSE 0 END) AS total_paid
    FROM Payments GROUP BY booking_id
) pay ON b.booking_id = pay.booking_id;

-- Revenue per train (gross, refunds, net)
CREATE VIEW vw_TrainRevenue AS
SELECT
    t.train_id, t.train_number, t.train_name, t.train_type,
    COALESCE(bk.total_bookings, 0) AS total_bookings,
    COALESCE(pay.gross_revenue, 0) AS gross_revenue,
    COALESCE(rf.refund_total, 0)   AS refund_total,
    COALESCE(pay.gross_revenue, 0) - COALESCE(rf.refund_total, 0) AS net_revenue
FROM Trains t
LEFT JOIN (
    SELECT ts.train_id, COUNT(DISTINCT b.booking_id) AS total_bookings
    FROM Bookings b JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    GROUP BY ts.train_id
) bk ON t.train_id = bk.train_id
LEFT JOIN (
    SELECT ts.train_id, SUM(p.amount) AS gross_revenue
    FROM Payments p JOIN Bookings b ON p.booking_id = b.booking_id
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    WHERE p.payment_status IN ('Success','Refunded')
    GROUP BY ts.train_id
) pay ON t.train_id = pay.train_id
LEFT JOIN (
    SELECT ts.train_id, SUM(r.refund_amount) AS refund_total
    FROM Refunds r
    JOIN Cancellations can ON r.cancellation_id = can.cancellation_id
    JOIN Bookings b ON can.booking_id = b.booking_id
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    WHERE r.refund_status = 'Processed'
    GROUP BY ts.train_id
) rf ON t.train_id = rf.train_id;

-- Schedule-level occupancy per coach. For a segment-aware check use
-- the sp_CheckAvailability procedure.
CREATE VIEW vw_ScheduleOccupancy AS
SELECT
    ts.schedule_id, ts.journey_date,
    t.train_number, t.train_name,
    c.coach_number, c.coach_type,
    COUNT(DISTINCT s.seat_id) AS total_seats,
    COUNT(DISTINCT sa.seat_id) AS occupied_seats,
    COUNT(DISTINCT s.seat_id) - COUNT(DISTINCT sa.seat_id) AS free_seats
FROM Train_Schedules ts
JOIN Trains  t ON ts.train_id = t.train_id
JOIN Coaches c ON t.train_id = c.train_id
LEFT JOIN Seats s             ON c.coach_id = s.coach_id
LEFT JOIN Seat_Allocations sa ON s.seat_id = sa.seat_id AND sa.schedule_id = ts.schedule_id
GROUP BY ts.schedule_id, ts.journey_date, t.train_number, t.train_name,
         c.coach_number, c.coach_type;

-- Waitlisted passengers
CREATE VIEW vw_Waitlist AS
SELECT
    b.booking_id, b.pnr,
    t.train_number, t.train_name, ts.journey_date,
    p.passenger_id, p.full_name AS passenger_name,
    bp.passenger_fare, bp.passenger_status, b.booking_status
FROM Booking_Passengers bp
JOIN Bookings b         ON bp.booking_id = b.booking_id
JOIN Passengers p       ON bp.passenger_id = p.passenger_id
JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
JOIN Trains t           ON ts.train_id = t.train_id
WHERE bp.passenger_status = 'Waitlist';

-- Cancellation and refund summary
CREATE VIEW vw_CancellationReport AS
SELECT
    can.cancellation_id, b.pnr, u.full_name AS booked_by,
    t.train_number, t.train_name, ts.journey_date,
    can.cancellation_date, can.cancellation_reason, can.cancellation_status,
    COALESCE(r.refund_total, 0) AS refund_total,
    r.refund_status_summary     AS refund_status
FROM Cancellations can
JOIN Bookings b         ON can.booking_id = b.booking_id
JOIN Users u            ON b.user_id = u.user_id
JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
JOIN Trains t           ON ts.train_id = t.train_id
LEFT JOIN (
    SELECT cancellation_id,
           SUM(CASE WHEN refund_status = 'Processed' THEN refund_amount ELSE 0 END) AS refund_total,
           GROUP_CONCAT(DISTINCT refund_status ORDER BY refund_status) AS refund_status_summary
    FROM Refunds GROUP BY cancellation_id
) r ON can.cancellation_id = r.cancellation_id;

-- ============================================================================
-- SECTION 5 — TRIGGERS
-- ============================================================================

DELIMITER //

-- Validates seat allocations and prevents overlapping assignments
CREATE TRIGGER trg_Allocation_Insert
BEFORE INSERT ON Seat_Allocations
FOR EACH ROW
BEGIN
    DECLARE v_book_src_stop INT DEFAULT NULL;
    DECLARE v_book_dst_stop INT DEFAULT NULL;

    IF NEW.source_stop < 1 OR NEW.destination_stop <= NEW.source_stop THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid stop range';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Seats s
        JOIN Coaches c ON s.coach_id = c.coach_id
        JOIN Train_Schedules ts ON ts.train_id = c.train_id
        WHERE s.seat_id = NEW.seat_id AND ts.schedule_id = NEW.schedule_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Seat does not belong to this schedule''s train';
    END IF;

    SELECT r1.stop_number, r2.stop_number
      INTO v_book_src_stop, v_book_dst_stop
    FROM Booking_Passengers bp
    JOIN Bookings b ON bp.booking_id = b.booking_id
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    JOIN Train_Routes r1 ON r1.train_id = ts.train_id AND r1.station_id = b.source_station_id
    JOIN Train_Routes r2 ON r2.train_id = ts.train_id AND r2.station_id = b.destination_station_id
    WHERE bp.booking_passenger_id = NEW.booking_passenger_id
      AND b.schedule_id = NEW.schedule_id;

    IF v_book_src_stop IS NULL OR v_book_dst_stop IS NULL
       OR v_book_src_stop <> NEW.source_stop
       OR v_book_dst_stop <> NEW.destination_stop THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Allocation stops must match booking segment';
    END IF;

    IF EXISTS (
        SELECT 1 FROM Seat_Allocations sa
        JOIN Booking_Passengers bp ON sa.booking_passenger_id = bp.booking_passenger_id
        WHERE sa.schedule_id = NEW.schedule_id
          AND sa.seat_id = NEW.seat_id
          AND bp.passenger_status <> 'Cancelled'
          AND NEW.source_stop      < sa.destination_stop
          AND NEW.destination_stop >  sa.source_stop
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Seat already allocated for overlapping segment';
    END IF;
END //

-- Same rules as above, applied to updates
CREATE TRIGGER trg_Allocation_Update
BEFORE UPDATE ON Seat_Allocations
FOR EACH ROW
BEGIN
    DECLARE v_book_src_stop INT DEFAULT NULL;
    DECLARE v_book_dst_stop INT DEFAULT NULL;

    IF NEW.source_stop < 1 OR NEW.destination_stop <= NEW.source_stop THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid stop range';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Seats s
        JOIN Coaches c ON s.coach_id = c.coach_id
        JOIN Train_Schedules ts ON ts.train_id = c.train_id
        WHERE s.seat_id = NEW.seat_id AND ts.schedule_id = NEW.schedule_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Seat does not belong to this schedule''s train';
    END IF;

    SELECT r1.stop_number, r2.stop_number
      INTO v_book_src_stop, v_book_dst_stop
    FROM Booking_Passengers bp
    JOIN Bookings b ON bp.booking_id = b.booking_id
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    JOIN Train_Routes r1 ON r1.train_id = ts.train_id AND r1.station_id = b.source_station_id
    JOIN Train_Routes r2 ON r2.train_id = ts.train_id AND r2.station_id = b.destination_station_id
    WHERE bp.booking_passenger_id = NEW.booking_passenger_id
      AND b.schedule_id = NEW.schedule_id;

    IF v_book_src_stop IS NULL OR v_book_dst_stop IS NULL
       OR v_book_src_stop <> NEW.source_stop
       OR v_book_dst_stop <> NEW.destination_stop THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Allocation stops must match booking segment';
    END IF;

    IF EXISTS (
        SELECT 1 FROM Seat_Allocations sa
        JOIN Booking_Passengers bp ON sa.booking_passenger_id = bp.booking_passenger_id
        WHERE sa.schedule_id = NEW.schedule_id
          AND sa.seat_id = NEW.seat_id
          AND sa.allocation_id <> OLD.allocation_id
          AND bp.passenger_status <> 'Cancelled'
          AND NEW.source_stop      < sa.destination_stop
          AND NEW.destination_stop >  sa.source_stop
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Seat already allocated for overlapping segment';
    END IF;
END //

-- Frees the seat when a passenger is cancelled
CREATE TRIGGER trg_BP_Cancelled_Cleanup
AFTER UPDATE ON Booking_Passengers
FOR EACH ROW
BEGIN
    IF NEW.passenger_status = 'Cancelled' AND OLD.passenger_status <> 'Cancelled' THEN
        DELETE FROM Seat_Allocations
        WHERE booking_passenger_id = NEW.booking_passenger_id;
    END IF;
END //

-- Refund must match a paid payment and the same booking's cancellation
CREATE TRIGGER trg_Refund_Insert
BEFORE INSERT ON Refunds
FOR EACH ROW
BEGIN
    DECLARE v_pay_booking INT DEFAULT NULL;
    DECLARE v_can_booking INT DEFAULT NULL;
    DECLARE v_pay_amount  DECIMAL(10,2) DEFAULT 0;
    DECLARE v_already     DECIMAL(10,2) DEFAULT 0;

    SELECT b.booking_id, p.amount INTO v_pay_booking, v_pay_amount
    FROM Payments p JOIN Bookings b ON p.booking_id = b.booking_id
    WHERE p.payment_id = NEW.payment_id AND p.payment_status IN ('Success','Refunded');

    SELECT booking_id INTO v_can_booking FROM Cancellations
    WHERE cancellation_id = NEW.cancellation_id;

    IF v_pay_booking IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment not found or not Success/Refunded';
    END IF;
    IF v_can_booking IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cancellation not found';
    END IF;
    IF v_pay_booking <> v_can_booking THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Refund must link same-booking payment and cancellation';
    END IF;

    SELECT COALESCE(SUM(refund_amount), 0) INTO v_already
    FROM Refunds
    WHERE payment_id = NEW.payment_id AND refund_status IN ('Processed','Pending');

    IF v_already + NEW.refund_amount > v_pay_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Total refunds would exceed the payment amount';
    END IF;
END //

-- Same checks as above, applied to updates
CREATE TRIGGER trg_Refund_Update
BEFORE UPDATE ON Refunds
FOR EACH ROW
BEGIN
    DECLARE v_pay_booking INT DEFAULT NULL;
    DECLARE v_can_booking INT DEFAULT NULL;
    DECLARE v_pay_amount  DECIMAL(10,2) DEFAULT 0;
    DECLARE v_already     DECIMAL(10,2) DEFAULT 0;

    SELECT b.booking_id, p.amount INTO v_pay_booking, v_pay_amount
    FROM Payments p JOIN Bookings b ON p.booking_id = b.booking_id
    WHERE p.payment_id = NEW.payment_id AND p.payment_status IN ('Success','Refunded');

    SELECT booking_id INTO v_can_booking FROM Cancellations
    WHERE cancellation_id = NEW.cancellation_id;

    IF v_pay_booking IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment not found or not Success/Refunded';
    END IF;
    IF v_can_booking IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cancellation not found';
    END IF;
    IF v_pay_booking <> v_can_booking THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Refund must link same-booking payment and cancellation';
    END IF;

    SELECT COALESCE(SUM(refund_amount), 0) INTO v_already
    FROM Refunds
    WHERE payment_id = NEW.payment_id
      AND refund_id <> OLD.refund_id
      AND refund_status IN ('Processed','Pending');

    IF v_already + NEW.refund_amount > v_pay_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Total refunds would exceed the payment amount';
    END IF;
END //

-- Validates route segment and prevents confirming on a cancelled schedule
CREATE TRIGGER trg_Booking_Insert
BEFORE INSERT ON Bookings
FOR EACH ROW
BEGIN
    DECLARE v_src_stop INT DEFAULT NULL;
    DECLARE v_dst_stop INT DEFAULT NULL;
    DECLARE v_status   VARCHAR(20) DEFAULT NULL;

    SELECT schedule_status INTO v_status FROM Train_Schedules
    WHERE schedule_id = NEW.schedule_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule not found';
    END IF;
    IF v_status = 'Cancelled' AND NEW.booking_status = 'Confirmed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot confirm a booking on a Cancelled schedule';
    END IF;

    SELECT r1.stop_number, r2.stop_number INTO v_src_stop, v_dst_stop
    FROM Train_Schedules ts
    JOIN Train_Routes r1 ON r1.train_id = ts.train_id AND r1.station_id = NEW.source_station_id
    JOIN Train_Routes r2 ON r2.train_id = ts.train_id AND r2.station_id = NEW.destination_station_id
    WHERE ts.schedule_id = NEW.schedule_id;

    IF v_src_stop IS NULL OR v_dst_stop IS NULL OR v_src_stop >= v_dst_stop THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source and destination are not a valid segment of this schedule';
    END IF;
END //

-- Same rules as above, applied to updates
CREATE TRIGGER trg_Booking_Update
BEFORE UPDATE ON Bookings
FOR EACH ROW
BEGIN
    DECLARE v_src_stop INT DEFAULT NULL;
    DECLARE v_dst_stop INT DEFAULT NULL;
    DECLARE v_status   VARCHAR(20) DEFAULT NULL;

    SELECT schedule_status INTO v_status FROM Train_Schedules
    WHERE schedule_id = NEW.schedule_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule not found';
    END IF;
    IF v_status = 'Cancelled' AND NEW.booking_status = 'Confirmed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot confirm a booking on a Cancelled schedule';
    END IF;

    SELECT r1.stop_number, r2.stop_number INTO v_src_stop, v_dst_stop
    FROM Train_Schedules ts
    JOIN Train_Routes r1 ON r1.train_id = ts.train_id AND r1.station_id = NEW.source_station_id
    JOIN Train_Routes r2 ON r2.train_id = ts.train_id AND r2.station_id = NEW.destination_station_id
    WHERE ts.schedule_id = NEW.schedule_id;

    IF v_src_stop IS NULL OR v_dst_stop IS NULL OR v_src_stop >= v_dst_stop THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source and destination are not a valid segment of this schedule';
    END IF;
END //

-- Records every new booking in the audit log
CREATE TRIGGER trg_Booking_Audit_Insert
AFTER INSERT ON Bookings
FOR EACH ROW
BEGIN
    INSERT INTO Booking_Audit
        (booking_id, old_status, new_status, action_type, action_note)
    VALUES (NEW.booking_id, NULL, NEW.booking_status, 'INSERT', 'New booking created');
END //

-- Records every status change in the audit log
CREATE TRIGGER trg_Booking_Audit_Update
AFTER UPDATE ON Bookings
FOR EACH ROW
BEGIN
    IF OLD.booking_status <> NEW.booking_status THEN
        INSERT INTO Booking_Audit
            (booking_id, old_status, new_status, action_type, action_note)
        VALUES (NEW.booking_id, OLD.booking_status, NEW.booking_status, 'UPDATE',
                CONCAT('Status changed from ', OLD.booking_status,
                       ' to ', NEW.booking_status));
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 6 — STORED PROCEDURES
-- ============================================================================

DELIMITER //

-- ============================================================================
-- 1. sp_CheckAvailability
-- Returns segment-aware seat availability for a specific schedule and coach.
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_CheckAvailability //
CREATE PROCEDURE sp_CheckAvailability(
    IN p_schedule_id INT,
    IN p_source_stop INT,
    IN p_dest_stop   INT,
    IN p_coach_type  VARCHAR(20)
)
BEGIN
    DECLARE v_train_id INT DEFAULT NULL;

    SELECT train_id INTO v_train_id FROM Train_Schedules
    WHERE schedule_id = p_schedule_id;

    IF v_train_id IS NULL THEN
        SELECT 'INVALID_SCHEDULE' AS status, 0 AS available_seats;
    ELSEIF p_source_stop < 1 OR p_dest_stop <= p_source_stop THEN
        SELECT 'INVALID_STOPS' AS status, 0 AS available_seats;
    ELSE
        SELECT
            c.coach_number, c.coach_type,
            COUNT(DISTINCT s.seat_id) AS total_seats,
            COUNT(DISTINCT s.seat_id)
                - COUNT(DISTINCT CASE WHEN sa.allocation_id IS NOT NULL THEN sa.seat_id END)
                AS available_seats,
            COUNT(DISTINCT CASE WHEN sa.allocation_id IS NOT NULL THEN sa.seat_id END)
                AS occupied_for_segment
        FROM Coaches c
        JOIN Seats s ON c.coach_id = s.coach_id
        LEFT JOIN Seat_Allocations sa
               ON sa.seat_id = s.seat_id
              AND sa.schedule_id = p_schedule_id
              AND p_source_stop < sa.destination_stop
              AND p_dest_stop   > sa.source_stop
        WHERE c.train_id = v_train_id AND c.coach_type = p_coach_type
        GROUP BY c.coach_id, c.coach_number, c.coach_type;
    END IF;
END //


-- ============================================================================
-- 2. sp_BookTicket
-- Books a ticket: validates inputs, locks schedule (with recheck), prevents 
-- passenger overlaps, allocates a seat (or waitlists), and records payment.
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_BookTicket //
CREATE PROCEDURE sp_BookTicket(
    IN  p_user_id      INT,
    IN  p_schedule_id  INT,
    IN  p_source_stn   INT,
    IN  p_dest_stn     INT,
    IN  p_passenger_id INT,
    IN  p_coach_type   VARCHAR(20),
    IN  p_fare         DECIMAL(10,2),
    OUT p_pnr          VARCHAR(20),
    OUT p_status       VARCHAR(20)
)
main: BEGIN
    DECLARE v_train_id      INT DEFAULT NULL;
    DECLARE v_sched_status  VARCHAR(20) DEFAULT NULL;
    DECLARE v_departure     DATETIME DEFAULT NULL;
    DECLARE v_src_stop      INT DEFAULT NULL;
    DECLARE v_dst_stop      INT DEFAULT NULL;
    DECLARE v_seat_id       INT DEFAULT NULL;
    DECLARE v_booking_id    INT DEFAULT NULL;
    DECLARE v_bp_id         INT DEFAULT NULL;
    DECLARE v_lock          INT DEFAULT NULL;
    DECLARE v_user_exists   INT DEFAULT 0;
    DECLARE v_pax_exists    INT DEFAULT 0;
    DECLARE v_pay_status    VARCHAR(20) DEFAULT 'Pending';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_pnr = NULL;
    SET p_status = NULL;

    IF p_fare IS NULL OR p_fare <= 0 THEN
        SET p_status = 'INVALID_FARE'; LEAVE main;
    END IF;

    SELECT COUNT(*) INTO v_user_exists FROM Users WHERE user_id = p_user_id;
    IF v_user_exists = 0 THEN SET p_status = 'INVALID_USER'; LEAVE main; END IF;

    SELECT COUNT(*) INTO v_pax_exists FROM Passengers WHERE passenger_id = p_passenger_id;
    IF v_pax_exists = 0 THEN SET p_status = 'INVALID_PASSENGER'; LEAVE main; END IF;

    SELECT train_id, schedule_status, departure_datetime
      INTO v_train_id, v_sched_status, v_departure
    FROM Train_Schedules WHERE schedule_id = p_schedule_id;

    IF v_train_id IS NULL THEN SET p_status = 'INVALID_SCHEDULE'; LEAVE main; END IF;
    IF v_sched_status = 'Cancelled' THEN SET p_status = 'SCHEDULE_CANCELLED'; LEAVE main; END IF;
    IF v_departure <= NOW() THEN SET p_status = 'TRAIN_DEPARTED'; LEAVE main; END IF;

    SELECT r1.stop_number, r2.stop_number INTO v_src_stop, v_dst_stop
    FROM Train_Routes r1
    JOIN Train_Routes r2 ON r1.train_id = r2.train_id
    WHERE r1.train_id   = v_train_id
      AND r1.station_id = p_source_stn
      AND r2.station_id = p_dest_stn;

    IF v_src_stop IS NULL OR v_dst_stop IS NULL OR v_src_stop >= v_dst_stop THEN
        SET p_status = 'INVALID_ROUTE'; LEAVE main;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Coaches
        WHERE train_id = v_train_id AND coach_type = p_coach_type
    ) THEN
        SET p_status = 'CLASS_NOT_AVAILABLE'; LEAVE main;
    END IF;

    START TRANSACTION;

    -- Lock the row AND fetch status + departure time together
    SELECT schedule_id, schedule_status, departure_datetime 
    INTO v_lock, v_sched_status, v_departure 
    FROM Train_Schedules
    WHERE schedule_id = p_schedule_id FOR UPDATE;

    -- Recheck schedule status after the lock
    IF v_sched_status = 'Cancelled' THEN
        ROLLBACK;
        SET p_status = 'SCHEDULE_CANCELLED';
        LEAVE main;
    END IF;

    -- Recheck departure time after the lock
    IF v_departure <= NOW() THEN
        ROLLBACK;
        SET p_status = 'TRAIN_DEPARTED';
        LEAVE main;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM Booking_Passengers bp
        JOIN Bookings b        ON bp.booking_id = b.booking_id
        JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
        JOIN Train_Routes r1   ON r1.train_id = ts.train_id
                              AND r1.station_id = b.source_station_id
        JOIN Train_Routes r2   ON r2.train_id = ts.train_id
                              AND r2.station_id = b.destination_station_id
        WHERE bp.passenger_id = p_passenger_id
          AND b.schedule_id = p_schedule_id
          AND bp.passenger_status <> 'Cancelled'
          AND v_src_stop < r2.stop_number
          AND v_dst_stop > r1.stop_number
    ) THEN
        ROLLBACK;
        SET p_status = 'PASSENGER_OVERLAP';
        LEAVE main;
    END IF;

    SELECT MIN(s.seat_id) INTO v_seat_id
    FROM Seats s
    JOIN Coaches c ON s.coach_id = c.coach_id
    WHERE c.train_id = v_train_id AND c.coach_type = p_coach_type
      AND NOT EXISTS (
          SELECT 1 FROM Seat_Allocations sa
          JOIN Booking_Passengers bp2 ON sa.booking_passenger_id = bp2.booking_passenger_id
          WHERE sa.schedule_id = p_schedule_id
            AND sa.seat_id = s.seat_id
            AND bp2.passenger_status <> 'Cancelled'
            AND v_src_stop < sa.destination_stop
            AND v_dst_stop > sa.source_stop
      );

    IF v_seat_id IS NOT NULL THEN
        SET p_status = 'Confirmed';
        SET v_pay_status = 'Success';
    ELSE
        SET p_status = 'Waitlist';
        SET v_pay_status = 'Pending';
    END IF;

    SET p_pnr = CONCAT('TMP', LEFT(REPLACE(UUID(), '-', ''), 17));

    INSERT INTO Bookings
        (pnr, user_id, schedule_id, source_station_id, destination_station_id,
         total_fare, booking_status)
    VALUES
        (p_pnr, p_user_id, p_schedule_id, p_source_stn, p_dest_stn,
         p_fare, p_status);
    SET v_booking_id = LAST_INSERT_ID();

    SET p_pnr = CONCAT('PNR', LPAD(v_booking_id + 100000000, 9, '0'));
    UPDATE Bookings SET pnr = p_pnr WHERE booking_id = v_booking_id;

    INSERT INTO Booking_Passengers
        (booking_id, passenger_id, passenger_fare, passenger_status)
    VALUES (v_booking_id, p_passenger_id, p_fare, p_status);
    SET v_bp_id = LAST_INSERT_ID();

    IF v_seat_id IS NOT NULL THEN
        INSERT INTO Seat_Allocations
            (schedule_id, seat_id, booking_passenger_id, source_stop, destination_stop)
        VALUES (p_schedule_id, v_seat_id, v_bp_id, v_src_stop, v_dst_stop);
    END IF;

    INSERT INTO Payments
        (booking_id, amount, payment_method, payment_status, transaction_reference)
    VALUES (v_booking_id, p_fare, 'UPI', v_pay_status,
            CONCAT('TXN', REPLACE(UUID(), '-', '')));

    COMMIT;
END //


-- ============================================================================
-- 3. sp_CancelBooking
-- Cancels a booking: locks the row, checks departure time, frees seats, 
-- calculates refunds, and updates payment statuses.
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_CancelBooking //
CREATE PROCEDURE sp_CancelBooking(
    IN p_pnr    VARCHAR(20),
    IN p_reason VARCHAR(255)
)
main: BEGIN
    DECLARE v_booking_id   INT DEFAULT NULL;
    DECLARE v_status       VARCHAR(20) DEFAULT NULL;
    DECLARE v_sched_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_departure    DATETIME DEFAULT NULL;
    DECLARE v_total_fare   DECIMAL(10,2) DEFAULT 0;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_payment_id   INT DEFAULT NULL;
    DECLARE v_cancel_id    INT DEFAULT NULL;
    DECLARE v_charge       DECIMAL(10,2) DEFAULT 0;
    DECLARE v_refund       DECIMAL(10,2) DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT b.booking_id, b.booking_status, ts.schedule_status, ts.departure_datetime
      INTO v_booking_id, v_status, v_sched_status, v_departure
    FROM Bookings b
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    WHERE b.pnr = p_pnr FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK; SELECT 'PNR not found' AS result; LEAVE main;
    END IF;

    IF v_status = 'Cancelled' THEN
        ROLLBACK; SELECT 'Already cancelled' AS result; LEAVE main;
    END IF;

    IF v_departure <= NOW() THEN
        ROLLBACK;
        SELECT 'TRAIN_DEPARTED — cancellation not allowed' AS result;
        LEAVE main;
    END IF;

    SELECT COUNT(*), COALESCE(SUM(passenger_fare), 0)
      INTO v_active_count, v_total_fare
    FROM Booking_Passengers
    WHERE booking_id = v_booking_id AND passenger_status <> 'Cancelled';

    IF v_active_count = 0 THEN
        ROLLBACK;
        SELECT 'No active passengers to cancel' AS result;
        LEAVE main;
    END IF;

    SELECT payment_id INTO v_payment_id FROM Payments
    WHERE booking_id = v_booking_id AND payment_status = 'Success'
    LIMIT 1;

    INSERT INTO Cancellations (booking_id, cancellation_reason, cancellation_status)
    VALUES (v_booking_id, p_reason, 'Processed');
    SET v_cancel_id = LAST_INSERT_ID();

    DELETE sa FROM Seat_Allocations sa
    JOIN Booking_Passengers bp ON sa.booking_passenger_id = bp.booking_passenger_id
    WHERE bp.booking_id = v_booking_id;

    UPDATE Booking_Passengers SET passenger_status = 'Cancelled'
    WHERE booking_id = v_booking_id AND passenger_status <> 'Cancelled';

    IF v_payment_id IS NULL THEN
        -- Waitlist / unpaid booking: no money collected, nothing to refund
        SET v_charge = 0;
        SET v_refund = 0;
        UPDATE Payments SET payment_status = 'Failed'
        WHERE booking_id = v_booking_id AND payment_status = 'Pending';
    ELSE
        SET v_charge = IF(v_sched_status = 'Cancelled',
                          0,
                          ROUND(v_total_fare * 0.10, 2));
        SET v_refund = GREATEST(v_total_fare - v_charge, 0);

        INSERT INTO Refunds
            (payment_id, cancellation_id, refund_amount, refund_status, refund_date)
        VALUES
            (v_payment_id, v_cancel_id, v_refund, 'Processed', NOW());

        UPDATE Payments SET payment_status = 'Refunded'
        WHERE payment_id = v_payment_id;
    END IF;

    UPDATE Bookings SET booking_status = 'Cancelled'
    WHERE booking_id = v_booking_id;

    COMMIT;
    SELECT CONCAT('Cancelled. Fare: ', v_total_fare,
                  ', Charge: ', v_charge,
                  ', Refund: ', v_refund) AS result;
END //

DELIMITER ;
-- ============================================================================
-- SECTION 7: SYSTEM VERIFICATION AND DATA INTEGRITY AUDIT
-- ============================================================================

-- Row counts for every table
SELECT 'Users'             AS table_name, COUNT(*) AS total FROM Users
UNION ALL SELECT 'Passengers',           COUNT(*) FROM Passengers
UNION ALL SELECT 'Stations',             COUNT(*) FROM Stations
UNION ALL SELECT 'Trains',               COUNT(*) FROM Trains
UNION ALL SELECT 'Train_Routes',         COUNT(*) FROM Train_Routes
UNION ALL SELECT 'Train_Schedules',      COUNT(*) FROM Train_Schedules
UNION ALL SELECT 'Coaches',              COUNT(*) FROM Coaches
UNION ALL SELECT 'Seats',                COUNT(*) FROM Seats
UNION ALL SELECT 'Bookings',             COUNT(*) FROM Bookings
UNION ALL SELECT 'Booking_Passengers',   COUNT(*) FROM Booking_Passengers
UNION ALL SELECT 'Seat_Allocations',     COUNT(*) FROM Seat_Allocations
UNION ALL SELECT 'Payments',             COUNT(*) FROM Payments
UNION ALL SELECT 'Cancellations',        COUNT(*) FROM Cancellations
UNION ALL SELECT 'Refunds',              COUNT(*) FROM Refunds
UNION ALL SELECT 'Booking_Audit',        COUNT(*) FROM Booking_Audit;

SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'railway_reservation_db';
SELECT 'vw_BookingDetails'      AS view_name, COUNT(*) AS records_returned FROM vw_BookingDetails
UNION ALL SELECT 'vw_TrainRevenue',        COUNT(*) FROM vw_TrainRevenue
UNION ALL SELECT 'vw_ScheduleOccupancy',   COUNT(*) FROM vw_ScheduleOccupancy
UNION ALL SELECT 'vw_Waitlist',            COUNT(*) FROM vw_Waitlist
UNION ALL SELECT 'vw_CancellationReport',  COUNT(*) FROM vw_CancellationReport;

-- 1. Check Booking Details (Expect 5 rows)
SELECT * FROM vw_BookingDetails;

-- 2. Check Train Revenue (Expect 5 rows)
SELECT * FROM vw_TrainRevenue;

-- 3. Check Schedule Occupancy (Expect 20 rows)
SELECT * FROM vw_ScheduleOccupancy;

-- 4. Check Waitlist (Expect 0 rows)
SELECT * FROM vw_Waitlist;

-- 5. Check Cancellation Report (Expect 2 rows)
SELECT * FROM vw_CancellationReport;

-- ============================================================================
-- SECTION 8: TRANSACTIONAL BUSINESS LOGIC VALIDATION (STORED PROCEDURES)
-- ============================================================================

-- TEST 1: Availability BEFORE Booking
-- PURPOSE: Establish a baseline. Prove sp_CheckAvailability works on a fresh train.
-- EXPECTED: 10 total seats, 10 available, 0 occupied.
CALL sp_CheckAvailability(6, 1, 3, 'Sleeper');

-- TEST 2: Normal Booking
-- PURPOSE: Prove sp_BookTicket works. It should find a free seat, create a PNR,
--          set the booking to 'Confirmed', and record a 'Success' payment.
-- EXPECTED: PNR100000006 | Confirmed

CALL sp_BookTicket(1, 6, 1, 3, 7, 'Sleeper', 300.00, @pnr, @st);
SELECT @pnr AS pnr, @st AS status;

-- TEST 3: Availability AFTER Booking
-- PURPOSE: Prove the seat was actually reserved in the database.
-- EXPECTED: 10 total seats, 9 available, 1 occupied.

CALL sp_CheckAvailability(6, 1, 3, 'Sleeper');

-- TEST 4: Passenger Overlap Prevention 
-- PURPOSE: Prove a single person cannot book overlapping seats on the same train.
--          Passenger 7 already has a ticket from stop 1 to 3. If they try to 
--          book stop 2 to 3, it must be blocked. 
-- EXPECTED: NULL | PASSENGER_OVERLAP
CALL sp_BookTicket(1, 6, 2, 3, 7, 'Sleeper', 300.00, @pnr3, @st3);
SELECT @pnr3 AS pnr3, @st3 AS status3;

-- Test 5: cancel the original booking
-- PURPOSE: Prove sp_CancelBooking works. It must free the seat, calculate a 
--          10% cancellation charge, and issue a 90% refund.
-- EXPECTED: Cancelled. Fare: 300.00, Charge: 30.00, Refund: 270.00
CALL sp_CancelBooking(@pnr, 'Test cancellation');

-- TEST 6: Reject Invalid Fare
-- PURPOSE: Prove the system prevents "free" tickets. (Proves FIX 1).
-- EXPECTED: NULL | INVALID_FARE
CALL sp_BookTicket(1, 6, 1, 3, 7, 'Sleeper', 0.00, @pnr2, @st2);
SELECT @pnr2 AS pnr2, @st2 AS status2;

-- TEST 7: Reject Departed Train
-- PURPOSE: Prove the system blocks bookings for trains that have already left.
--          We insert a fake schedule from Jan 2026 (in the past) to test this.
-- EXPECTED: NULL | TRAIN_DEPARTED
INSERT INTO Train_Schedules
(train_id, journey_date, departure_datetime, arrival_datetime, schedule_status) VALUES
(1,'2026-01-01','2026-01-01 17:20:00','2026-01-01 21:00:00','On-Time');
SET @past_sched = LAST_INSERT_ID();
CALL sp_BookTicket(1, @past_sched, 1, 3, 7, 'Sleeper', 300.00, @pnr4, @st4);
SELECT @pnr4 AS pnr4, @st4 AS status4;
/*
-- ============================================================================
-- SECTION 9: CONSTRAINT ENFORCEMENT AND TRIGGER VALIDATION (NEGATIVE TESTING)
-- ============================================================================
-- ----------------------------------------------------------------------------
-- TEST 1: trg_Allocation_Insert (Prevents seat double-booking on INSERT)
-- Try to insert a new seat allocation that overlaps with an existing one.
-- EXPECTED: ERROR 1644 (Seat already allocated for overlapping segment)
-- ----------------------------------------------------------------------------
INSERT INTO Seat_Allocations (schedule_id, seat_id, booking_passenger_id, source_stop, destination_stop) 
VALUES (1, 1, 2, 1, 3);
-- ----------------------------------------------------------------------------
-- TEST 2: trg_Allocation_Update (Prevents seat double-booking on UPDATE)
-- Try to change an existing allocation so it overlaps with another passenger.
-- EXPECTED: ERROR 1644 (Seat already allocated for overlapping segment)
-- ----------------------------------------------------------------------------
UPDATE Seat_Allocations 
SET schedule_id = 1, seat_id = 1, source_stop = 1, destination_stop = 3
WHERE allocation_id = 2;

-- ----------------------------------------------------------------------------
-- TEST 3: trg_Refund_Insert (Prevents over-refunding on INSERT)
-- Try to refund 9999.00 for a payment that was only 700.00.
-- EXPECTED: ERROR 1644 (Total refunds would exceed the payment amount)
-- ----------------------------------------------------------------------------
INSERT INTO Refunds (payment_id, cancellation_id, refund_amount, refund_status) 
VALUES (1, 1, 9999.00, 'Pending');

-- ----------------------------------------------------------------------------
-- TEST 4: trg_Refund_Update (Prevents over-refunding on UPDATE)
-- Try to edit an existing valid refund to be higher than the original payment.
-- EXPECTED: ERROR 1644 (Total refunds would exceed the payment amount)
-- ----------------------------------------------------------------------------
UPDATE Refunds 
SET refund_amount = 9999.00 
WHERE refund_id = 1;

-- ----------------------------------------------------------------------------
-- TEST 5: trg_Booking_Insert (Prevents invalid routes on INSERT)
-- Try to book Schedule 1 (Train 1) using Station 7, which is not on Train 1's route.
-- EXPECTED: ERROR 1644 (Source and destination are not a valid segment...)
-- ----------------------------------------------------------------------------
INSERT INTO Bookings (pnr, user_id, schedule_id, source_station_id, destination_station_id, total_fare, booking_status) 
VALUES ('FAKE1', 1, 1, 1, 7, 500, 'Confirmed');

-- ----------------------------------------------------------------------------
-- TEST 6: trg_Booking_Update (Prevents invalid routes on UPDATE)
-- Try to change a valid booking's destination to a station not on the train.
-- EXPECTED: ERROR 1644 (Source and destination are not a valid segment...)
-- ----------------------------------------------------------------------------
UPDATE Bookings 
SET destination_station_id = 10 
WHERE booking_id = 1;

-- ----------------------------------------------------------------------------
-- TEST 7: trg_BP_Cancelled_Cleanup (Auto-frees seat when passenger cancels)
-- We will cancel a passenger and check if their seat is deleted, then ROLLBACK.
-- EXPECTED: Output shows '0' (seat was automatically deleted by the trigger).
-- ----------------------------------------------------------------------------
START TRANSACTION;
UPDATE Booking_Passengers SET passenger_status = 'Cancelled' WHERE booking_passenger_id = 1;
SELECT COUNT(*) AS seat_allocations_left FROM Seat_Allocations WHERE booking_passenger_id = 1;
ROLLBACK;

-- ----------------------------------------------------------------------------
-- TEST 8 & 9: trg_Booking_Audit_Insert & trg_Booking_Audit_Update (Audit Log)
-- We will insert a booking, update its status, and check the audit log.
-- EXPECTED: Output shows 2 rows (one INSERT, one UPDATE). Then we ROLLBACK.
-- ----------------------------------------------------------------------------
START TRANSACTION;

INSERT INTO Bookings (pnr, user_id, schedule_id, source_station_id, destination_station_id, total_fare, booking_status)
VALUES ('AUDIT_TEST', 1, 1, 1, 3, 500, 'Confirmed');

UPDATE Bookings SET booking_status = 'Cancelled' WHERE pnr = 'AUDIT_TEST';

SELECT action_type, old_status, new_status 
FROM Booking_Audit 
WHERE booking_id = (SELECT booking_id FROM Bookings WHERE pnr = 'AUDIT_TEST');

ROLLBACK;
 
*/
USE railway_reservation_db;

-- ============================================================================
-- Section10: BASIC RETRIEVAL, FILTERING, AND SORTING
-- ============================================================================

-- ==========================================================
-- PART 1: BASIC SELECT & DISTINCT
-- ==========================================================

-- Q1. Retrieve all records from the Passengers table.
SELECT * FROM Passengers;

-- Q2. Retrieve a list of unique train types available in the system.
SELECT DISTINCT train_type FROM Trains;


-- ==========================================================
-- PART 2: THE WHERE CLAUSE (COMPARISON & LOGICAL OPERATORS)
-- ==========================================================

-- Q3. Retrieve all male passengers who are older than 30. (Using AND, >)
SELECT passenger_id, full_name, age, gender 
FROM Passengers 
WHERE age > 30 AND gender = 'Male';

-- Q4. Retrieve all booking passengers who are NOT cancelled. (Using <>)
SELECT booking_passenger_id, booking_id, passenger_fare 
FROM Booking_Passengers 
WHERE passenger_status <> 'Cancelled';

-- Q5. Retrieve refunds that are NOT pending. (Using NOT)
SELECT refund_id, payment_id, refund_amount, refund_status 
FROM Refunds 
WHERE NOT refund_status = 'Pending';


-- ==========================================================
-- PART 3: RANGE, LIST, AND PATTERN MATCHING
-- ==========================================================

-- Q6. Retrieve all payments where the amount is between 500 and 1000 (inclusive). (Using BETWEEN)
SELECT payment_id, amount, payment_method 
FROM Payments 
WHERE amount BETWEEN 500 AND 1000;

-- Q7. Retrieve all trains whose type is either 'Shatabdi' or 'Superfast'. (Using IN)
SELECT train_number, train_name 
FROM Trains 
WHERE train_type IN ('Shatabdi', 'Superfast');

-- Q8. Retrieve all users whose email ends with '@gmail.com'. (Using LIKE)
SELECT full_name, email 
FROM Users 
WHERE email LIKE '%@gmail.com';

-- Q9. Retrieve all passengers who do not have a phone number registered. (Using IS NULL)
SELECT passenger_id, full_name 
FROM Passengers 
WHERE phone IS NULL;

-- Q10. Retrieve all train routes where an arrival time is recorded. (Using IS NOT NULL)
SELECT route_id, train_id, station_id, stop_number, arrival_time 
FROM Train_Routes 
WHERE arrival_time IS NOT NULL;


-- ==========================================================
-- PART 4: SORTING & LIMITING (ORDER BY & LIMIT)
-- ==========================================================

-- Q11. Retrieve all schedules ordered by journey_date from newest to oldest.
SELECT schedule_id, train_id, journey_date, schedule_status 
FROM Train_Schedules 
ORDER BY journey_date DESC;

-- Q12. Retrieve the top 3 longest route segments (by distance_from_source).
SELECT train_id, stop_number, distance_from_source 
FROM Train_Routes 
ORDER BY distance_from_source DESC 
LIMIT 3;


-- ============================================================================
-- Section11: AGGREGATIONS WITH WHERE, GROUP BY, HAVING
-- ============================================================================

-- Q13. Count the total number of confirmed bookings.
SELECT COUNT(*) AS confirmed_bookings 
FROM Bookings 
WHERE booking_status = 'Confirmed';

-- Q14. Find the total revenue collected across all successful payments.
SELECT SUM(amount) AS total_revenue 
FROM Payments 
WHERE payment_status = 'Success';

-- Q15. Find the cheapest and most expensive booking fares.
SELECT MIN(total_fare) AS cheapest, MAX(total_fare) AS most_expensive 
FROM Bookings;

-- Q16. Count how many bookings exist for each booking status.
SELECT booking_status, COUNT(*) AS total_bookings 
FROM Bookings 
GROUP BY booking_status;

-- Q17. Calculate total revenue collected per payment method (successful only).
SELECT payment_method, SUM(amount) AS total_collected 
FROM Payments 
WHERE payment_status = 'Success'
GROUP BY payment_method;

-- Q18. Group coaches by type, finding total seats, only for coaches with 10+ seats.
SELECT coach_type, SUM(total_seats) AS total_seats_available 
FROM Coaches 
WHERE total_seats >= 10
GROUP BY coach_type;

-- Q19. Find payment methods where the total collection exceeds 800.
SELECT payment_method, SUM(amount) AS total_collected 
FROM Payments 
WHERE payment_status = 'Success'
GROUP BY payment_method 
HAVING SUM(amount) > 800;

-- Q20. Group train routes by train_id, showing only trains with average segment > 200km.
SELECT train_id, AVG(distance_from_source) AS avg_segment 
FROM Train_Routes 
GROUP BY train_id 
HAVING AVG(distance_from_source) > 200;


-- ============================================================================
-- Section12: JOINS (COMBINING TABLES)
-- ============================================================================

-- Q21. Retrieve the PNR and the user's full name. (INNER JOIN)
SELECT b.pnr, u.full_name AS booked_by
FROM Bookings b
INNER JOIN Users u ON b.user_id = u.user_id;

-- Q22. Retrieve the PNR, train name, and journey date. (3-Table INNER JOIN)
SELECT b.pnr, t.train_name, ts.journey_date
FROM Bookings b
INNER JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
INNER JOIN Trains t ON ts.train_id = t.train_id;

-- Q23. Show passenger name, train, coach, seat number, and PNR. (Multi-Table JOIN)
SELECT 
    p.full_name AS passenger_name, 
    t.train_name,
    c.coach_number,
    s.seat_number, 
    b.pnr
FROM Seat_Allocations sa
INNER JOIN Seats s ON sa.seat_id = s.seat_id
INNER JOIN Coaches c ON s.coach_id = c.coach_id          
INNER JOIN Trains t ON c.train_id = t.train_id           
INNER JOIN Booking_Passengers bp ON sa.booking_passenger_id = bp.booking_passenger_id
INNER JOIN Passengers p ON bp.passenger_id = p.passenger_id
INNER JOIN Bookings b ON bp.booking_id = b.booking_id;

-- Q24. List all users and their PNRs, including users who have never booked. (LEFT JOIN)
SELECT u.full_name, b.pnr
FROM Users u
LEFT JOIN Bookings b ON u.user_id = b.user_id;

-- Q25. List all stations and their route IDs, including stations not on any route. (RIGHT JOIN)
SELECT s.station_name, tr.route_id
FROM Train_Routes tr
RIGHT JOIN Stations s ON tr.station_id = s.station_id;

-- Q26. Find pairs of stations located in the exact same city. (SELF JOIN)
SELECT s1.station_name AS station_1, s2.station_name AS station_2, s1.city
FROM Stations s1
INNER JOIN Stations s2 ON s1.city = s2.city AND s1.station_id < s2.station_id;

-- Q27. Find total revenue collected per train from successful payments. (JOIN + GROUP BY)
SELECT t.train_name, SUM(p.amount) AS total_revenue
FROM Trains t
INNER JOIN Train_Schedules ts ON t.train_id = ts.train_id
INNER JOIN Bookings b ON ts.schedule_id = b.schedule_id
INNER JOIN Payments p ON b.booking_id = p.booking_id
WHERE p.payment_status = 'Success'
GROUP BY t.train_name;

-- Q28. Find total refund amount issued per cancellation reason. (JOIN + GROUP BY)
SELECT c.cancellation_reason, SUM(r.refund_amount) AS total_refunded
FROM Cancellations c
INNER JOIN Refunds r ON c.cancellation_id = r.cancellation_id
WHERE c.cancellation_status = 'Processed'
GROUP BY c.cancellation_reason;


-- ============================================================================
-- Section13: ADVANCED CONCEPTS (SUBQUERIES, CASE, STRING FUNCTIONS, SETS)
-- ============================================================================

-- Q29. Find bookings where the fare is greater than the average fare. (Scalar Subquery)
SELECT pnr, total_fare FROM Bookings 
WHERE total_fare > (SELECT AVG(total_fare) FROM Bookings);

-- Q30. Find users who have at least one cancelled booking. (IN Subquery)
SELECT full_name FROM Users 
WHERE user_id IN (SELECT user_id FROM Bookings WHERE booking_status = 'Cancelled');

-- Q31. Find users who have NEVER made a booking. (NOT EXISTS)
SELECT u.full_name FROM Users u 
WHERE NOT EXISTS (SELECT 1 FROM Bookings b WHERE b.user_id = u.user_id);

-- Q32. Find the second-highest booking fare. (Subquery with MAX)
SELECT MAX(total_fare) AS second_highest 
FROM Bookings 
WHERE total_fare < (SELECT MAX(total_fare) FROM Bookings);

-- Q33. Use a Derived Table to find train types with an average fare > 500. (Subquery in FROM)
SELECT train_type, avg_fare FROM (
    SELECT t.train_type, AVG(b.total_fare) AS avg_fare
    FROM Bookings b 
    JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id
    JOIN Trains t ON ts.train_id = t.train_id 
    GROUP BY t.train_type
) AS TrainSummary 
WHERE avg_fare > 500;

-- Q34. Classify bookings as 'Premium' (>=1000), 'Standard' (>=500), or 'Budget'. (CASE)
SELECT pnr, total_fare,
    CASE 
        WHEN total_fare >= 1000 THEN 'Premium'
        WHEN total_fare >= 500 THEN 'Standard'
        ELSE 'Budget'
    END AS fare_category
FROM Bookings;

-- Q35. Group passengers into age brackets (Minor, Adult, Senior). (CASE in GROUP BY)
SELECT 
    CASE 
        WHEN age < 18 THEN 'Minor'
        WHEN age BETWEEN 18 AND 60 THEN 'Adult'
        ELSE 'Senior'
    END AS age_group,
    COUNT(*) AS total_passengers
FROM Passengers
GROUP BY age_group;

-- Q36. Generate a formatted travel route string (e.g. 'Source to Destination'). (CONCAT)
SELECT CONCAT(src.station_name, ' to ', dest.station_name) AS travel_route, b.total_fare
FROM Bookings b
JOIN Stations src ON b.source_station_id = src.station_id
JOIN Stations dest ON b.destination_station_id = dest.station_id;

-- Q37. Find how many days in advance passengers booked their tickets. (DATEDIFF)
SELECT b.pnr, b.booking_date, ts.journey_date, 
       DATEDIFF(ts.journey_date, DATE(b.booking_date)) AS days_in_advance
FROM Bookings b
JOIN Train_Schedules ts ON b.schedule_id = ts.schedule_id;

-- Q38. Combine all names from Users and Passengers, removing duplicates. (UNION)
SELECT full_name FROM Users
UNION
SELECT full_name FROM Passengers;

-- Q39. Find names that exist in BOTH Users and Passengers. (Simulating INTERSECT)
SELECT full_name FROM Users 
WHERE full_name IN (SELECT full_name FROM Passengers);

-- Q40. Find passengers who are NOT registered as users. (Simulating EXCEPT)
SELECT full_name FROM Passengers 
WHERE full_name NOT IN (SELECT full_name FROM Users);






