# 🚀 Athar App

**Athar (أثر)** is a modern social media application built with a high-performance architecture, focusing on speed, scalability, and a smooth user experience.

---

## ✨ Features

- 📱 Modern social media platform
- ⚡ High-performance backend
- 🔒 Secure authentication
- 💬 Real-time messaging
- ❤️ Posts, comments, reactions, and follows
- 🗄️ PostgreSQL database with type-safe SQL generation

---

## 🛠️ Tech Stack

### Frontend
- Flutter (Dart)

### Backend
- Go (Golang)
- Gin Framework

### Database
- PostgreSQL
- sqlc
- pgx/v5

---

## 📂 Project Structure

```text
athar/
├── lib/                # Flutter application
├── Backend/            # Go backend
├── database/           # SQL schema and queries
└── README.md
```

---

## 📸 Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/f78613b9-0bac-4660-9402-513b61af62b7" width="320" alt="Athar App Screenshot">
</p>

---

## 🚀 Getting Started

### Clone the repository

```bash
git clone https://github.com/ARM-technology/athar.git
```

### Backend

```bash
cd Backend
go mod tidy
sqlc generate
go run .
```

### Flutter

```bash
flutter pub get
flutter run
```

---

## 📌 Technologies

- Flutter
- Dart
- Go
- Gin
- PostgreSQL
- sqlc
- pgx/v5
- REST API

---

## 📄 License

This project is licensed under the MIT License.
