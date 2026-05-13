import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickscanner/main.dart';
import 'package:quickscanner/services/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('QuickScanner home loads', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({OnboardingPrefs.prefsKey: true});

    await tester.pumpWidget(
      const QuickScannerApp(cameras: <CameraDescription>[]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('QuickScanner'), findsWidgets);
    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.textContaining('Scan'), findsWidgets);
  });
}
