# Kelime: Turkish Word of the Day (iOS app + lock screen widget)

A new everyday Turkish word every morning at **7:00**, on your lock screen.
Tap the widget to open the app with the meaning, a usage tip and example
sentences (each can be read aloud with the Turkish system voice).

- **361 hand-picked words**: daily expressions (*kolay gelsin*, *geçmiş olsun*),
  core verbs, adjectives and adverbs, everyday nouns, and useful B1–B2 words for
  work and conversation. Each has 4 natural example sentences with translations.
- **Never repeats**: the word list is stored in a fixed random order and day N
  shows word N, so every word appears exactly once until the whole list has been
  shown (about a year). The app's **Past words** screen lists everything shown so far.
- **Next word**: want more than one a day? Tap **Next word** under today's word
  to move on right away (the widget follows). It just takes the next word in the
  list, so nothing repeats, and tomorrow's word still arrives at 7:00. The taps
  are shared with the widget through the App Group `group.com.miqdam.wordoftheday`.
- **Widgets**: lock screen (rectangular + inline) and home screen (small + medium).
  The timeline schedules the next seven 07:00 changes ahead of time, so the word
  switches on time even if iOS delays the widget refresh.
- Works fully offline and builds with a free Apple ID (Personal Team).

## Build and install

```bash
brew install xcodegen
xcodegen generate
open WordOfTheDay.xcodeproj   # choose your iPhone and press Run
```

Or from the command line (replace the device IDs with yours from
`xcrun devicectl list devices`):

```bash
xcodebuild -project WordOfTheDay.xcodeproj -scheme WordOfTheDayApp -configuration Release \
  -destination 'id=<hardware UDID>' -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <device id> \
  build/Build/Products/Release-iphoneos/WordOfTheDayApp.app
```

The first time, trust the developer on the phone: **Settings → General →
VPN & Device Management → Apple Development: <your Apple ID> → Trust**.

Then long-press the lock screen → **Customize** → **Lock Screen** → tap the
widget area under the clock → **Kelime** and add **Word**, then **Sentence**
next to it. iOS caps a single lock screen widget at half the row, so the two
tiles together fill it from edge to edge: the word and meaning on the left,
an example sentence on the right.

> Apps signed with a free Personal Team expire after **7 days**. Re-run the
> build/install to refresh it. Your place in the word schedule is kept because
> it is based on the date, not on stored data.

## Adding words

Words live in `tools/word-source/*.txt`:

```
word | meaning | noun/verb/adjective/adverb/expression | A1-B2 | usage tip
  Turkish example sentence = English translation
```

Run `python3 tools/build_words.py` to regenerate
`Shared/WordData/turkish_words.json`. The script is append-only: existing words
keep their place in the schedule and new words are shuffled onto the end, so
nothing that was already shown comes back. It refuses to remove a word that has
already been scheduled.

## Code

- `Shared/DailySchedule.swift`: which word belongs to which day (7:00 rollover,
  no repeats), shared by the app and the widget
- `Shared/Word.swift`: word model and JSON loading
- `WordOfTheDayWidget/`: WidgetKit extension
- `WordOfTheDayApp/`: SwiftUI app (today's word, past words, text-to-speech)
- `tools/make_icon.py`: regenerates the app icon
