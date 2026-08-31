// Apple transaction JWS verifier — Track M M.1 (v1.3).
// ---------------------------------------------------------------------------
// Wraps Apple's OFFICIAL @apple/app-store-server-library SignedDataVerifier (it
// does the x5c chain validation against Apple's root, signature check, bundleId
// + environment checks). Server-side only — this never ships in the iOS binary,
// so the client's "no third-party SDK" privacy moat is untouched. Requires the
// `nodejs_compat` Workers flag (the library uses Buffer + node:crypto).
//
// Not exercised by the unit tests (they inject a double). It needs a runtime
// check on the Workers runtime + a real sandbox Pro JWS before it gates real Pro.

import { SignedDataVerifier, Environment } from "@apple/app-store-server-library";

// Apple Root CA - G3 (DER, base64). Public trust anchor for StoreKit 2 JWS
// chains. SHA-256 fp 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:
// 6F:30:17:B3:A8:C4:88:C3:65:3E:91:79. Fetched from
// https://www.apple.com/certificateauthority/AppleRootCA-G3.cer (2026-08-31).
const APPLE_ROOT_CA_G3_B64 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";

// RoastMate's numeric App Store app id (public; in the App Store URL). Required
// by the library to bind PRODUCTION transactions to this app.
const DEFAULT_APP_APPLE_ID = 6769317103;

let cached = null;

/**
 * Build (once, cached) a verifier exposing `verifyAndDecodeTransaction(jws)`.
 * Tries PRODUCTION first, then SANDBOX (TestFlight / dev transactions verify
 * under the sandbox environment), matching the same contract auth.js expects.
 */
export function buildVerifier(env) {
  if (cached) return cached;
  const bundleId = (env && env.APP_BUNDLE_ID) || "yyh.roastmate.app";
  const appAppleId = env && env.APP_APPLE_ID ? Number(env.APP_APPLE_ID) : DEFAULT_APP_APPLE_ID;
  const roots = [Buffer.from(APPLE_ROOT_CA_G3_B64, "base64")];
  const enableOnlineChecks = false; // no OCSP/CRL round-trip at the edge

  const prod = new SignedDataVerifier(roots, enableOnlineChecks, Environment.PRODUCTION, bundleId, appAppleId);
  const sandbox = new SignedDataVerifier(roots, enableOnlineChecks, Environment.SANDBOX, bundleId, appAppleId);

  cached = {
    async verifyAndDecodeTransaction(jws) {
      try {
        return await prod.verifyAndDecodeTransaction(jws);
      } catch (_e) {
        return await sandbox.verifyAndDecodeTransaction(jws);
      }
    },
  };
  return cached;
}
