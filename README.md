# 📇 CardFlow - Digital Business Card Platform

**Professional business card sharing app for freelancers and professionals** 🚀

---

## 🎯 What is CardFlow?

CardFlow is a Flutter-based digital business card platform designed for **freelancers** who need to:
- Create unlimited business cards for different clients
- Share cards via QR Code, Deep Links, or Nearby Share
- Connect with clients and manage business relationships
- Chat securely about projects and opportunities
- Track card engagement with analytics

---

## ✨ Key Features

- **📱 Multi-Card Creation** - Unlimited cards with 12 premium themes
- **📷 QR Code Sharing** - Instant card exchange
- **🔗 Deep Link Sharing** - Share via WhatsApp, Email, SMS
- **📡 Nearby Share** - Bluetooth/WiFi direct transfer
- **🤝 Connection System** - LinkedIn-style networking
- **💬 Real-time Messaging** - Secure chat with connections
- **🔔 Push Notifications** - Multi-device support
- **📊 Analytics Dashboard** - Track views, shares, and engagement
- **🎨 Theme Customization** - 12 glassmorphic designs
- **🔐 Google Sign-In** - Secure authentication

---

## 🚀 Quick Start

### Installation
```bash
# Clone repository
git clone https://github.com/yourusername/cardflow.git

# Install dependencies
flutter pub get

# Run app
flutter run
```

### Prerequisites
- Flutter SDK ≥ 3.5.3
- Firebase project with:
  - Authentication (Google Sign-In)
  - Realtime Database
  - Storage
  - Cloud Messaging

---

## 📚 Documentation

**For complete documentation, see:** [`CARDFLOW_DOCUMENTATION.md`](CARDFLOW_DOCUMENTATION.md)

This includes:
- Complete architecture overview
- Database structure & data flow
- User flows (create card, share, connect, chat)
- Screen navigation map
- Analytics tracking details
- Security & privacy guidelines
- Development & Firebase setup guide
- Known issues & roadmap

---

## 🛠️ Tech Stack

```yaml
Framework: Flutter 3.5.3
Language: Dart ^3.5.3
Backend: Firebase (Auth, Realtime DB, Storage, FCM)
State: Provider Pattern
UI: Glassmorphism + Custom Animations
```

---

## 📱 App Flow

```
Login (Google) → Home → Create Card → Share via QR/Link
                  ↓
            My Network → Connect → Accept → Chat
```

---

## 🎨 Available Themes

12 professional glassmorphic themes including:
- Professional Blue
- Elegant Purple
- Corporate Dark
- Sunset Glow
- Ocean Breeze
- And 7 more...

---

## 📂 Project Structure

```
lib/
├── main.dart                           # App entry + FCM
├── screens/                            # 13 UI screens
│   ├── login_screen.dart
│   ├── modern_home_screen.dart
│   ├── card_creation_wizard.dart
│   ├── submission_screen.dart
│   ├── card_sharing_hub.dart
│   ├── received_cards_screen.dart
│   ├── my_connections_screen.dart
│   ├── chat_screen.dart
│   └── analytics_screen.dart
├── services/                           # 10 backend services
│   ├── auth_service.dart
│   ├── connection_service.dart
│   ├── messaging_service.dart
│   ├── fcm_service.dart
│   ├── device_service.dart
│   └── analytics_service.dart
└── widgets/                            # Reusable components
```

---

## 🔐 Security

- ✅ Google OAuth authentication
- ✅ Firebase security rules
- ✅ Connection-based messaging
- ✅ Privacy-protected profiles
- ✅ Multi-device token management

---

## 📄 License

Proprietary - All rights reserved.

---

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Status:** Production Ready ✅

**For detailed information, refer to:** [`CARDFLOW_DOCUMENTATION.md`](CARDFLOW_DOCUMENTATION.md)
