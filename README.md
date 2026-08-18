# Mani

A macOS scratchpad for manipulating text. Paste into the editor, reshape it, copy it out.

The bottom bar holds three menus, split by what you are trying to do.

**Format** pretty-prints and minifies JSON and XML, with options to sort JSON keys and XML attributes.

**Text** reshapes the text as text. It sorts, reverses, shuffles, deduplicates and numbers lines; normalizes line endings; removes newlines, spaces, empty lines and invisible Unicode; strips ANSI escape sequences; and converts case — upper, lower, Title, camelCase, PascalCase, snake_case, kebab-case, CONSTANT_CASE and URL slugs. Case conversion works a line at a time, so you can select a column of names and convert the lot.

**Convert** re-represents the text in another encoding: Base64, hex bytes, URL percent-encoding, HTML entities, JSON string escapes and shell backslashes, each in both directions. It also hashes with MD5, SHA-1, SHA-256 or SHA-512, decodes a JSON Web Token's header and payload into JSON, and converts between Unix timestamps and ISO 8601 dates. Paste a number and Unix Timestamp → Date infers the unit from its size, up through nanoseconds. When you know the unit and want it obeyed, the Timestamp submenu states it outright, in both directions, for seconds, milliseconds, microseconds and nanoseconds.

**Organize** rewrites the text as structured Markdown using the on-device Apple Intelligence model. It requires Apple Intelligence to be enabled, and nothing leaves the machine.

Press ⇧⌘P, or Edit > Search Commands, to open the command palette. Type to filter: your letters have to appear in the command's name in order, but not next to each other, so `fjsk` finds Format JSON (Sort Keys). Arrows or ⌃N and ⌃P move, Page Up and Page Down move by eight, Home and End jump to the ends, Return runs, Escape closes.

The app guesses what the text is, judging the selection when there is one, and offers only the commands that fit it. With JSON on screen the XML formatters grey out, and Decode JWT is offered only for something shaped like a token. The guess is a heuristic, so it defers: anything it cannot identify, including ordinary prose, leaves every command available.

Every action is undoable and applies to the selection when there is one. The status bar shows live character, word and line counts, plus a guess at what the text is (JSON, XML, HTML, JWT, Base64, hex, URL, Unix timestamp) when it recognizes the shape. Anything that can fail — invalid JSON or XML, malformed Base64, a token that is not a token — never touches your text; the error surfaces in a banner instead.

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
