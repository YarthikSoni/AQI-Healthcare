// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'AQI मॉनिटर';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get hospitals => 'पास के अस्पताल';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get hospitalsEmpty => 'इस क्षेत्र में कोई अस्पताल नहीं मिला।';

  @override
  String get directions => 'दिशा-निर्देश';

  @override
  String get emergency => 'भारत आपातकाल: 112 राष्ट्रीय आपातकाल · 108 एम्बुलेंस';

  @override
  String get setup => 'backend/.env में OPENWEATHER_API_KEY सेट करें';

  @override
  String get disclaimer =>
      'केवल जानकारी के लिए। यह उपकरण चिकित्सा सलाह नहीं है।';
}
