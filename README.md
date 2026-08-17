# Mani

A macOS scratchpad for manipulating text. Paste into the editor, then use
**Format** (pretty-print or minify JSON, pretty-print XML) and **Replace**
(remove newlines or spaces, unescape JSON/shell strings, strip ANSI escape
sequences, decode URLs, strip invisible Unicode, change case) to reshape it.
Every action is undoable and applies to the selection when there is one.
The status bar shows live character and line counts. Invalid JSON or XML
never touches your text — errors surface in a banner instead.

## Build it yourself

```bash
scripts/build.sh --install
```

That compiles the app, signs it **ad hoc** (`codesign -s -`), and copies it to
`/Applications`. Drop `--install` to leave the app in `./build`. Run
`scripts/build.sh --test` to run the unit tests.

Requirements: macOS 26 or later and Xcode (the full app — `xcodebuild` needs it
to compile the asset catalog).

There is no Developer ID and no notarization here, and none is needed: macOS
only gatekeeps apps that arrive quarantined from the internet. An app you built
on your own machine launches normally and keeps working indefinitely. To sign
with your own credentials instead, pass them through the environment:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
```

Rebuilding produces a new ad-hoc signature, so macOS treats the app as a fresh
binary; any granted privacy permissions may be asked for again.

## Sandbox

The app runs in the App Sandbox with hardened runtime enabled. It has no
network entitlement — everything happens on-device.
