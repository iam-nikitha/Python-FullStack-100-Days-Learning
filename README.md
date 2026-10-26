# 🚆 Online Railway Reservation System

## 📖 Project Overview
The Online Railway Reservation System is a relational database project developed using MySQL.
This project is designed to manage railway operations such as trains, routes, schedules, coaches, seats, passengers, bookings, payments, cancellations, and refunds.
The database demonstrates the implementation of:

* ER diagram design (first step of the project)
* Table creation
* Primary and foreign keys
* Data insertion
* Relationships between tables
* Indexes, views, triggers, and stored procedures
* SQL queries of different difficulty levels

## ✨ Features

* Proper relational database design with 15 normalized tables
* Use of primary and foreign keys with CHECK and UNIQUE constraints
* Segment-wise seat booking with overlap prevention
* Automatic waitlisting, seat assignment, and refund calculation
* Audit log for booking status changes
* ER Diagram included
* Sample records inserted for testing
* Query categorization based on difficulty level

## 🛠️ Technologies Used

* MySQL 8.0.16+
* SQL

## 🗺️ ER Diagram
The project began with designing the ER (Entity Relationship) Diagram, which identified the entities, attributes, and relationships. The database tables were created from this design.

**ER Diagram Link:** _Add your ER diagram link here_

## 🗄️ Database Tables
The project contains the following tables:

```
railway_reservation_db
├── Users
├── Passengers
├── Stations
├── Trains
├── Train_Routes
├── Train_Schedules
├── Coaches
├── Seats
├── Bookings
├── Booking_Passengers
├── Seat_Allocations
├── Payments
├── Cancellations
├── Refunds
└── Booking_Audit
```

## 🔗 Relationships

* One user can make multiple bookings
* One train can have multiple routes, schedules, and coaches
* One coach can contain multiple seats
* One booking can include multiple passengers
* One booking can have multiple payments
* One cancellation can have refunds linked to payments
* Seat_Allocations connect schedules, seats, and booked passengers for a stop range

## ⚙️ Database Objects

### ⚡ Indexes
Indexes are created on frequently searched and filtered columns of bookings, schedules, payments, stations, passengers, and the audit log. Their purpose is to speed up lookups, filtering, and sorting, so queries run faster as the data grows.

### 👁️ Views
Views provide ready-made reports without rewriting complex joins each time.

* vw_BookingDetails - full booking details, one row per passenger
* vw_TrainRevenue - revenue per train (gross, refunds, and net)
* vw_ScheduleOccupancy - seat occupancy per coach for each schedule
* vw_Waitlist - list of waitlisted passengers
* vw_CancellationReport - summary of cancellations and refunds

### 🔔 Triggers
Triggers enforce business rules and keep data consistent automatically.

* Seat allocation triggers - validate seat allocations and prevent overlapping seat assignments (on insert and update)
* Passenger cancellation trigger - frees the seat when a passenger is cancelled
* Refund triggers - ensure a refund matches a paid payment and the same booking's cancellation (on insert and update)
* Booking triggers - validate the route segment and prevent confirming a booking on a cancelled schedule (on insert and update)
* Audit triggers - record every new booking and every status change in the audit log

### 📦 Stored Procedures
Stored procedures handle the main transactional workflows safely, with validation and rollback on errors.

* sp_CheckAvailability - shows seat availability for a given stop range, so a seat can be reused on non-overlapping segments
* sp_BookTicket - books a ticket, prevents passenger overlap, allocates a seat or waitlists, and records payment
* sp_CancelBooking - cancels a booking, frees seats, calculates the refund, and updates payment status

## 📝 SQL Queries Included (Q1 to Q40)

### 🟢 Easy Level Queries
Queries using:

* SELECT and DISTINCT
* WHERE clause
* Operators (AND, <>, NOT)
* BETWEEN
* IN
* LIKE
* IS NULL / IS NOT NULL
* ORDER BY and LIMIT

### 🟡 Intermediate Level Queries
Queries using:

* Aggregate Functions
* COUNT()
* SUM()
* MIN() and MAX()
* AVG()
* GROUP BY
* HAVING

### 🔴 Hard Level Queries
Queries using:

* INNER JOIN, LEFT JOIN, RIGHT JOIN, and SELF JOIN
* Multi-table joins with GROUP BY
* Subqueries (scalar, IN, NOT EXISTS, derived tables)
* CASE expressions
* String and date functions (CONCAT, DATEDIFF)
* UNION and simulated INTERSECT / EXCEPT

## ▶️ How to Run

1. Install MySQL 8.0.16 or later and open MySQL Workbench.
2. Open the project SQL script.
3. Execute the script from beginning to end.
4. Verify the tables, sample data, views, triggers, and stored procedures.

## 🎓 Learning Outcomes
This project helped in understanding:

* Database normalization
* SQL query writing
* Table relationships
* Aggregate functions
* Joins and relational analysis
* ER diagram design
* Views, triggers, and stored procedures
* Transaction handling and data integrity

## 🔮 Future Scope

* **Full-Stack Integration:** Connect the database to a Node.js backend and a responsive React frontend.
* **Automated Waitlists:** Implement background Cron jobs to auto-promote waitlisted passengers.
* **Cloud Deployment:** Migrate to AWS or Azure using Docker for high availability.
* **Advanced Analytics:** Integrate Power BI or Tableau for live admin dashboards.

## 👩‍💻 Author
K. Nikitha
