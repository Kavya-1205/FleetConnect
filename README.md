# 🚗 FleetConnect

### Smart Fleet Management & Vehicle Operations Platform

FleetConnect is a full-stack fleet management application designed to digitize and streamline day-to-day vehicle and driver operations.

The application provides dedicated **Driver** and **Admin** workflows for managing trips, attendance, fuel, repairs, issues, assets, vehicles, routes, and fleet allocations through a centralized system.

---

## ✨ Features

### 👨‍✈️ Driver Module

* 🔐 Role-based login
* 👤 Driver profile & session management
* 🕐 Punch-In / Punch-Out attendance
* 🚗 Assigned vehicle, route & shift viewing
* 🛣️ Trip start & trip completion
* 📏 Start / End ODO tracking
* ⛽ Fuel entry management
* 💳 Automatic fuel-card lookup
* 📷 Fuel receipt image upload
* ⚠️ Vehicle issue & observation reporting
* 🛠️ Repair logging
* 📦 Vehicle asset tracking
* 💾 Active trip persistence using local storage

### 🛡️ Admin Module

* 📊 Fleet operations dashboard
* 👨‍✈️ Driver management
* 🚗 Vehicle management
* 🗺️ Route management
* 💳 Fuel card management
* 📋 Trip allocation
* 🕐 Driver attendance monitoring
* 📈 Fleet statistics
* 📦 Asset tracking
* 📑 Operational reports
* 📥 Excel (`.xlsx`) export
* ✏️ Add / Edit / Delete records
* 🔄 Data refresh and live dashboard updates

---

## 🏗️ System Architecture

```text
                    ┌──────────────────────┐
                    │   Flutter Mobile App │
                    │       (Dart)         │
                    └──────────┬───────────┘
                               │
                               │ REST API / HTTP
                               ▼
                    ┌──────────────────────┐
                    │ Node.js + Express.js │
                    │      Backend API     │
                    └──────────┬───────────┘
                               │
                               │ SQL Queries
                               ▼
                    ┌──────────────────────┐
                    │      PostgreSQL      │
                    │       Database       │
                    └──────────────────────┘
```

The Flutter application communicates with the backend through centralized REST API methods in `ApiService`.

---

## 🧰 Tech Stack

| Layer                | Technology        |
| -------------------- | ----------------- |
| Mobile Frontend      | Flutter           |
| Programming Language | Dart              |
| Backend              | Node.js           |
| API Framework        | Express.js        |
| Database             | PostgreSQL        |
| API Communication    | REST API / HTTP   |
| Local Persistence    | SharedPreferences |
| Image Handling       | Image Picker      |
| Reports              | Excel / XLSX      |
| File Sharing         | Share Plus        |
| Version Control      | Git & GitHub      |
| Backend Deployment   | Render            |

---

## 📱 Application Workflow

```text
                    Login
                      │
             ┌────────┴────────┐
             ▼                 ▼
          Driver              Admin
             │                 │
             ▼                 ▼
       Driver Dashboard   Admin Dashboard
             │                 │
      ┌──────┼──────┐    ┌─────┼──────────────┐
      ▼      ▼      ▼    ▼     ▼      ▼       ▼
 Attendance  Trip   Fuel  Drivers Vehicles Routes
      │      │      │    │     │      │       │
      ▼      ▼      ▼    └─────┴──────┴───────┘
   Issues  Repairs Assets          │
                                   ▼
                            Trip Allocation
                                   │
                                   ▼
                             Reports / XLSX
```

---

## 🔐 Authentication

FleetConnect provides separate login flows for **Driver** and **Admin** users.

The login request sends:

```json
{
  "emp_id": "EMP001",
  "password": "********",
  "role": "driver"
}
```

After successful authentication, the application stores session information locally and redirects the user according to their role.

---

## 🛣️ Trip Management

The trip module manages the complete trip lifecycle.

### Trip Allocation

Admin assigns:

* Driver
* Vehicle
* Route
* Shift

### Trip Start

Driver provides the starting ODO reading and starts the trip.

```text
Driver
  ↓
Select / Receive Assignment
  ↓
Enter Start ODO
  ↓
Start Trip
  ↓
Trip ID Generated
  ↓
Active Trip
```

### Trip Completion

```text
Active Trip
    ↓
Enter End ODO
    ↓
End Trip
    ↓
Trip Completed
```

Active trip information is persisted locally so the application can restore the trip state when required.

---

## 🕐 Attendance Management

Drivers can digitally record their daily attendance using:

* Punch-In
* Punch-Out
* Live clock
* Shift status
* Total working hours

The backend maintains attendance records with driver ID, date, punch-in and punch-out timestamps.

---

## ⛽ Fuel Management

FleetConnect supports fuel logging for both active and non-active trips.

### Fuel Details

* Fuel type
* Litres filled
* Amount
* Fuel card
* Vehicle
* Trip
* Receipt image

The fuel card can be automatically loaded based on the selected vehicle.

Receipt images can be captured through the camera or selected from the gallery and submitted with the fuel entry.

---

## ⚠️ Issue & Observation Reporting

Drivers can report vehicle issues directly from the application.

Information includes:

* Vehicle VIN
* Date
* ODO reading
* Issue description

The backend stores these records for further fleet and maintenance tracking.

---

## 🛠️ Repair Management

Repair history can be recorded with:

* Vehicle
* Service date
* Requested by
* Performed by
* ODO reading
* Repair details
* Notes
* Part replacement
* Part removal / refit
* Software flashing

This creates a structured maintenance history for vehicles.

---

## 📦 Asset Tracking

FleetConnect tracks vehicle-related hardware and accessories.

### Supported Categories

* Dashcam Fixation
* Datalogger Fixation
* Fuel Card Assignment
* TC Plate Allocation
* Puncture Repair Kit
* Emergency Kit Assignment
* Sandbag Allocation

Each asset record can contain vehicle, asset number, requester, installer, installation date and ODO information.

---

## 🛡️ Admin Dashboard

The Admin dashboard provides a centralized view of fleet operations.

It displays information such as:

* Active Drivers
* Active Vehicles
* Active Trips
* Trip Allocations
* Routes
* Fuel Cards

Administrators can navigate to individual management modules and perform CRUD operations.

---

## 📊 Management Modules

```text
Admin Dashboard
│
├── 👥 Admins
├── 👨‍✈️ Drivers
├── 🚗 Vehicles
├── 🗺️ Routes
├── 💳 Fuel Cards
├── 📋 Trip Allocations
├── 📊 Driver Interface / Reports
└── 📦 Asset Tracking
```

---

## 📥 Excel Report Export

The Admin module supports exporting operational data to `.xlsx` files.

The application generates Excel sheets containing structured records and uses `share_plus` to allow the generated file to be shared or saved.

---

## 🔌 REST API

The backend exposes REST endpoints for different fleet operations.

### Examples

```text
POST   /login

GET    /vehicles
POST   /vehicles
PUT    /vehicles/:id
DELETE /vehicles/:id

GET    /routes
POST   /routes
PUT    /routes/:id
DELETE /routes/:id

POST   /start-trip
POST   /end-trip

POST   /fuel-entries

POST   /issues

POST   /repairs

POST   /assets
DELETE /assets/:id

GET    /trips/all
GET    /fuel/all
GET    /issues/all
GET    /repairs/all
```

API calls are centralized inside the Flutter `ApiService` class, keeping the UI layer separated from backend communication.

---

## 🗄️ Database

PostgreSQL is used as the application's relational database.

Major data areas include:

```text
Users
  │
  ├── Drivers
  └── Admins

Vehicles
  │
  ├── Trips
  ├── Fuel Entries
  ├── Repairs
  ├── Issues
  └── Assets

Routes
  │
  └── Trip Allocations

Fuel Cards
  │
  └── Vehicles

Attendance
  │
  └── Drivers
```

The backend uses SQL queries through a PostgreSQL connection pool to insert and retrieve fleet records.

---

## 📁 Project Structure

```text
FleetConnect/
│
├── mobile_app/
│   │
│   ├── lib/
│   │   ├── main.dart
│   │   │
│   │   ├── login_screen.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── driver_home.dart
│   │   │   ├── admin_screen.dart
│   │   │   ├── attendance_screen.dart
│   │   │   ├── trip_screen.dart
│   │   │   ├── fuel_screen.dart
│   │   │   ├── issue_screen.dart
│   │   │   ├── repair_screen.dart
│   │   │   └── asset_screen.dart
│   │   │
│   │   └── services/
│   │       └── api_service.dart
│   │
│   └── pubspec.yaml
│
├── server/
│   ├── server.js
│   ├── package.json
│   └── package-lock.json
│
└── README.md
```

---

# 🚀 Getting Started

## Prerequisites

Install the following:

* Flutter SDK
* Dart SDK
* Android Studio
* Node.js
* npm
* PostgreSQL
* Git

---

## 1️⃣ Clone the Repository

```bash
git clone https://github.com/<your-username>/FleetConnect.git

cd FleetConnect
```

---

## 2️⃣ Backend Setup

Navigate to the backend:

```bash
cd server
```

Install dependencies:

```bash
npm install
```

Start the backend:

```bash
node server.js
```

The backend should then be available at the configured server address.

---

## 3️⃣ Database Setup

Create a PostgreSQL database:

```sql
CREATE DATABASE fleetconnect;
```

Configure the PostgreSQL connection in the backend according to your local environment.

Example:

```text
Database: fleetconnect
Host: localhost
Port: 5432
User: postgres
Password: <your-password>
```

> Do not commit database passwords, API keys, or other secrets to GitHub.

---

## 4️⃣ Flutter Setup

Navigate to the mobile application:

```bash
cd mobile_app
```

Install Flutter dependencies:

```bash
flutter pub get
```

Check connected devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

---

# 🔧 API Configuration

The Flutter application communicates with the backend through `ApiService`.

Update the backend URL before running the application:

```dart
static const String baseUrl = "YOUR_BACKEND_URL";
```

For local development:

```text
http://YOUR_LOCAL_IP:PORT
```

For a deployed backend:

```text
https://YOUR-RENDER-BACKEND.onrender.com
```

---

# 🧪 Testing

The application can be tested module-by-module:

### Authentication

* Valid login
* Invalid login
* Driver/Admin role navigation

### Trips

* Assignment
* Start trip
* End trip
* ODO validation
* Active trip persistence

### Fuel

* Vehicle selection
* Fuel card lookup
* Fuel entry
* Receipt upload

### Attendance

* Punch-In
* Punch-Out
* Working-hour calculation

### Maintenance

* Issue reporting
* Repair logging
* Asset allocation

### Admin

* CRUD operations
* Dashboard statistics
* Data refresh
* Excel export

---

# 🔒 Security Notes

For production deployment:

* Store credentials using environment variables.
* Never commit `.env` files.
* Hash passwords before storing them.
* Add proper authentication tokens.
* Validate and sanitize API inputs.
* Configure CORS appropriately.
* Use HTTPS for production communication.
* Restrict database access.

---

# 🌱 Future Enhancements

Potential improvements include:

* 📍 GPS-based live vehicle tracking
* 🗺️ Route visualization
* 🔔 Push notifications
* 🤖 Predictive vehicle maintenance
* ⛽ Fuel consumption analytics
* 📊 Advanced fleet dashboards
* 🔐 JWT-based authentication
* ☁️ Cloud storage for receipts
* 📱 Improved offline support
* 📈 Fleet performance analytics

---

# 🎯 Project Objective

FleetConnect aims to replace fragmented manual fleet workflows with a centralized digital platform that connects **drivers, vehicles, trips, fuel, maintenance, assets, and administrators**.

The project demonstrates full-stack application development involving:

**Flutter + Node.js + Express.js + PostgreSQL + REST APIs**

---

# 👩‍💻 Author

**Kavya C K S**

B.E. Computer Science & Engineering
Artificial Intelligence & Machine Learning

GitHub: [Kavya-1205](https://github.com/Kavya-1205)

---

## ⭐ If you find this project useful

Give the repository a ⭐ and feel free to explore the project.

---

### 📌 Project Status

**Active Development / Academic & Industry Project**
