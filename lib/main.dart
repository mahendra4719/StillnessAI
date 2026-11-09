import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/consent.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  consentNotifier.value = prefs.getBool(kConsentKey) ?? false;
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const DrishtiApp(),
  ));
}

class DrishtiApp extends StatelessWidget {
  const DrishtiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Drishti',
        theme: appTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      );
}