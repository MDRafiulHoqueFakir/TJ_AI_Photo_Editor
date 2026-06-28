import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tj_photo_editor/app.dart';

void main() {
  testWidgets('App boots into onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TJPhotoEditorApp()));
    await tester.pump();

    // First onboarding slide + CTA should be present.
    expect(find.text('Edit like a pro'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
