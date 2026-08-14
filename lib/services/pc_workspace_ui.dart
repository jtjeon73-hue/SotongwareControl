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

/// 제작소 상단 PC 작업환경 상태 문구 (표시 전용, 폴더 연결 강제 없음).
class PcWorkspaceStatusCopy {
  const PcWorkspaceStatusCopy({
    required this.headline,
    required this.agentLine,
    this.devWorkDocLine,
    this.showInboxUnconnectedWarning = false,
  });

  /// 핵심 운영 상태 (Agent/Relay 중심).
  final String headline;

  /// 소통24워크 PC 온라인/오프라인 한 줄.
  final String agentLine;

  /// DevWorkDoc 로컬 폴더 경고/정상 (FSA 환경에서만).
  final String? devWorkDocLine;

  /// Inbox 미연결을 장애처럼 노출할지 (Relay 비정상일 때만 true).
  final bool showInboxUnconnectedWarning;
}

/// Agent 온라인 + Relay 가능이면 핵심은 정상. DevWorkDoc/Inbox는 별도 경고.
PcWorkspaceStatusCopy resolvePcWorkspaceStatusCopy({
  required bool fsaSupported,
  required bool agentOnline,
  required bool hasAnyAgent,
  required bool devFolderReady,
  required bool inboxReady,
  int onlineAgentCount = 1,
}) {
  final relayOk = agentOnline;
  final agentLine = !agentOnline
      ? (hasAnyAgent ? '소통24워크 PC  · 오프라인' : '소통24워크 PC  · 상태 없음')
      : '소통24워크 PC  ● 온라인'
          '${onlineAgentCount == 1 ? '' : ' ($onlineAgentCount)'}';

  final String headline;
  if (!fsaSupported) {
    headline = relayOk ? '원격 작업 전달 정상' : '원격 작업환경';
  } else if (relayOk) {
    headline = '원격 작업 전달 정상';
  } else {
    headline = '소통24워크 PC 재연결 필요';
  }

  final String? devLine;
  if (fsaSupported) {
    if (devFolderReady) {
      devLine = 'DevWorkDoc 연결';
    } else {
      devLine = 'DevWorkDoc  재연결 필요';
    }
  } else {
    devLine = '작업지시 전달 : 원격(Firestore)';
  }

  final showInbox = fsaSupported && !inboxReady && !relayOk;

  return PcWorkspaceStatusCopy(
    headline: headline,
    agentLine: agentLine,
    devWorkDocLine: devLine,
    showInboxUnconnectedWarning: showInbox,
  );
}
