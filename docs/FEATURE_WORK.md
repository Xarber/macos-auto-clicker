# Fork feature work

The fork retains the upstream MIT license and attribution. The first batch adds an opt-in random cursor movement setting (upstream issue #79) and a toggle shortcut when the separate stop shortcut is cleared (#89). Random movement samples points inside a circle around the cursor position at start, at a configurable interval; points outside connected displays are rejected. It stops with the click session. It is not intended to evade detection, and movement is discrete rather than a smooth trajectory. Settings are applied at the next start.

Synthetic movement is marked so that the existing stop-on-movement monitor can distinguish it from user movement. This interaction, multiple displays, and Accessibility behavior require real-device validation.

The permissions view gives recovery guidance for stale macOS Accessibility entries. The build no longer runs `tccutil reset` against the user's existing grant. This does not prove or fix the cause of every denied Accessibility request.

`fork-build.yml` builds a macOS artifact for feature branches and manual runs, without publishing a release. Artifacts are ad-hoc signed, not notarized. Do not replace an existing installation until the artifact and real Accessibility interaction have been verified; changing the app signature may require the user to reauthorize it.

Outstanding upstream requests include idle activation, hold-to-run and hold input, fixed coordinates, sequences, update checks, and other distribution and localization requests. A macOS App Store build or notarization requires an authorized Apple signing identity. Upstream's existing dynamic menu icon setting addresses #65 in the current source; it still needs runtime confirmation.

## Timing and movement correction

Random intervals now schedule a new one-shot timer for every press; the displayed final time in range mode is an estimate. The completion notification is scheduled when the final press occurs. Reversed range endpoints are accepted safely.

When movement is enabled, the initial cursor position is captured once. A click-through circle shows the fixed area until the session stops. Movement begins immediately and then uses the configured interval; generated positions are restricted to that circle and connected display bounds. If the user moves outside the circle, an automated mouse click first returns to the center; the user can still move the mouse freely to retain control and use stop-on-movement. The circle is expressed in macOS screen points (which need not equal physical pixels on Retina displays). Display changes, full-screen windows, and the interaction with stop-on-movement require validation on real hardware.

## Interface redesign

The main window groups click setup, cursor area, run controls, and live session status. Fixed and random timing can be selected alongside their values; cursor movement settings are also accessible directly. The existing input recorder, duration selector, themes, keyboard shortcuts, notifications, menu bar, and settings remain in use. The permission screen now presents the request and recovery steps as a focused task. The layout uses native SwiftUI controls, adapts to window resizing and supports scrolling.

The redesign retains the existing theme system and macOS 13 minimum; it does not claim use of system Liquid Glass. New interface labels include English, German and Latin American Spanish translations. Settings content scrolls and theme choices expose their names to accessibility. Visual accessibility, dark/light themes, translations in context, and real-device interaction require further verification.

## Movement and countdown

Cursor movement uses a short eased quadratic path. Its control points remain in the session circle, and paths abort if they cross a display gap. The radius slider displays a temporary circle centered at the cursor when editing begins; it disappears when slider editing ends. The active session captures its own center at start. Manual pointer movement remains possible.

The main view displays a countdown based on the next scheduled click. Its floating countdown button minimizes the main window and opens a small always-on-top panel; closing or expanding the panel restores the main window. The panel shows Ready once clicking finishes. Real-device testing of movement, previews, multi-display behavior and window lifecycle remains required.

The radius slider has no tick marks and shares its value with the numeric field. Its preview window resizes in place. The floating countdown initially appears at the upper-right of the main window's screen, within the visible desktop area.
