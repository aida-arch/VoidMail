# Void Mail

A minimal, dark-mode-first iOS mail client inspired by Spark, Canary Mail, and Newton Mail.

## Setup

### Option A: Xcode Project (Recommended)
1. Open Xcode → File → New → Project → iOS App
2. Name: `VoidMail`, Interface: SwiftUI, Language: Swift
3. Delete the auto-generated files
4. Drag the `VoidMail/` folder into the project navigator
5. Add Google Sign-In SDK via SPM: `https://github.com/google/GoogleSignIn-iOS.git`

### Option B: XcodeGen
```bash
brew install xcodegen
cd VoidMail
xcodegen generate
open VoidMail.xcodeproj
```

### Option C: Swift Package
```bash
cd VoidMail
open Package.swift
```

## Google Sign-In Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project and enable Gmail API + Calendar API
3. Create OAuth 2.0 credentials (iOS type)
4. Add your Client ID to `VoidMailApp.swift` and `Info.plist`
5. Uncomment the Google Sign-In code in `GoogleAuthService.swift`

## Architecture
- **SwiftUI** with MVVM pattern
- **Design System**: Custom dark theme (Colors, Typography, Components)
- **Services**: GoogleAuth, Gmail API, Calendar API
- **Demo Mode**: Runs with sample data out of the box

## Features
- Smart Inbox with Priority/Updates/Newsletters tabs
- AI-powered email summaries
- Integrated Google Calendar
- Helix-o1 AI assistant with smart alerts
- Compose with AI draft generation
- Swipe actions (archive, snooze, delete)
- Pull to refresh
- Privacy-first settings
