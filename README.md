# Backline

Backline is a standalone macOS host app for the **Helix Native** and **Helix Stadium Native** plugins from Line 6.  
Open Backline, play Helix. No DAW required.

## Current Status

Early development.

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).  
The Xcode project is generated from `project.yml`, and not committed to source control.

With [mise](https://mise.jdx.dev), which installs the pinned XcodeGen version:

```sh
mise install
mise run generate-project
open Backline.xcodeproj
```

Or with XcodeGen installed some other way:

```sh
xcodegen
open Backline.xcodeproj
```

### Development Team

To sign with your own Apple team, set `BACKLINE_DEVELOPMENT_TEAM` to your team ID before generating. This will stop macOS from asking for microphone access again after every rebuild.

With mise, put it in a `mise.local.toml` file at the repo root:

```toml
[env]
BACKLINE_DEVELOPMENT_TEAM = "YOUR_TEAM_ID"
```

## Trademarks

Line 6, Helix, and related product names are trademarks of Yamaha Guitar Group, Inc. They are used here only to describe compatibility.

Backline is an independent project. It is not associated with, affiliated with, endorsed by, or sponsored by Line 6 or Yamaha Guitar Group. Backline does not include any Line 6 software. Helix Native or Helix Stadium Native must be purchased and installed separately.
