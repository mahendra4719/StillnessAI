import 'package:flutter/foundation.dart';

const String kConsentKey = 'consent_v1';

/// true = user ne privacy notice accept kiya hai.
final ValueNotifier<bool> consentNotifier = ValueNotifier<bool>(false);