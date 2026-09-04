/// Control UI contentSubtype ↔ Sotong24Work commercial contentSubtype enum.
///
/// Work known subtypes (CommercialContentQualityProfile.h):
/// song_audio | shorts_video | comic_video | notification_promo_video |
/// image_design | other | legacy aliases music|shorts|comic
library;

class ContentSubtypeContract {
  ContentSubtypeContract._();

  static const songAudio = 'song_audio';
  static const shortsVideo = 'shorts_video';
  static const comicVideo = 'comic_video';
  static const notificationPromoVideo = 'notification_promo_video';
  static const imageDesign = 'image_design';
  static const other = 'other';

  /// Work-accepted values including legacy aliases.
  static const knownWorkSubtypes = <String>{
    songAudio,
    shortsVideo,
    comicVideo,
    notificationPromoVideo,
    imageDesign,
    other,
    'music',
    'shorts',
    'comic',
  };

  /// Canonical Work commercial enum (no silent fallback to a default).
  /// Returns null when empty; throws [ArgumentError] for unknown values.
  static String? toWorkCommercialEnum(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    switch (s) {
      case 'music':
      case 'song':
      case 'song_audio':
      case 'music_content':
      case 'content_music':
        return songAudio;
      case 'shorts':
      case 'shorts_video':
      case 'youtube_shorts':
      case 'video':
        return shortsVideo;
      case 'comic':
      case 'comic_video':
        return comicVideo;
      case 'notification_promo_video':
      case 'notification':
      case 'promo_video':
      case 'promo':
        return notificationPromoVideo;
      case 'image_design':
      case 'image':
      case 'design':
      case 'design_content':
        return imageDesign;
      case 'other':
      case 'song_and_shorts':
      case 'songandshorts':
        return other;
      default:
        throw ArgumentError.value(
          raw,
          'contentSubtype',
          'unknown content subtype — refuse silent default',
        );
    }
  }

  static bool isKnown(String? raw) {
    try {
      toWorkCommercialEnum(raw);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Prefer canonical Work enum for commercial profile serialization.
  static String requireWorkCommercialEnum(String raw) {
    final v = toWorkCommercialEnum(raw);
    if (v == null || v.isEmpty) {
      throw ArgumentError('contentSubtype is required');
    }
    return v;
  }
}
