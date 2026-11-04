# LevelSet

LevelSet is an iPhone app that makes you earn your screen time. When your
daily budget runs out, the app locks, and the only way to get more time is to
finish a physical challenge, like push-ups verified by the camera, or to spend
XP you've already earned.

The same balance carries over to your computer: a web dashboard and a Chrome
extension spend your earned time on the websites you choose to restrict.

## Features

- **Camera-verified challenges.** Push-ups, jumping jacks, wall sits and
  planks are tracked on device with Apple's Vision framework. Push-ups are
  validated by Core ML models trained on recorded pose data. Reps only count
  after a full range of motion with good form. Video never leaves the phone.
- **Daily time budget** with streaks, XP, adaptive difficulty and four
  unlockable themes that also change the app icon.
- **Lock Screen widgets** with ActivityKit and WidgetKit.
- **Cross-device screen time.** Link a computer by scanning a QR code. A
  Chrome extension deducts earned time while you're on restricted sites and
  locks them when your balance reaches zero.

## Repository layout

| Path | What it is |
| --- | --- |
| `LevelSet/` | iOS app (Swift, SwiftUI, AVFoundation, Vision) |
| `LevelSetWidgets/` | Lock Screen and Live Activity widgets |
| `Shared/` | Code shared by the app and the widgets |
| `Training/` | Push-up model trainer and recording guide, see [`Training/README.md`](Training/README.md) |
| `project.yml` | XcodeGen project definition |
| `web-ecosystem/nextjs-dashboard/` | Next.js dashboard and API, deployed on Vercel |
| `web-ecosystem/browser-extension/` | Chrome extension (Manifest V3) |
| `web-ecosystem/supabase/schema.sql` | Supabase PostgreSQL schema |

## Building the iOS app

Requirements: Xcode 15 or later, iOS 17 or later, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open LevelSet.xcodeproj
```

Select your own development team under Signing & Capabilities, and change the
bundle identifier if needed. Camera tracking needs a real device.

## Running the web services

See [`web-ecosystem/README.md`](web-ecosystem/README.md) for the Supabase,
Vercel and Chrome extension setup. You'll need your own Supabase project. No
keys are included in this repository.

## Security

See [`SECURITY.md`](SECURITY.md) for how to report a vulnerability.

## License

LevelSet is Copyright (c) 2026 pratyushsh99 and released under the [MIT License](LICENSE).

If you use, modify or redistribute this project, or any substantial part of it, you must keep the copyright notice and include the full MIT License text in every copy, including in the documentation of any app, website or product built from it. See the [Terms of Service](LevelSet/Legal/TermsOfService.txt) and [Privacy Policy](LevelSet/Legal/PrivacyPolicy.txt).
