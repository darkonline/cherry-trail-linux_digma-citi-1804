// Digma CITI 1804 (Atom x5-Z8350, Cherry Trail): make YouTube use H.264 with VA-API hardware decoding.
// Remove this file to return to Firefox defaults.
user_pref("media.av1.enabled", false);
user_pref("media.mediasource.vp9.enabled", false);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
