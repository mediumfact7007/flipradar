import 'package:flutter/widgets.dart';

import 'v10_app.dart';

export 'v07.dart';
export 'v09_app.dart';
export 'v10_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipRadarV10App());
}
