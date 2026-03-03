# Word of the Day (iOS + Widget)

SwiftUI iOS app where the user chooses a language and fetches a daily word.

- Primary source: Google Gemini API
- Fallback source: internet fetch (random Wikipedia word + translation)
- Widget: shows latest saved word from the app
- Difficulty levels: Easy / Medium / Hard
- Theme modes: System / Light / Dark
- Daily behavior: one automatic word per day (stays fixed that day unless user taps `Get New Word`)

## 1) Prerequisites

- Xcode 15+
- Homebrew
- XcodeGen

Install XcodeGen:

```bash
brew install xcodegen
```

## 2) Configure secrets

Create your local secrets file:

```bash
cp Config/Secrets.xcconfig.template Config/Secrets.xcconfig
```

Set your Gemini API key in `Config/Secrets.xcconfig`:

```xcconfig
GEMINI_API_KEY = your_real_key
```

## 3) Configure identifiers

Update these placeholders before building:

- Bundle IDs in `project.yml`
- App Group ID in:
  - `project.yml`
  - `Shared/AppConfig.swift`
  - `WordOfTheDayApp/WordOfTheDayApp.entitlements`
  - `WordOfTheDayWidget/WordOfTheDayWidget.entitlements`

Use one consistent value, for example: `group.com.yourcompany.wordoftheday`.

## 4) Generate and open project

```bash
xcodegen generate
open WordOfTheDay.xcodeproj
```

In Xcode:

1. Assign your Apple Team for both targets.
2. Add `Config/Secrets.xcconfig` as a Base Configuration for Debug/Release on the app target.
3. Build and run the app on device/simulator.
4. Add the widget to the home screen.

## 5) How it works

- `WordOfTheDayApp`: language picker + difficulty picker + theme picker + fetch button
- Word card shows:
  - meaning
  - characteristics (part of speech, CEFR, register, usage tip)
  - one example sentence at a time with English translation
- `Shared/WordProvider.swift`:
  - `GeminiWordProvider` calls Gemini with difficulty-aware prompt and asks for strict JSON
  - Gemini JSON includes translated examples and characteristics
  - `CommonEverydayWordProvider` provides very easy daily-life fallback words for Easy mode
  - `WikipediaWordProvider` is a final fallback internet source
- `Shared/WordStore.swift`: writes selected language and last word to shared `UserDefaults` (App Group)
- `WordOfTheDayWidget`: reads shared data and renders the widget

## Notes

- If Gemini key is missing, fallback internet mode still works.
- Widget refreshes when the app fetches a new word.
