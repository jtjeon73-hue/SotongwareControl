import 'package:flutter/foundation.dart';

/// PC DevWorkDoc / Inbox 로컬 폴더 설정 UI 노출 여부.
/// 모바일(Android/iOS)·좁은 화면에서는 숨기고, PC desktop web + FSA만 표시.
bool showPcLocalFolderSettings({
  required bool fsaSupported,
  required double widthPx,
  bool? isWeb,
  TargetPlatform? platform,
  double minWidthPx = 700,
}) {
  final web = isWeb ?? kIsWeb;
  final plat = platform ?? defaultTargetPlatform;
  // Non-web (native mobile) never shows PC folder settings.
  if (!web) return false;
  // Mobile browsers report android/iOS — hide regardless of width.
  if (plat == TargetPlatform.android || plat == TargetPlatform.iOS) {
    return false;
  }
  if (widthPx < minWidthPx) return false;
  return fsaSupported;
}
