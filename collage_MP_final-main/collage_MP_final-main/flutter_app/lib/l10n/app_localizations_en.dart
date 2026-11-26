// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AQI Monitor';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get profile => 'Profile';

  @override
  String get hospitals => 'Nearby Hospitals';

  @override
  String get settings => 'Settings';

  @override
  String get hospitalsEmpty => 'No hospitals found in this area.';

  @override
  String get directions => 'Directions';

  @override
  String get emergency =>
      'India emergency: 112 national emergency · 108 ambulance';

  @override
  String get setup => 'Set OPENWEATHER_API_KEY in backend/.env';

  @override
  String get disclaimer =>
      'For information only. This tool is not medical advice.';
}
