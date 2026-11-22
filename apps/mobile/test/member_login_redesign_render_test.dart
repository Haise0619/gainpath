import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/main.dart';
import '../../../test_support/fyp_render_support.dart';

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/images/gainpath_logo_sticker.png') {
      return ByteData.sublistView(File(
              'c:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/assets/images/gainpath_logo_sticker.png')
          .readAsBytesSync());
    }
    if (key == 'assets/images/google_sign_in_mark.png') {
      return ByteData.sublistView(File(
              'c:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/assets/images/google_sign_in_mark.png')
          .readAsBytesSync());
    }
    return rootBundle.load(key);
  }
}

class _TestGoogleAuthRepository extends InMemoryAuthRepository
    implements GoogleAuthActions {
  @override
  bool get supportsGoogleSignIn => true;

  @override
  Future<AuthSession> signInWithGoogle({required bool registering}) async {
    throw const AuthSignInCancelled();
  }
}

void main() {
  testWidgets('render redesigned member login and registration screens',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
          .readAsBytesSync())));
    await icons.load();

    const artifactDir =
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314';

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();

    final testBundle = _TestAssetBundle();

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: testBundle,
        child: RepaintBoundary(
          key: key,
          child: GainPathMobileApp.injected(
            authRepository: _TestGoogleAuthRepository(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final BuildContext context = key.currentContext!;
      await precacheImage(
        AssetImage('assets/images/gainpath_logo_sticker.png',
            bundle: testBundle),
        context,
      );
      await precacheImage(
        AssetImage('assets/images/google_sign_in_mark.png',
            bundle: testBundle),
        context,
      );
    });
    await tester.pumpAndSettle();

    // 1. Capture Login Screen
    await tester.runAsync(() async {
      final renderObject =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await renderObject.toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('$artifactDir/member_login_page_redesigned.png');
      await file.writeAsBytes(bytes);
      image.dispose();
    });

    // 2. Toggle to Register mode
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    // Capture Register Screen
    await tester.runAsync(() async {
      final renderObject =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await renderObject.toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('$artifactDir/member_register_page_redesigned.png');
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  });
}
