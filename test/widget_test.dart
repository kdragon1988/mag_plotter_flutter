/// MAG PLOTTER ウィジェットテスト
///
/// 基本的なウィジェットテストを実行
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mag_plotter/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // アプリを起動
    await tester.pumpWidget(const MagPlotterApp());

    // スプラッシュ画面が表示されることを確認
    expect(find.text('MAG PLOTTER'), findsOneWidget);
  });
}
