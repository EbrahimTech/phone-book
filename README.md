# 📱 Phone Book - Flutter Case Study

A modern Flutter application for managing contacts with device integration, built following Clean Architecture principles and Material Design 3 guidelines.

## 🎯 Project Overview

This application was developed as a case study for **NEXOFT Mobile**, demonstrating proficiency in Flutter development, Clean Architecture, state management, and API integration.

## ✨ Key Features

### Core Functionality
- ✅ **CRUD Operations**: Create, Read, Update, Delete contacts
- ✅ **Image Upload**: Profile pictures with dynamic glow effect
- ✅ **Search**: Advanced search with history tracking
- ✅ **Device Integration**: Sync with device contacts
- ✅ **Grouping**: Alphabetical grouping of contacts
- ✅ **Swipe Actions**: Edit and delete via swipe gestures

### Technical Features
- ✅ **Clean Architecture**: Separation of concerns (Domain, Data, Presentation)
- ✅ **State Management**: Riverpod with Event-State pattern
- ✅ **Caching**: Local database (Hive) + Network caching
- ✅ **Responsive Design**: Support for all screen sizes
- ✅ **Performance Optimization**: Image compression, lazy loading, efficient caching
- ✅ **Offline Support**: Network-first with cache fallback

## 🏗️ Architecture

The project follows **Clean Architecture** principles:

```
lib/
├── domain/          # Business Logic (Entities, Repository Interfaces)
├── data/            # Data Layer (API, Local Storage, Repositories)
└── presentation/    # UI Layer (Screens, Widgets, State Management)
```

### Design Patterns
- **Repository Pattern**: Abstraction for data access
- **Provider Pattern**: Dependency injection with Riverpod
- **State Management**: Event-State pattern with StateNotifier

## 🛠️ Technology Stack

### Core
- **Flutter**: 3.8.1+
- **Dart**: 3.8.1+

### State Management
- **Riverpod**: 2.5.1 (State management & Dependency injection)

### Networking
- **Dio**: 5.4.0 (HTTP client)
- **HTTP**: 1.2.0

### Local Storage
- **Hive**: 2.2.3 (Local database)
- **Hive Flutter**: 1.1.0

### UI/UX
- **Lottie**: 3.1.0 (Animations)
- **Cached Network Image**: 3.3.1 (Image caching)
- **Flutter Slidable**: 3.0.1 (Swipe actions)
- **Image Picker**: 1.0.7
- **Image**: 4.1.7 (Image processing)

### Device Integration
- **Flutter Contacts**: 1.1.7+1
- **Permission Handler**: 11.2.0

## 📦 Installation & Setup

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher
- Android Studio / VS Code
- Android SDK (for Android development)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd case_study
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 🔨 Building APK

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

## 🔌 API Integration

### Base URL
```
http://146.59.52.68:11235
```

### Swagger Documentation
```
http://146.59.52.68:11235/swagger
```

### API Key
The API key is configured in `lib/core/constants/api_constants.dart`

**Note**: All API requests require the `ApiKey` header.

## 📱 Permissions

### Android
The app requires the following permissions (configured in `AndroidManifest.xml`):
- `INTERNET`: For API communication
- `READ_CONTACTS`: To check if contacts exist in device
- `WRITE_CONTACTS`: To save contacts to device

## 🎨 Design

- **Material Design 3**: Modern UI following MD3 guidelines
- **Responsive**: Supports phones, tablets, and large screens
- **Dynamic Theming**: Color scheme based on Material Design 3
- **Custom Animations**: Lottie animations for better UX

## 🚀 Performance Optimizations

1. **Image Caching**: Cached network images reduce data usage
2. **Local Database**: Hive for fast local storage
3. **Device Contacts Cache**: Cached for 5 minutes to reduce system calls
4. **Lazy Loading**: Images and lists load on demand
5. **Image Compression**: Images compressed before upload

## 📊 Project Structure

```
lib/
├── core/
│   ├── constants/      # API constants, app constants
│   ├── theme/          # App theme configuration
│   └── utils/          # Utility functions
├── data/
│   ├── datasources/    # API, Local, Device contacts services
│   ├── models/         # Data models
│   └── repositories/   # Repository implementations
├── domain/
│   ├── entities/       # Domain entities
│   └── repositories/   # Repository interfaces
└── presentation/
    ├── providers/      # State management (Riverpod)
    ├── screens/        # UI screens
    └── widgets/        # Reusable widgets
```

## ✅ Requirements Compliance

### Mandatory Features
- ✅ Create contact with name, phone, photo
- ✅ Lottie animation on contact creation
- ✅ Contacts list with alphabetical grouping
- ✅ Swipe to edit/delete
- ✅ Device contacts indicator icon
- ✅ Profile screen with edit/delete
- ✅ Save to device contacts
- ✅ Dynamic avatar glow based on image color
- ✅ Auto-refresh after edit/delete
- ✅ Search with space support
- ✅ Search history
- ✅ Design matches Figma specifications

### Bonus Features
- ✅ Responsive design
- ✅ Cached images
- ✅ Image optimization
- ✅ Local database cache

## 🧪 Testing

### Run Tests
```bash
flutter test
```

### Analyze Code
```bash
flutter analyze
```

## 📝 Code Quality

- **Clean Architecture**: Proper separation of concerns
- **SOLID Principles**: Applied throughout the codebase
- **DRY**: No code duplication
- **KISS**: Simple and maintainable code
- **Linting**: Flutter lints enabled
- **No Issues**: `flutter analyze` shows no issues

## 🔒 Security

- API key stored in constants (should be moved to environment variables in production)
- Permissions requested at runtime
- Input validation on all forms
- Error handling for network failures

## 📄 License

This project was developed as a case study for NEXOFT Mobile.

## 👤 Developer

Developed as part of the NEXOFT Mobile case study application.

## 📧 Contact

For questions or inquiries, please contact: ik@nexoftmobile.net

---

**Version**: 1.0.0  
**Flutter Version**: 3.8.1+  
**Build Date**: 2024
