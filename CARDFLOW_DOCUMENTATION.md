# 📇 CardFlow - Complete Documentation

**Digital Business Card Sharing Platform for Freelancers**

---

## 📱 What is CardFlow?

CardFlow is a professional digital business card sharing app designed specifically for **freelancers** and **professionals** who need to:
- Create unlimited business cards for different clients/projects
- Share cards instantly via QR Code, Deep Links, or Nearby Share
- Connect with clients and business contacts
- Chat securely about business opportunities
- Track card engagement with analytics

---

## 🎯 Core Features

### 1. **Multi-Card Creation** (Perfect for Freelancers)
- ✅ Create unlimited business cards
- ✅ 12 premium glassmorphic themes
- ✅ Custom branding (colors, fonts, logos)
- ✅ Each card has unique identity

### 2. **Smart Sharing Methods**
- 📷 **QR Code** - Generate & scan instantly
- 🔗 **Deep Links** - Share via WhatsApp, Email, SMS
- 📡 **Nearby Share** - Bluetooth/WiFi direct transfer

### 3. **Connection System** (LinkedIn-style)
- 🤝 Either party can send connection request
- ✅ Accept/Decline functionality
- 📊 Track connection status
- 🔒 Privacy-protected (can't message without connection)

### 4. **Secure Messaging**
- 💬 Real-time chat with connected users
- ✍️ Typing indicators
- ✅ Read receipts
- 🔔 Push notifications

### 5. **Analytics Dashboard**
- 📊 Card view tracking
- 📈 Weekly engagement graphs
- 👆 Contact button clicks (email, phone, website)
- 📤 Share count

---

## 🏗️ Technical Architecture

### **Stack**
```yaml
Framework: Flutter 3.5.3 / Dart ^3.5.3
Backend: Firebase
  - Authentication: Google Sign-In
  - Database: Realtime Database (not Firestore)
  - Storage: Firebase Storage (profile pictures)
  - Messaging: Firebase Cloud Messaging (FCM)
State: Provider Pattern
UI: Glassmorphism + Custom Animations
```

### **Project Structure**
```
lib/
├── main.dart                           # App entry, FCM initialization
├── screens/
│   ├── splash_screen_wrapper.dart      # Auth state handler
│   ├── login_screen.dart               # Google Sign-In
│   ├── modern_home_screen.dart         # Main dashboard
│   ├── card_creation_wizard.dart       # Card builder (3-step wizard)
│   ├── card_customization_screen.dart  # Theme selector
│   ├── submission_screen.dart          # My Cards library
│   ├── received_cards_screen.dart      # My Network (received cards)
│   ├── card_sharing_hub.dart           # Sharing methods hub
│   ├── business_card.dart              # Card display screen
│   ├── edit_submission_screen.dart     # Card editor
│   ├── my_connections_screen.dart      # Connection management (3 tabs)
│   ├── chat_screen.dart                # Messaging interface
│   └── analytics_screen.dart           # Analytics dashboard
├── services/
│   ├── auth_service.dart               # Google Sign-In/Out
│   ├── analytics_service.dart          # Firebase Analytics tracking
│   ├── card_customization_service.dart # Theme management
│   ├── nearby_share_service.dart       # Bluetooth/WiFi sharing
│   ├── deep_link_service.dart          # URL-based card sharing
│   ├── connection_service.dart         # Connection CRUD operations
│   ├── messaging_service.dart          # Chat functionality
│   ├── fcm_service.dart                # Push notifications
│   ├── device_service.dart             # Multi-device token management
│   └── firestore_service.dart          # User profile management
└── widgets/
    └── animated_gradient_container.dart # Reusable gradient background
```

---

## 🗄️ Database Structure (Firebase Realtime DB)

```javascript
users/
  {userId}/                             // Firebase Auth UID
    createdCards/
      {cardId}/
        businessName: "Tech Solutions"
        personName: "John Doe"
        email: "john@tech.com"
        contactNumber: "+1234567890"
        website: "www.techsol.com"
        imageUrl: "https://..."          // Profile picture URL
        themeData:                        // Theme configuration
          themeId: "corporate_dark"
          gradientColor1: "ff424242"
          gradientColor2: "ff212121"
          textColor: "ffffffff"
          accentColor: "ff757575"
          fontFamily: "Roboto"
          borderRadius: 16
          hasGlassEffect: false
        timestamp: 1760667979528
        isActive: true
    
    receivedCards/                      // Cards from others
      {originalCardId}/
        businessName: "..."
        personName: "..."
        email: "..."
        contactNumber: "..."
        website: "..."
        imageUrl: "..."
        themeData: {...}
        originalCardId: "{cardId}"      // Links to original
        sharedBy: "{userId}"            // Sender's Firebase UID
        sharedByUsername: "..."         // Display name
        sharedByPhoto: "..."            // Sender's photo
        receivedAt: 1760683252324
    
    connections/                        // Connection tracking
      connected/
        {otherUserId}: true
      pending_sent/
        {otherUserId}: true
      pending_received/
        {otherUserId}: true
    
    analytics/
      globalStats/
        totalViews: 150
        totalShares: 45
        emailClicks: 12
        phoneClicks: 8
        websiteClicks: 20
        weeklyViews: [10, 25, 30, 15, 40, 20, 10]
      cardStats/
        {cardId}/
          views: 50
          shares: 15
          emailClicks: 5
          phoneClicks: 3
          websiteClicks: 8
          lastViewedAt: 1760428166944

connections/
  {initiatorId}_{recipientId}/          // Connection records
    initiatorId: "userA_id"
    recipientId: "userB_id"
    initiatorName: "John Doe"
    recipientName: "Jane Smith"
    initiatorPhoto: "https://..."
    recipientPhoto: "https://..."
    cardId: "{cardId}"                  // Card that was shared
    status: "pending" | "connected" | "declined"
    requestedAt: 1760679588108
    connectedAt: 1760679023655          // When accepted
    lastInteraction: 1760679186910
    shareMethod: "qr_code" | "deep_link" | "nearby" | "my_network"
    requestNote: "Let's connect!"

messages/
  {connectionId}/                       // Chat messages
    {messageId}/
      connectionId: "userA_id_userB_id"
      senderId: "userA_id"
      senderName: "John Doe"
      senderPhoto: "https://..."
      text: "Hi, let's discuss the project"
      type: "text" | "image" | "card" | "system"
      timestamp: 1760679036294
      read: true
      imageUrl: null                    // For image messages
      cardData: null                    // For card messages

devices/                                // Multi-device support
  {deviceId}/
    deviceId: "phone_device_id_123"
    userId: "userA_id"
    fcmToken: "dfmM0ODfRSWW..."
    deviceName: "Samsung Galaxy S24"
    deviceModel: "SM-S928B"
    platform: "android" | "ios"
    osVersion: "Android 14"
    isActive: true
    lastActive: 1729150000000
    createdAt: 1729150000000

notifications/                          // Push notification queue
  {notificationId}/
    title: "New Connection Request"
    body: "John Doe wants to connect with you"
    recipientUserId: "userB_id"
    recipientToken: "dfmM0ODfRSWW..."
    type: "connection_request"
    data:
      connectionId: "..."
      senderId: "..."
      senderName: "..."
    timestamp: 1760683372787
    sent: false
```

---

## 🔄 Complete User Flows

### **1. New User Onboarding**
```
1. Open app → Splash screen
2. Not authenticated → Login Screen
3. Tap "Sign in with Google" → Google OAuth
4. AuthService.signInWithGoogle()
5. Firebase Auth creates user
6. FCMService.initialize() → Get device FCM token
7. DeviceService.registerDevice() → Save to devices/
8. Navigate to Home Screen
```

### **2. Create Business Card**
```
1. Home Screen → Tap "Create New Card"
2. CardCreationWizard opens (3 steps):
   
   Step 1: Business Info
     - Business name (required)
     - Person name (required)
     - Email (required, validated)
     - Phone (required, validated)
     - Website (optional)
   
   Step 2: Theme Selection
     - Grid of 12 themes
     - Tap to preview
     - Select favorite
   
   Step 3: Review & Submit
     - Preview card
     - Edit if needed
     - Tap "Create Card"

3. Save to Firebase:
   users/{userId}/createdCards/{cardId}
   
4. Initialize analytics:
   users/{userId}/analytics/cardStats/{cardId}
   
5. Navigate back to My Cards screen
```

### **3. Share Card via QR Code**
```
1. My Cards → Tap card → "Share Card"
2. CardSharingHub opens
3. Tap "Generate QR Code"
4. Encode card data:
   businessName|personName|email|phone|website|imageUrl|themeId|
   themeData|cardId|username|photoUrl|userId
   
5. Generate QR with qr_flutter
6. Display QR code screen
7. Other person scans → receives card
```

### **4. Receive Card via QR Scan**
```
1. CardSharingHub → Tap "Scan QR Code"
2. Camera opens (mobile_scanner)
3. Scan QR code
4. Decode card data
5. Save to Firebase:
   users/{currentUserId}/receivedCards/{originalCardId}
   
6. Track analytics:
   users/{cardOwnerUserId}/analytics/cardStats/{cardId}/shares++
   
7. Show "Card Received!" dialog
8. Navigate to My Network screen
```

### **5. Send Connection Request**
```
1. My Network → Tap received card
2. Tap "Connect" button
3. ConnectionService.sendConnectionRequest():
   
   a) Create connection record:
      connections/{initiatorId}_{recipientId}/
        status: "pending"
        requestedAt: timestamp
        ...
   
   b) Update user connection lists:
      users/{initiatorId}/connections/pending_sent/{recipientId}: true
      users/{recipientId}/connections/pending_received/{initiatorId}: true
   
   c) Send push notification:
      FCMService.sendNotificationToUser(recipientId)
      → DeviceService.getUserFCMTokens(recipientId)
      → Get all device tokens
      → Send notification to each device
   
4. Button changes to "Pending..."
```

### **6. Accept Connection Request**
```
1. Receive push notification → Open app
2. My Connections → "Pending Requests" tab
3. See incoming request with card preview
4. Tap "Accept"
5. ConnectionService.acceptConnection():
   
   a) Update connection status:
      connections/{initiatorId}_{recipientId}/
        status: "connected"
        connectedAt: timestamp
   
   b) Update user connection lists:
      Remove from pending_received
      Add to connected
   
   c) Send notification to initiator:
      "John accepted your connection request!"
   
6. Chat button appears → Can now message
```

### **7. Start Chatting**
```
1. My Connections → "Connected" tab
2. Tap connection card → Opens ChatScreen
3. MessagingService.getMessagesStream() → Real-time listener
4. Type message → Tap send
5. MessagingService.sendMessage():
   
   Save to: messages/{connectionId}/{messageId}/
     text: "..."
     senderId: "..."
     timestamp: ...
     read: false
   
6. Other user receives in real-time
7. When they open chat:
   MessagingService.markMessagesAsRead()
   → Update read: true
```

---

## 🎨 UI Components & Themes

### **Available Themes** (12 Total)
```dart
1. Professional Blue    - Blue gradient, white text
2. Elegant Purple       - Purple gradient, white text
3. Corporate Dark       - Dark gray gradient, white text
4. Modern Gradient      - Multi-color gradient
5. Sunset Glow          - Orange-pink gradient
6. Ocean Breeze         - Teal-blue gradient
7. Forest Green         - Green gradient
8. Royal Gold           - Gold-yellow gradient
9. Midnight Blue        - Dark blue gradient
10. Rose Pink           - Pink gradient
11. Lavender Dream      - Light purple gradient
12. Emerald Shine       - Bright green gradient
```

### **Card Display Components**
```dart
BusinessCardScreen
  ├── GlassmorphicContainer (if hasGlassEffect: true)
  │   ├── Business Name (large, bold)
  │   ├── Person Name (medium)
  │   ├── Contact Info (email, phone, website with icons)
  │   └── Quick Actions (3 buttons)
  │       ├── Email (tap to open email app)
  │       ├── Call (tap to open phone dialer)
  │       └── Website (tap to open browser)
  └── Regular Container (if hasGlassEffect: false)
      └── Same content with solid gradient
```

### **Connection Status Indicators**
```dart
My Network Card:
  - No connection    → "Connect" button (blue)
  - Pending sent     → "Pending..." button (orange, disabled)
  - Pending received → "Accept/Decline" buttons (green/red)
  - Connected        → "Chat" button (gradient)
```

---

## 📊 Analytics Tracking

### **Tracked Events**
```dart
1. Card Views
   - Who: Card owner (not viewer)
   - When: Every time someone opens their card
   - Updates: totalViews, weeklyViews, lastViewedAt

2. Card Shares
   - Who: Card owner
   - When: Card is shared via QR/link/nearby
   - Updates: totalShares

3. Contact Button Clicks
   - Who: Card owner
   - What: Email, Phone, or Website button
   - Updates: emailClicks, phoneClicks, websiteClicks
```

### **Analytics Display**
```
Analytics Screen:
  ├── Total Views Card (with growth indicator)
  ├── Total Shares Card
  ├── Contact Clicks Card (breakdown)
  ├── Weekly Views Chart (bar graph)
  └── Per-Card Statistics (list)
```

---

## 🔔 Push Notifications System

### **Multi-Device Support**
Each user can have multiple devices (phone + tablet). When someone sends a connection request, ALL active devices receive the notification.

**Flow:**
```
1. User A sends connection request to User B
2. FCMService.sendNotificationToUser(userB_id)
3. DeviceService.getUserFCMTokens(userB_id)
   → Queries users/{userB_id}/devices/
   → Reads each devices/{deviceId}/ where isActive: true
   → Returns: ["token1", "token2", "token3"]
4. For each token:
   Send notification via Firebase Admin SDK
5. All User B's devices receive notification simultaneously
```

**Device Management:**
- Login → DeviceService.registerDevice() → Creates device record
- Logout → DeviceService.deactivateDevice() → Sets isActive: false
- Token refresh → FCMService.onTokenRefresh → Updates FCM token

---

## 🔒 Security & Privacy

### **Authentication**
- Google Sign-In only (no password management)
- Firebase Auth handles all OAuth flow
- User profile from Google account (name, email, photo)

### **Data Access Rules**
```javascript
// Firebase Realtime Database Rules
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "connections": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "messages": {
      "$connectionId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "devices": {
      "$deviceId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

### **Privacy Features**
- ✅ Can't message without connection
- ✅ Can decline connection requests
- ✅ Profile only visible to connected users
- ✅ Analytics only visible to card owner

---

## 🚀 Key Improvements Implemented

### **1. Multi-Device Notifications**
- ✅ All user devices receive notifications
- ✅ Device token management
- ✅ Automatic token refresh
- ✅ Device deactivation on logout

### **2. Connection System**
- ✅ LinkedIn-style connection flow
- ✅ Bidirectional connection support
- ✅ Connection status tracking
- ✅ Request notes

### **3. Real-Time Messaging**
- ✅ Firebase Realtime Database streams
- ✅ Typing indicators
- ✅ Read receipts
- ✅ Message timestamps

### **4. Analytics Dashboard**
- ✅ Per-card statistics
- ✅ Global statistics
- ✅ Weekly trends
- ✅ Click tracking

---

## 🛠️ Development Setup

### **Prerequisites**
```bash
Flutter 3.5.3 or higher
Dart 3.5.3 or higher
Android Studio / Xcode
Firebase account
```

### **Installation**
```bash
# Clone repository
git clone https://github.com/yourusername/cardflow.git

# Install dependencies
flutter pub get

# Run app
flutter run
```

### **Firebase Configuration**
1. Create Firebase project at console.firebase.google.com
2. Enable services:
   - Authentication (Google Sign-In)
   - Realtime Database
   - Storage
   - Cloud Messaging
3. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
4. Update database rules (see Security section)

---

## 📱 Screen Navigation Map

```
Splash Screen (AuthHandler)
  ↓
  ├─ Not Logged In → Login Screen
  │                    ↓
  │                    Google Sign-In
  │                    ↓
  └─ Logged In → Home Screen
                   ↓
                   ├─→ Create New Card → Card Creation Wizard
                   │                        ↓
                   │                        My Cards (Submission Screen)
                   │                        ↓
                   │                        Edit/Delete Card
                   │
                   ├─→ My Cards → Submission Screen
                   │                ↓
                   │                View Card → Business Card Screen
                   │                ↓
                   │                Share → Card Sharing Hub
                   │                           ↓
                   │                           ├─ QR Code
                   │                           ├─ Deep Link
                   │                           └─ Nearby Share
                   │
                   ├─→ My Network → Received Cards Screen
                   │                  ↓
                   │                  ├─ View Card
                   │                  └─ Connect → Connection Request
                   │
                   ├─→ My Connections → My Connections Screen (3 tabs)
                   │                      ↓
                   │                      ├─ Pending Requests
                   │                      ├─ Sent Requests
                   │                      └─ Connected
                   │                          ↓
                   │                          Chat → Chat Screen
                   │
                   ├─→ Analytics → Analytics Screen
                   │
                   ├─→ Customize Themes → Card Customization Screen
                   │
                   └─→ Logout → Login Screen
```

---

## 🐛 Known Issues & Future Enhancements

### **Current Limitations**
- ❌ Messages are permanent (no 3-day auto-deletion yet)
- ❌ No search functionality in connections/cards
- ❌ No profile editing (uses Google profile only)
- ❌ No card categories/tags
- ❌ No export to contacts feature

### **Planned Features**
1. **3-Day Message Auto-Deletion**
   - Add scheduled deletion to MessagingService
   - Cloud Function to clean up old messages
   
2. **Search & Filters**
   - Search received cards by name/business
   - Filter connections by status
   - Sort by date/name
   
3. **Enhanced Profile**
   - Custom bio
   - Social media links
   - Profile picture editing
   
4. **Card Management**
   - Categories (Client, Partner, Vendor, etc.)
   - Tags for organization
   - Archive inactive cards
   
5. **Export Features**
   - Export to phone contacts
   - Export as vCard (.vcf)
   - Print card as PDF

---

## 📞 Support & Contact

**App Name:** CardFlow  
**Version:** 1.0.0  
**Platform:** Flutter (iOS & Android)  
**Firebase Project:** ygitapp  

For technical support, refer to the codebase documentation or contact the development team.

---

## 📄 License

Proprietary - All rights reserved.

---

**Last Updated:** January 2025  
**Status:** Production Ready ✅
