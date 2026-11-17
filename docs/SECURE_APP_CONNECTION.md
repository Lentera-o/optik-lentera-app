# OPTIK LENTERA — Secure app connection checklist

This document describes the remaining setup required before enabling direct in-app transactions. It does not change the live Apps Script deployment or spreadsheet.

## Current implementation status

- The Flutter app still opens prefilled Google Forms for order and payment entry. It does not yet submit transactions directly.
- `ApiService.createOrder` and `ApiService.createPayment` provide the HTTP transport, but the transaction screens are not wired to them.
- `OptikLenteraApi.gs` validates Google ID tokens and active staff, then delegates to the existing `olProcessOrder_` / `olProcessPayment_` functions.
- The legacy processors use the existing invoice, receipt, numbering, and PDF workflows. They store internal event keys to recover retries.
- The app currently reads spreadsheet tabs through the Google Visualization CSV endpoint. Before production use, verify the spreadsheet's sharing and publish settings; if those expose customer data, replace these reads with authenticated Apps Script reads.

## Required Android / Google OAuth setup

1. Create and retain a stable Android release signing key outside the repository and CI logs. Do not use the CI debug signing key for production identity.
2. Record the SHA-1 certificate fingerprint for that release key.
3. In the same Google Cloud project used for the app, register an Android OAuth client with:
   - Package: `com.optiklentera.optik_lentera`
   - SHA-1: the fingerprint of the stable release signing certificate.
4. Register or identify the Web application OAuth client. The Web client ID is used as the ID-token audience/server client ID.
5. Configure the Apps Script project's Script Properties:
   - `OL_GOOGLE_WEB_CLIENT_ID`: exact Web OAuth client ID.
   - `OL_GOOGLE_ANDROID_CLIENT_ID`: exact Android OAuth client ID.
6. Add only approved staff email addresses with status `AKTIF` in the existing staff settings sheet.
7. Keep OAuth client IDs as configuration, not secrets. Never embed a client secret, shared password, or service-account private key in the APK.
8. Configure Google Sign-In in Flutter to request an ID token for the Web client ID. Confirm that the resulting token has the expected `aud` (Web client) and `azp` (Android client) claims before enabling writes.

## Transaction request contract

Order:
- `action`: `createOrder`
- `requestId`: one stable unique ID per user submission; reuse it only when retrying that same submission.
- `idToken`: freshly obtained Google ID token.
- `data`: `orderDate`, `name`, `phone`, `address`, `doctor`, OD/OS prescription fields, `lensType`, `rxNote`, `frameDescription`, `framePrice`, `lensDescription`, `lensPrice`, `otherDescription`, `otherPrice`, `initialPayment`, `initialPaymentMethod`, `note`.

Payment:
- `action`: `createPayment`
- `requestId`: one stable unique ID per user submission; reuse it only when retrying that same submission.
- `idToken`: freshly obtained Google ID token.
- `data`: `invoice`, `paymentDate`, `amount`, `method`, `category`, `note`.

## Release gates

- [ ] Stable release keystore created and stored securely outside source control.
- [ ] Android OAuth client registered against the release package and SHA-1.
- [ ] Web OAuth client ID and Android OAuth client ID configured in Apps Script Script Properties.
- [ ] Google Sign-In implemented and verified on a real Android build.
- [ ] Staff allowlist and active status verified.
- [ ] Flutter order screen calls `createOrder` and displays returned invoice/PDF details.
- [ ] Flutter payment screen calls `createPayment` and displays returned receipt/PDF and balance.
- [ ] Duplicate-submit/retry behavior tested using a non-production test spreadsheet and test Drive folder.
- [ ] Spreadsheet read access moved behind authenticated Apps Script endpoints, or sharing settings explicitly reviewed and approved.
- [ ] Apps Script Web App deployment updated only after explicit owner approval.
- [ ] Final release build signed with the stable release key.

## Safety rules

- Do not run dummy transactions against production customer records.
- Do not change spreadsheet sharing, publish settings, triggers, Forms, folders, or Script Properties without owner approval.
- Do not merge the integration PR or deploy Apps Script changes without owner approval.
- Do not claim direct in-app transactions are ready until the release gates above have been verified.
