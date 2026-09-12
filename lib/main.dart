import 'dart:async';

import 'package:flutter/widgets.dart';

import 'v13_app.dart';

export 'v07.dart';
export 'v09_app.dart';
export 'v10_app.dart';
export 'v13_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () => runApp(const FlipRadarV13App()),
    (error, stack) {
      // Keep asynchronous Dart/plugin errors from tearing down the UI.
      // Production builds will forward these to crash reporting later.
    },
  );
}
