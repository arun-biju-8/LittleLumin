# ✨ LittleLumin

**AI-Powered Child Development & Parenting Guidance Platform**

---

## 📌 Overview

LittleLumin is an AI-powered digital therapeutic and parenting guidance platform designed to support early childhood development for children aged 3-6. It provides personalized, screen-free activities generated in real-time based on each child's unique learning and developmental needs.

Unlike conventional learning apps that place children directly on screens, LittleLumin empowers parents to become their child's primary educator through guided, therapeutic activities.

---

## 🎯 Key Features

| Feature | Description |
|---------|-------------|
| 👶 **Personalized Activities** | AI-generated activities tailored to each child's skill level |
| 📱 **Screen-Free Learning** | Parents guide children through real-world activities |
| 📊 **Progress Tracking** | Monitor development across 6 skill domains |
| 👩‍🏫 **LLG Dashboard** | Little Lumin Guides review and support flagged children |
| 👨‍💼 **Admin Panel** | Manage users, create LLG accounts, and monitor flagged children |
| 🔐 **Role-Based Access** | Parent, LLG, and Admin dashboards |
| 🧠 **VABS-II Integration** | Clinically validated developmental assessment |

---

## 👥 User Roles

| Role | Platform | Description |
|------|----------|-------------|
| **Parent** | Mobile App | Guides child, submits feedback, views progress |
| **LLG** (Little Lumin Guide) | Web Dashboard | Reviews flagged children, sends academic recommendations |
| **Admin** | Web Dashboard | Manages users, content, and flagged children |

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend (Mobile)** | Flutter (Dart) |
| **Frontend (Web)** | Flutter Web (Dart) |
| **Backend API** | Python FastAPI (Coming Soon) |
| **Database** | Firebase Firestore |
| **Authentication** | Firebase Authentication |
| **AI / LLM** | OpenAI API, HuggingFace API |
| **Image Processing** | OpenCV, Tesseract OCR |

---

## 📂 Project Structure

littlelumin/
├── lib/
│ ├── models/ # Data models
│ ├── screens/ # All app screens
│ │ ├── admin/ # Admin dashboard
│ │ └── parent/ # Parent screens
│ ├── services/ # Firebase & API services
│ └── utils/ # Constants, helpers
├── assets/ # Images, fonts
├── web/ # Web configuration
├── pubspec.yaml # Dependencies
└── README.md # This file


---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- Android Studio / VS Code
- Firebase Project
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/arun-biju-8/LittleLumin.git

# Navigate to project
cd LittleLumin

# Get dependencies
flutter pub get

# Run on Android/iOS
flutter run

# Run on Web
flutter run -d chrome

🔥 Firebase Setup
Create a Firebase project

Enable Email/Password Authentication

Enable Google Sign-In

Set up Firestore Database

Download and add configuration files:

Android: google-services.json

iOS: GoogleService-Info.plist

Web: Add config to web/index.html

Create a users collection with userType field

📱 App Screens
Screen	Description
Landing Page	Welcome screen with login/signup
Login / Signup	Email/Password + Google Sign-In
Parent Dashboard	Child progress, activities, feedback
LLG Dashboard	Flagged children, recommendations
Admin Dashboard	User management, LLG creation, flagged review
📊 Database Schema (Firestore)
Users Collection
Field	Type	Description
uid	string	Firebase Auth UID
name	string	User's full name
email	string	User's email
userType	string	parent, llg, or admin
status	string	active or inactive
Children Collection
Field	Type	Description
childId	string	Unique ID
parentId	string	Reference to parent
name	string	Child's name
age	int	Child's age
isFlagged	boolean	Flagged for review
skillProfile	object	6 domain skill scores
👨‍💻 Contributors
Name	Role
Arun Biju	Developer & Designer
📄 License
This project is for academic purposes as part of MCA curriculum.

🙏 Acknowledgments
Vineland Adaptive Behavior Scales (VABS-II)

OpenAI & HuggingFace

Firebase & Google Cloud

📬 Contact
Arun Biju
MCA Student, Amal Jyothi College of Engineering
Project ID: T87 — LittleLumin

⭐ If you find this project useful, give it a star!

text

---

## 🔧 Step 2: Commit and Push

```bash
git add README.md
git commit -m "Added detailed README"
git push