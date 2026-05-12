# Trackify: Project Overview and Documentation

Trackify is a specialized financial management application that merges a classic "vintage" aesthetic with modern software architecture. It utilizes an **Offline-First** approach to ensure data integrity across volatile network conditions, while leveraging Google Gemini AI Flash 2.5 for automated receipt processing and WebSockets for real-time synchronization.

---

## Project Description

Trackify is a secure, local-first expense tracker designed to bridge the gap between physical transactions and digital accounting. The application prioritizes user privacy and data ownership through a custom Opaque Token authentication system, utilizing a self-hosted FastAPI and Neon PostgreSQL backend.

---

## Core Functionality

* **Local-First Data Persistence**: All transactions are written to a local SQLite database immediately. The application remains fully functional without an internet connection.

* **Asynchronous Synchronization**: A background synchronization engine detects connectivity changes to push pending local entries to the cloud and pull historical data.

* **AI Receipt Processing**: Integration with Google Gemini extracts establishment names, amounts, dates, and categories from images provided via camera or gallery.

* **WebSocket Real-Time Updates**: Uses WebSockets to notify the mobile client the moment an asynchronous AI task is completed on the server.

* **Multi-Currency Support**: Features a dedicated currency preference system with auditory feedback unique to each currency.

---

## Architectural Details

### Tech Stack
* **Frontend**: Flutter (Cross-platform support for Mobile and Windows Desktop)
* **State Management**: BLoC (Business Logic Component)
* **Local Database**: SQLite (via sqflite and sqflite_common_ffi)
* **Backend**: FastAPI (Python)
* **Primary Database**: Neon PostgreSQL
* **AI Engine**: Google Gemini API
* **Authentication**: Opaque Token Session Management

### The Sync Engine
Trackify employs a "Pull-on-Login" and "Push-on-Connect" strategy. Upon authentication, the app fetches all historical data from Neon to populate the local SQLite cache. When a user is offline, entries are marked with a synchronization flag (`is_synced = 0`). Once connectivity is restored, the system pushes these specific entries to the backend and reconciles the local ledger with the server state.

---

## Application Pages and Features

### 1. Authentication (Login & Register)
* Secure hashing (Bcrypt) for password protection.

### 2. The Ledger (Dashboard)
* Chronological display of all transactions.
* "Sync Pending" indicators for local data that has not yet reached the server.
* Real-time list updates via WebSocket signals when receipt processing finishes.

### 3. New Entry (Manual & AI)
* **Manual Entry**: Users can record establishment names, amounts, and dates with immediate local feedback.
* **AI Scan**: Users can take a photo or upload from the gallery. The image is processed by Gemini on the server, and results are broadcast back to the app via WebSockets.

### 4. Profile & Preferences
* **Currency Settings**: Users select a default currency (RON, USD, EUR, etc.).
* **Auditory Feedback**: Changing the default currency triggers a unique sound theme for that currency.
* **Security**: Logout clears all local session data and wipes the local SQLite cache.

---

## API & Data Handling

The backend serves as a central hub for data transformation:
* **Receipt Parser**: Converts raw image data into structured JSON using prompt engineering.
* **Session Manager**: Validates Opaque Tokens against the PostgreSQL database for every request.
* **Sync Endpoint**: Accepts batches of expenses from the mobile client to resolve offline discrepancies.

---

## Visual & Auditory Theme

* **Visuals**: A "Vintage Paper" theme featuring cream backgrounds, ink-colored text, and aged-gold accents.
* **Typography**: Georgia and serif-based fonts simulate a physical accounting ledger.
* **Sounds**: Integrated auditory feedback for saving transactions or updating settings to enhance the tactile feel of the digital ledger.

---

## How to Use

### Prerequisites
* Flutter SDK
* Python 3.10+
* PostgreSQL (Neon) account
* Google Gemini API Key

### Backend Setup
1. Navigate to the server directory.
2. Install dependencies: `pip install -r requirements.txt`.
3. Configure the `.env` file with `DATABASE_URL` and `GEMINI_API_KEY`.
4. Run the server: `uvicorn main:app --reload`.

### Frontend Setup
1. Navigate to the mobile directory.
2. Enable Windows Developer Mode if running on Desktop.
3. Run `flutter pub get`.
4. Run `flutter run`.

### Testing Offline Sync
1. Disconnect the internet while the app is running.
2. Add a manual entry; it will appear in the Ledger immediately.
3. Reconnect the internet.
4. Terminal logs will display the background sync pushing the entry to the cloud.