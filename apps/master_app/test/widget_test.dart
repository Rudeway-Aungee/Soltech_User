import 'package:flutter_test/flutter_test.dart';
import 'package:soltech_master_app/core/design_system/app_theme.dart';

void main() {
  test('Soltech light theme uses the app color system', () {
    final theme = SoltechTheme.light();

    expect(theme.colorScheme.primary, SoltechColors.green);
    expect(theme.scaffoldBackgroundColor, SoltechColors.canvas);
  });
}
