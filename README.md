# Twi Bible — fearGod

Bilingual Bible app: KJV English + Akuapem Twi side by side.

## Building

```bash
xcodegen generate
xcodebuild -scheme fearGod -destination "platform=iOS Simulator,name=iPhone 17" build
```

## Data

- KJV: public domain
- Twi: Biblica® Open Akuapem Twi Contemporary Bible™ © 1996, 2020 Biblica, Inc. — CC BY-SA 4.0
- 31,100 verses, 99% Twi coverage across all 66 books

## Roadmap

- v1.0 — side-by-side reading (English / Twi)
- v2.0 — TTS with sentence + word highlight (Speechify-style)
