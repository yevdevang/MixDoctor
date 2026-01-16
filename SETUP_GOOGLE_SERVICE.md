# GoogleService-Info.plist Setup

## Important Security Notice

**Never commit `GoogleService-Info.plist` to version control!** This file contains sensitive API keys.

## Setup Instructions

1. Copy the template file:
   ```bash
   cp GoogleService-Info.plist.template MixDoctor/GoogleService-Info.plist
   ```

2. Get your Firebase credentials:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: `mixdoctor-6a0e6`
   - Go to Project Settings → General
   - Download the `GoogleService-Info.plist` file

3. Replace the template file:
   - Replace `MixDoctor/GoogleService-Info.plist` with the downloaded file from Firebase

4. Verify the file is ignored:
   - Check that `GoogleService-Info.plist` is listed in `.gitignore`
   - The file should NOT appear in `git status`

## If You've Already Committed the File

If you've already committed `GoogleService-Info.plist` with real keys:

1. **Immediately rotate your API keys** in Firebase Console:
   - Go to Firebase Console → Project Settings → General
   - Regenerate API keys

2. Remove from git tracking (but keep local file):
   ```bash
   git rm --cached MixDoctor/GoogleService-Info.plist
   git commit -m "Remove GoogleService-Info.plist from version control"
   ```

3. Add to .gitignore (already done):
   - `GoogleService-Info.plist` is now in `.gitignore`

4. Update your local file with new keys from Firebase Console

## Security Best Practices

- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Use template files for documentation
- ✅ Rotate keys if they've been exposed
- ✅ Never hardcode API keys in documentation
- ✅ Use environment variables or secure config files for keys
