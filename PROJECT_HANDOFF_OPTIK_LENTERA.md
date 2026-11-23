# OPTIK LENTERA — Project Handoff

Updated: 2026-11-19

## Non-negotiable baseline rules
- The user's official reference APK is `base.apk`, uploaded on 2026-11-19.
- Treat that APK as the immutable baseline. Never overwrite it or modify it in place.
- Make a separate working copy for every experiment.
- Preserve existing transaction flows, customer data, Google Sheets integration, and all already-working configuration.
- Only make targeted changes for confirmed issues. Do not rebuild or reconfigure unrelated parts.
- Before delivering any modified APK, compare it against the baseline and test the affected flow plus key existing flows.

## Repository / CI context recorded in the conversation
- Repository: `Lentera-o/optik-lentera-app`
- Earlier CI run: #439
- Earlier branch: `fix/official-drive-documents`
- Earlier commit: `80f06569a25d9633c9515da51cb84c6c288296fe`
- Earlier PR: #13
- Earlier workflow artifact: `optik-lentera-release-apk`, artifact ID `14537015682`
- The earlier CI artifact is NOT confirmed to be identical to the user's official `base.apk`. Do not substitute it for the baseline without a byte-for-byte comparison.

## Uploaded APK identity recorded earlier
A separate upload named `app-release (1) (1).apk` was inspected in a prior work session:
- Size: 43,068,765 bytes
- SHA-256: `fcd6e887f5e51f8cba69072a37527760e2c348e11aeda7eec5741d4d21050a14`
- This file was NOT confirmed to be the official `base.apk`. Do not label or use it as the baseline.

## Important limitation / current status
This handoff preserves decisions and known repository context, not the APK binaries or the original Flutter analysis artifacts. At the time this note was written, the current execution workspace did not contain `base.apk` or the previously inspected APK, so no APK binary was uploaded by this commit. Do not claim the baseline binary is backed up until its presence in GitHub Releases/LFS or another durable artifact store is verified.

## Continuation checklist
1. Locate and preserve the official `base.apk` as an immutable binary artifact.
2. Recover or recreate the original Flutter analysis only from actual source/artifacts; clearly label anything reconstructed.
3. Record each confirmed defect, exact affected file/component, proposed minimal fix, and regression checks here or in a linked issue.
4. Never overwrite the baseline; keep working builds and test results separately.
