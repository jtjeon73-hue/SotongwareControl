/// 제작 형태(artifact) — 기획·작업지시의 1차 필수 축.
library;

/// 통일 artifact ID: app | ebook | contents | site | promo_site
class ArtifactType {
  static const app = 'app';
  static const ebook = 'ebook';
  static const contents = 'contents';
  static const site = 'site';
  static const promoSite = 'promo_site';
  static const undecided = 'undecided';

  static const allSelectable = [ebook, app, contents, site, promoSite];

  static const folderNames = {
    app: 'App',
    ebook: 'Ebook',
    contents: 'Contents',
    site: 'Site',
    promoSite: 'PromoSite',
  };

  /// UI 짧은 표시명 (기획 마법사·목록 통일).
  static String labelShortKo(String id) {
    switch (normalize(id)) {
      case app:
        return '앱';
      case ebook:
        return '전자책';
      case contents:
        return '콘텐츠';
      case site:
        return '사이트';
      case promoSite:
        return '홍보사이트';
      case undecided:
        return '아직 결정하지 못함';
      default:
        return id;
    }
  }

  /// [labelShortKo]와 동일 — 화면 표시는 짧은 이름으로 통일.
  static String labelKo(String id) => labelShortKo(id);

  /// 개발 트랙 짧은 표시 (primaryTrack과 동일 계열).
  static String labelDevKo(String id) => primaryTrack(id);

  /// 레거시 deliverable → artifact.
  static String normalize(String raw) {
    switch (raw) {
      case app:
      case '앱':
        return app;
      case ebook:
      case '전자책':
        return ebook;
      case contents:
      case 'content':
      case 'content_music':
      case 'music_content':
      case 'education_content':
      case 'youtube_shorts':
      case 'youtube_video':
        return contents;
      case site:
      case 'industrial_automation':
        return site;
      case promoSite:
      case 'web_marketing':
        return promoSite;
      case undecided:
      case 'custom':
        return undecided;
      default:
        return raw.isEmpty ? undecided : raw;
    }
  }

  static String primaryTrack(String artifact) {
    switch (normalize(artifact)) {
      case app:
        return '앱개발';
      case ebook:
        return '전자책개발';
      case contents:
        return '콘텐츠개발';
      case site:
        return '사이트개발';
      case promoSite:
        return '마케팅사이트개발';
      default:
        return '미정';
    }
  }

  static String primaryTrackId(String artifact) {
    switch (normalize(artifact)) {
      case app:
        return 'app_dev';
      case ebook:
        return 'ebook_dev';
      case contents:
        return 'content_dev';
      case site:
        return 'site_dev';
      case promoSite:
        return 'promo_site_dev';
      default:
        return 'undecided';
    }
  }

  static String? folderName(String artifact) =>
      folderNames[normalize(artifact)];
}

/// 콘텐츠개발 하위 유형.
class ContentSubtype {
  static const song = 'song';
  static const shorts = 'shorts';
  static const video = 'video';
  static const songAndShorts = 'song_and_shorts';
  static const other = 'other';
  static const undecided = 'undecided';

  static const allSelectable = [song, shorts, video, songAndShorts, other];

  static String labelKo(String id) {
    switch (id) {
      case song:
        return '노래';
      case shorts:
        return '유튜브 쇼츠';
      case video:
        return '영상';
      case songAndShorts:
        return '노래와 쇼츠 연계';
      case other:
        return '기타 콘텐츠';
      case undecided:
        return '아직 결정하지 못함';
      default:
        return id;
    }
  }

  static String normalize(String raw) {
    switch (raw) {
      case song:
      case 'music_content':
      case 'content_music':
        return song;
      case shorts:
      case 'youtube_shorts':
        return shorts;
      case video:
      case 'youtube_video':
        return video;
      case songAndShorts:
        return songAndShorts;
      case other:
      case 'education_content':
      case 'content':
        return other;
      default:
        return undecided;
    }
  }
}
