import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  runApp(const ProviderScope(child: RefetchApp()));
}

/// Inter and Poppins ship under the SIL Open Font License, which asks for the
/// licence to travel with the fonts; it shows in the app's licence page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [
      ('Inter', 'assets/fonts/Inter-OFL.txt'),
      ('Poppins', 'assets/fonts/Poppins-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    }
  });
}
