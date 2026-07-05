# Resumiq — AI CV Generator

> **Build a professional CV in minutes, powered by AI.**

Resumiq is a Flutter-based Android app that lets job seekers generate, edit, and export polished CVs using AI. Simply fill in your details, choose a template, and get a job-ready CV — no design skills required.

---

## Features

- 🤖 **AI-Powered CV Generation** — Generate a full, professional CV from a simple form using Groq (Llama 3.3 70B).
- 📄 **Multiple Templates** — Classic, Modern, Europass, Professional, and more (Pro).
- ✏️ **Granular CV Editor** — Edit every section of your CV individually after generation.
- 📸 **Passport Photo** — Attach a passport-style photo to your CV.
- 🎤 **Voice Input** — Dictate your experience with built-in speech recognition.
- 📥 **PDF Export** — Download a high-quality PDF of your CV directly from the app.
- 🔐 **Firebase Auth** — Secure Google Sign-In.
- ⚡ **Resumiq Pro** — Unlock premium templates and unlimited generations.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| AI | Groq API — Llama 3.3 70B |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Cloudinary |
| Config | Firebase Remote Config |
| PDF | `pdf` package |

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.12.2`
- Android Studio or VS Code
- Firebase project configured (`google-services.json` in `android/app/`)

### Run locally

```bash
flutter pub get
flutter run
```

### Build release APK

```bash
flutter build apk --release
```

---

## Project Structure

```
lib/
├── app/              # App entry, router, theme
├── core/             # Constants, services, utilities
└── features/
    ├── auth/         # Login, splash, onboarding
    ├── cv/           # Input, generation, editor, preview, PDF
    ├── home/         # CV list dashboard
    ├── payment/      # Pro upgrade & payment
    └── profile/      # User profile & settings
```

---

## License

MIT © 2026 zetroxyyy
