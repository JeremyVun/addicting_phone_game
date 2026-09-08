/// Build-time configuration. Everything here that reads `REPLACE_ME` must be
/// filled in by the owner before a store build (see `docs/contracts/monetisation.md`).
library;

const String kPrivacyPolicyUrl = 'https://REPLACE_ME/settle/privacy';

const String kAnalyticsProject = 'settle';
const String kAnalyticsUrlEnv = 'SETTLE_ANALYTICS_URL';
const String kAnalyticsKeyEnv = 'SETTLE_ANALYTICS_KEY';

const String kAnalyticsUrl = String.fromEnvironment(kAnalyticsUrlEnv);
const String kAnalyticsKey = String.fromEnvironment(kAnalyticsKeyEnv);

/// Debug drives only: makes UMP believe the device is in the EEA so the consent
/// form can be screenshotted on an emulator.
const bool kForceEeaConsent = bool.fromEnvironment('SETTLE_FORCE_EEA');

/// The hashed id UMP prints to logcat, when the emulator is not auto-detected.
const String kConsentTestDeviceId = String.fromEnvironment(
  'SETTLE_CONSENT_TEST_DEVICE',
);

/// Debug drives only: selects the fakes instead of AdMob and Play Billing.
const bool kFakeServices = bool.fromEnvironment('SETTLE_FAKE_SERVICES');
