# LittleLumin — AI-Powered Child Development Platform

**Personalized developmental activities. Practical parenting guidance. AI-assisted learning.**

LittleLumin is an AI-powered child development and parenting guidance platform designed to support early childhood development, particularly for children aged 3–6. It helps parents engage children in personalized, screen-free activities while tracking progress and accessing developmental guidance.

The platform combines a Flutter application, cloud-based data management, authentication, and generative AI to support personalized learning experiences.

## Overview

Traditional digital learning applications often require children to spend extended periods interacting directly with screens. LittleLumin takes a different approach by helping parents guide children through practical activities in their everyday environment.

The platform is designed to connect parents, developmental specialists (Little Lumin Guides), and administrators through dedicated interfaces and workflows.

## Key Features

- **AI-Generated Activities:** Generate personalized learning activities using Google Gemini.
- **Interactive Stories:** Create AI-generated stories to support engaging learning experiences.
- **Screen-Free Learning:** Help parents guide children through activities away from the screen.
- **Developmental Progress Tracking:** Monitor children's progress across skill domains.
- **Parent Dashboard:** Access activities, progress information, feedback, and recommendations.
- **Specialist Support:** Enable Little Lumin Guides (LLGs) to review assigned cases and provide guidance.
- **Administrative Management:** Provide administrative workflows for managing users and platform operations.
- **Authentication:** Support user authentication through Firebase Authentication.
- **Cloud Data Management:** Store and retrieve application data using Firebase Firestore.

## Technology Stack

| Component | Technology |
|---|---|
| Mobile Application | Flutter, Dart |
| Web Interface | Flutter Web |
| Backend API | Python, FastAPI |
| Generative AI | Google Gemini API |
| Database | Firebase Firestore |
| Authentication | Firebase Authentication |
| Version Control | Git, GitHub |

## Architecture

LittleLumin separates the user interface, backend services, AI integration, and cloud data management.

```text
              Flutter Application
             Mobile and Web Clients
                      |
          +-----------+-----------+
          |                       |
   Firebase Services         FastAPI Backend
          |                       |
   +------+-------+         Google Gemini API
   |              |                |
Authentication  Firestore     AI-Generated
                               Activities
                               and Stories
```

The Flutter application provides the user interface. Firebase handles authentication and cloud data storage, while the FastAPI backend exposes endpoints for AI-powered functionality through Google Gemini.

## AI Integration

Generative AI is used to support personalized learning experiences rather than functioning as a standalone chatbot.

Key AI capabilities include:

- Generating learning activities based on application requirements.
- Generating interactive stories.
- Connecting frontend workflows with backend AI services.
- Handling API requests and responses between the application and AI services.

The application uses Google Gemini API for generative AI functionality.

## Engineering Experience

Developing LittleLumin involved working across multiple layers of a software application.

Areas of implementation and development included:

- Integrating frontend screens with backend services.
- Implementing API-based AI functionality.
- Integrating Firebase authentication and database services.
- Debugging application errors and authentication workflows.
- Improving activity progression and developmental tracking logic.
- Testing application features and investigating unexpected behavior.
- Using AI-assisted development tools to support implementation, troubleshooting, and code refinement.

These experiences provided practical exposure to application architecture, API integration, cloud services, debugging, and iterative software development.

## Project Structure

The repository contains the Flutter application, backend implementation, supporting assets, and tests.

```text
LittleLumin/
├── android/             # Android platform configuration
├── assets/              # Application assets
├── backend/             # Backend services
├── lib/                 # Flutter application source
├── test/                # Flutter tests
├── web/                 # Web platform configuration
├── pubspec.yaml         # Flutter dependencies
└── README.md            # Project documentation
```

Additional platform-specific directories and supporting project files are included in the repository.

## Getting Started

### Prerequisites

- Git
- Flutter SDK
- Dart SDK compatible with your Flutter installation
- Firebase project and appropriate configuration
- Google Gemini API access for AI functionality

### Clone the Repository

```bash
git clone https://github.com/arun-biju-8/LittleLumin.git
cd LittleLumin
```

### Configure the Application

1. Install the Flutter dependencies.
2. Configure Firebase using the appropriate project-specific settings.
3. Configure the required environment variables and API credentials.
4. Follow the backend setup instructions in the `backend/` directory.
5. Ensure the frontend is configured to communicate with the intended backend endpoint.

**Security:** Never commit real API keys, passwords, private credentials, or production environment files to GitHub.

### Install Flutter Dependencies

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

The target device or platform must be configured in your Flutter development environment.

For complete setup instructions, consult the configuration files and backend documentation included in the repository.

## Testing

The repository includes automated tests and supporting test resources.

Run the Flutter test suite with:

```bash
flutter test
```

Additional test scripts and test resources are available in the repository.

## Project Information

- **Project:** LittleLumin
- **Developer:** Arun Biju Thomas
- **Institution:** Amal Jyothi College of Engineering
- **Program:** Master of Computer Applications (MCA)
- **Repository:** [GitHub — LittleLumin](https://github.com/arun-biju-8/LittleLumin)

## License

This project includes a GPL-3.0 license. Refer to the `LICENSE` file for the applicable terms.

---

*LittleLumin explores how AI and software engineering can support personalized child development and more accessible parenting guidance.*
