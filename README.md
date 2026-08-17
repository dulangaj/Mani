# Mani

A macOS scratchpad for manipulating text. Paste into the editor, reshape it, copy it out.

**Format** pretty-prints and minifies JSON and XML, with options to sort JSON keys and XML attributes.

**Replace** removes newlines or spaces, unescapes JSON and shell strings, strips ANSI escape sequences, decodes URLs, strips invisible Unicode, and changes case.

**Organize** rewrites the text as structured Markdown using the on-device Apple Intelligence model. It requires Apple Intelligence to be enabled, and nothing leaves the machine.

Every action is undoable and applies to the selection when there is one. The status bar shows live character and line counts. Invalid JSON or XML never touches your text; errors surface in a banner instead.

## Build it yourself

```bash
scripts/build.sh --install
```

That compiles the app, signs it **ad hoc** (`codesign -s -`), and copies it to `/Applications`. Drop `--install` to leave the app in `./build`. Run `scripts/build.sh --test` to run the unit tests.

Requirements: macOS 26 or later and the full Xcode app, since `xcodebuild` needs it to compile the asset catalog.

No Developer ID or notarization is needed. macOS only gatekeeps apps that arrive quarantined from the internet, so an app built on your own machine launches normally and keeps working indefinitely.

To sign with your own credentials instead:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
```

Rebuilding produces a new ad-hoc signature, so macOS treats the app as a fresh binary. Any granted privacy permissions may be asked for again.

## Sandbox

The app runs in the App Sandbox with hardened runtime enabled. It has no network entitlement; everything happens on-device.
