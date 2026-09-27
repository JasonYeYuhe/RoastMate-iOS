/**
 * True when `locale` means Traditional Chinese. The ONE home for this rule on
 * the Worker, mirroring the app's `AppLanguage.contentBucket`: the script
 * subtag is authoritative (Hant → yes, Hans → no), and only when it is absent
 * does the region decide (TW / HK / MO → Traditional).
 *
 * Why a region fallback is not optional: measured 2026-09-26 on an iOS 18.5
 * simulator set up as a real Taiwan phone (language zh-Hant-TW), the app's
 * `Locale.current.identifier` — which is exactly what it sends here as
 * `locale` — is "zh_TW", with NO "Hant". Hong Kong sends "zh_HK". So a check
 * for "hant" alone told every Taiwan and Hong Kong user to reply in 简体中文,
 * while the vent directive further down the same prompt said 繁體中文.
 *
 * Unicode keywords are dropped before matching. iOS appends the user's
 * calendar / first-weekday / number overrides to the identifier
 * ("zh_TW@calendar=roc" on a phone using the 民國 calendar), and the region
 * test below needs the region to end the string. v1.5.0's looser
 * `includes("tw")` happened to accept those; the review of this helper
 * caught the regression before it shipped.
 */
export function isTraditionalChinese(locale) {
  const c = (locale || "").toLowerCase().split("@")[0].replace(/_/g, "-");
  if (!c.startsWith("zh")) return false;
  if (c.includes("hant")) return true;
  if (c.includes("hans")) return false;
  return /-(tw|hk|mo)(-|$)/.test(c);
}

/**
 * The locale with any Unicode keywords removed: "zh_TW@calendar=roc" →
 * "zh_TW". Prompts never need calendar / first-weekday / measurement
 * preferences, and Foundation keeps them in `Locale.identifier` (measured
 * 2026-09-27: "zh_TW@calendar=roc" is 18 characters, and a few overrides
 * together reach 40). Before this, `validate` capped the RAW identifier at 16
 * characters, so any user with such an override got 400 invalid_locale and
 * the app fell back to local output — Vent silently never reached the cloud.
 */
export function baseLocale(locale) {
  return String(locale).split("@")[0].trim();
}
