# Field Coordinator Training Guide

For coordinators demoing AgriSense AI to farmers and helping with first-time setup. This
describes what the app actually does as of Week 12 — not aspirational features from the project
plan that haven't been built yet. If something below doesn't match what you see on a device,
the device is likely running an older build; check with the project team before troubleshooting
further.

## 1. What AgriSense AI does, in one sentence per feature

| Feature | What it does | What it needs |
|---|---|---|
| Crop disease scan | Photograph a leaf, get a diagnosis + treatment advice in seconds | Nothing — works fully offline |
| Weather advisory | Spray-window and rain warnings for the farmer's location | Internet, when it runs |
| Mandi price comparison | Compares live prices across nearby markets for a crop | Internet, when it runs |
| Voice commands | Tap the mic, say "scan" / "prices" / "weather" to navigate | Nothing — on-device |
| "Hear Advice" | Reads the diagnosis and treatment aloud in the farmer's language | Nothing — on-device |
| SMS / voice-call fallback | Crop + symptom menu over text or a phone call, for farmers without the app | A basic phone, no smartphone or app needed |
| Feedback | "Was this diagnosis right? Did the treatment help?" on a past scan | Nothing to record it; needs internet to sync |

The scan, voice command, and "Hear Advice" features work with **no signal at all** — this is the
single most important thing to communicate to a farmer with unreliable connectivity. Weather,
prices, and syncing scans/feedback to the shared backend need a connection, but the app queues
that work and retries automatically once one is available — nothing is lost by staying offline.

## 2. Demo script (5-10 minutes)

1. **Open the app.** Point out the language selector (globe icon, top right) first — switch it
   to the farmer's language before doing anything else, so the rest of the demo is legible to
   them.
2. **Tap "Capture Photo."** Photograph a real leaf if one's nearby (a healthy one is fine for a
   demo — it doesn't need to be diseased). The result screen appears with no visible delay;
   this is the point to say "this just happened without using any internet."
3. **Point out the confidence, crop, and urgency badges**, and read the treatment section aloud
   (or tap "Hear Advice in [language]" to let the app do it).
4. **Go back and show Recent Scans** — explain that scans are saved on the phone even before
   they sync, and show the sync status line ("N scan(s) waiting to sync" / "All scans synced").
5. **Tap the mic icon** and say "prices" to show voice navigation, or tap "prices" in the
   bottom nav directly if voice recognition struggles in a noisy field environment (it's on-device
   and short-vocabulary — see §4 for likely failure modes).
6. **If revisiting an earlier scan**: tap it, scroll down, tap "Give Feedback" — this is worth
   demonstrating once so the farmer knows the option exists for later, once they've actually
   tried a treatment and know whether it worked.

## 3. First-time setup checklist

- [ ] Set the farmer's language via the globe icon before handing over the phone.
- [ ] Do one practice scan together — this is the best way to confirm the camera and gallery
      permissions were actually granted (Android will prompt on first use).
- [ ] Show the farmer where "Recent Scans" is, so they know their history persists.
- [ ] If the farmer doesn't have a smartphone, or won't reliably have one on hand in the field,
      note their phone number for the SMS fallback path instead — see §5.
- [ ] Explain that scans made offline sync automatically the next time the phone has a signal —
      no manual step is required, though a "Sync Now" button exists if they want to force it
      (useful right before you leave a low-signal area, if they want to confirm a scan saved
      before you're both out of reach).

## 4. Common issues and what to do about them

| Symptom | Likely cause | What to do |
|---|---|---|
| Camera permission denied, capture does nothing | Android permission was denied on first prompt | Guide the farmer to Settings → Apps → AgriSense AI → Permissions → Camera, enable it |
| Diagnosis confidence is low / "Detected" badge looks wrong on an obviously healthy leaf | Photo is blurry, poorly lit, or shows too little of the leaf | Retake with the leaf filling more of the frame, in daylight, held flat |
| Voice command not recognized | Background noise, or the farmer's phrasing doesn't match the app's fixed keywords ("scan"/"prices"/"weather") | Fall back to tapping the bottom nav directly — voice is a shortcut, not the only path to any feature |
| "N scan(s) waiting to sync" never clears | No signal reached yet, or the backend is unreachable | Not a bug — it will clear automatically once connectivity returns; tapping "Sync Now" retries immediately if you want to check |
| Weather / prices screen shows nothing or an error | No signal, or these features specifically need it (unlike scanning) | Explain the offline/online split from §1 — this is expected, not broken |
| Farmer wants advice but has no smartphone at all | — | Use the SMS/voice-call fallback (§5) instead of the app |

## 5. SMS / voice-call fallback, for farmers without the app

This works from any basic phone, no data connection needed:

- **Text a photo-free description**: reply to the menu prompts — crop, then what the leaf looks
  like — and get treatment advice back as a text message.
- **Call the same number**: an automated voice menu asks the same two questions via keypad
  presses and reads the advice aloud.

This is deliberately a simpler, lower-precision version of the photo-based diagnosis (a
two-question triage rather than a specific disease match) — the plan's own guidance was that a
text/voice-only menu should never exceed 3 options, which trades precision for reachability on
purpose. Tell the farmer this upfront so they don't expect photo-level accuracy from a text
conversation.

## 6. What a coordinator should escalate rather than try to fix

- The app crashing on launch, or repeatedly failing to open the camera even after permissions
  are confirmed granted.
- A diagnosis that's confidently and obviously wrong on a clear, well-lit photo (this is useful
  signal for the retraining pipeline — encourage the farmer to leave feedback via "Give Feedback"
  on that scan either way, since that's exactly what it's for).
- Any request for a feature not in the table in §1 — don't promise functionality that doesn't
  exist yet.

## 7. What this guide doesn't cover

Coordinator recruitment, training logistics for coordinators themselves (as opposed to the
content they'll deliver), and village-specific rollout planning are outside this document's
scope — see [village-selection-checklist.md](village-selection-checklist.md) and
[README.md](README.md) in this folder for why those aren't filled in here.
