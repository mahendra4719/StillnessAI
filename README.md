# Drishti

Drishti is a Flutter app for guided mindfulness sessions and gentle reflection on session habits. Choose a 5, 10, or 20 minute session, set whether your eyes will be open or closed, and review your session history and trends over time.

During a session, the app can use the camera to observe visible eye and head behaviour, such as blink rate and gaze stability. These are simple observations, not a measure of how you feel or a clinical assessment. The app also includes breathing guidance, a journal, and session insights.

## Run the app

You’ll need the Flutter SDK and a device or emulator set up for Flutter development. From the project directory, run:


```bash
flutter pub get
flutter run
```

Camera access is needed for camera-based session observations. You can also explore the rest of the app, including its session history and breathing exercises.

Before using the app on a mobile device, enable Developer options and turn on USB tethering.

## Built with

- Flutter and Dart
- Riverpod for app state
- GoRouter for navigation
- SQLite and shared preferences for local app data
- Flutter camera and text-to-speech packages for session features

## Learn more about Flutter

- [Set up Flutter](https://docs.flutter.dev/get-started/install)
- [Flutter documentation](https://docs.flutter.dev/)
