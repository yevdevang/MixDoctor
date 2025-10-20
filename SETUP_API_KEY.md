# 🚨 SETUP REQUIRED: Add Your OpenAI API Key

## Quick Setup (2 minutes)

### Step 1: Get Your API Key
1. Go to: https://platform.openai.com/api-keys
2. Sign in (or create a free account)
3. Click "Create new secret key"
4. Copy the key (starts with `sk-proj-...`)

### Step 2: Add to Code
1. Open: `Core/Services/ChatGPTService.swift`
2. Find line 13:
```swift
private let apiKey = "YOUR_OPENAI_API_KEY_HERE"
```
3. Replace with your key:
```swift
private let apiKey = "sk-proj-xxxxxxxxxxxxxxxxxxxxxxxx"
```

### Step 3: Test It
1. Build and run the app
2. Import an audio file
3. Click "Analyze"
4. See ChatGPT-powered recommendations! 🎉

## That's It!
Users won't see anything related to API keys - it just works seamlessly with your key embedded in the app.

## Cost
- ~$0.005-0.015 per analysis
- Set spending limits at: https://platform.openai.com/usage

## Need Help?
Read full documentation in `CHATGPT_INTEGRATION.md`
