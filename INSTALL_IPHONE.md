# How to Build & Install the Cafe POS iPhone App (IPA)

This project builds a **sideloadable iOS IPA** automatically with GitHub Actions.
No Mac and no Apple Developer account required.

## What you get

A proper **~20–50 MB** `.ipa` file that you install on your iPhone with a
sideloading app (iLoader, AltStore, Sideloadly, or Scarlet).

## Why the old 6 KB file was broken

`flutter build ipa --no-codesign` still runs Xcode's archive+export pipeline,
which **requires a `DEVELOPMENT_TEAM`** (a paid Apple Developer account).
Without one, the export fails and produces an empty/invalid IPA.

This project instead uses:

```
flutter build ios --release --no-codesign     # produces Runner.app, no Apple account needed
zip -r app.ipa Payload                        # wrap Runner.app in Payload/ to make a real .ipa
```

This is the standard way to build an unsigned, sideloadable Flutter IPA.

## Step 1 — Run the workflow

1. Open **https://github.com/ravipatel31-art/Mobile-app-shop/actions**
2. In the left sidebar click **Build iOS IPA (unsigned — for sideloading)**
3. Click **Run workflow → Run workflow** (branch: `main`)
4. Wait ~10–20 minutes. The run turns green when done.

> The workflow also runs automatically whenever you push changes to `mobile/`.

## Step 2 — Download the IPA

1. Click the finished workflow run.
2. Scroll to the **Artifacts** section at the bottom.
3. Download **`cafe-pos-ipa`** — this is a `.zip` containing your IPA.
4. Unzip it. You get **`cafe-pos-unsigned.ipa`**.

## Step 3 — Get the IPA onto your iPhone

Pick one:

- **AirDrop** — send the `.ipa` to your iPhone (easiest if you're on a Mac).
- **Files app** — save it to iCloud Drive / On My iPhone, then open from Files.
- **iLoader / Sideloadly** — these tools also let you transfer directly.

## Step 4 — Install with iLoader

1. Open **iLoader** on your iPhone.
2. Tap **+ / Add** and select `cafe-pos-unsigned.ipa`.
3. Tap **Install** and wait.
4. When prompted, sign in with your **Apple ID** (this re-signs the app for your device).

## Step 5 — Trust the app

1. Go to **Settings → General → VPN & Device Management**.
2. Under your Apple ID, tap **Trust**.
3. Confirm.

## Step 6 — Launch

Open **Cafe POS** from your home screen.

## Important: 7-day expiry

An unsigned IPA signed with a **free Apple ID** expires after **7 days**.
When it stops opening:

1. Delete the app.
2. Re-run the workflow (or reuse the IPA).
3. Re-install with iLoader.

A **paid Apple Developer account ($99/yr)** extends this to **1 year**.

## Troubleshooting

| Problem | Fix |
|---|---|
| Workflow fails | Open the run → click the failed step → read the log. Most common: Flutter version drift. |
| IPA is still tiny | The build didn't finish. Re-run the workflow; check the "Verify IPA" step log. |
| "Untrusted Developer" | Settings → General → VPN & Device Management → Trust. |
| App won't open after 7 days | It expired. Delete and re-install (see above). |
| App opens but can't reach server | The app talks to `https://mobileapp.unonomercysound.online`. Make sure that backend is running. |

## Files in this repo

- `.github/workflows/build-ios-unsigned.yml` — the sideloadable IPA build (the one you want)
- `.github/workflows/build-ios.yml` — signed TestFlight/App Store build (needs Apple Developer secrets; optional)
