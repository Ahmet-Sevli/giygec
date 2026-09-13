import 'package:flutter_riverpod/flutter_riverpod.dart';

// Represents the application language state. Default is 'tr', can be 'en'.
final languageProvider = StateProvider<String>((ref) => 'tr');
