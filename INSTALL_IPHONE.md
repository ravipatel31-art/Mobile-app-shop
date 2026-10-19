# 📱 How to Install Cafe POS on iPhone with iLoader

## Prerequisites
- iPhone 17 with iOS 15 or later
- iLoader app installed on iPhone
- GitHub account

## Installation Steps

### Step 1: Build the IPA
1. Go to: https://github.com/ravipatel31-art/Mobile-app-shop/actions
2. Click on "Build iOS IPA for iLoader" workflow
3. Click "Run workflow" → "main" → "Run workflow"
4. Wait 10-30 minutes for the build to complete

### Step 2: Download the IPA
1. After the build completes, go to the Actions tab
2. Click on the completed workflow run
3. Scroll down to "Artifacts" section
4. Download `cafe-pos-ipa` (this is your IPA file)

### Step 3: Install with iLoader
1. Open iLoader on your iPhone
2. Tap "Add" or "+" button
3. Select the downloaded IPA file
4. Wait for installation to complete
5. Tap "Install" to confirm

### Step 4: Trust the App
1. Go to Settings > General > VPN & Device Management
2. Find "Cafe POS" or your developer
3. Tap "Trust Cafe POS"
4. Confirm trust

### Step 5: Launch the App
1. Open iLoader
2. Find "Cafe POS" in your apps
3. Tap to launch

## Troubleshooting

### App Won't Open
- Make sure you've trusted the app in Settings
- Reinstall the IPA
- Ensure iOS is up to date

### Installation Failed
- Check that you downloaded the correct IPA
- Make sure iLoader is updated
- Try a different iOS version

### "Untrusted Developer" Error
- Go to Settings > General > VPN & Device Management
- Trust the app certificate
- Restart the app

## What You'll Get

- **App Name:** Cafe POS
- **Build Type:** IPA (for sideloading)
- **Code Signing:** None (for testing)
- **Compatible with:** iPhone 17, iOS 15+
- **Size:** ~20-50MB (proper size!)

## Quick Start

```bash
# Build the IPA on GitHub Actions
1. Go to GitHub Actions
2. Run "Build iOS IPA for iLoader"
3. Wait for completion
4. Download the IPA
5. Install with iLoader
```

## Need Help?

If you encounter issues:
1. Check the workflow logs for errors
2. Make sure you have the latest Flutter version
3. Try building locally if GitHub Actions fails

## Build Information

- **App:** Cafe POS
- **Version:** 1.0.0
- **Platform:** iOS (iPhone 17)
- **Build Type:** IPA for sideloading with iLoader
- **Signing:** Ad-hoc (for testing)

---

**Ready to install!** 🎉
