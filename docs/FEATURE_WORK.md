# Fork feature work

The fork retains the upstream MIT license and attribution. The first batch adds an opt-in random cursor movement setting (upstream issue #79) and a toggle shortcut when the separate stop shortcut is cleared (#89). Random movement samples points inside a circle around the cursor position at start, at a configurable interval; points outside connected displays are rejected. It stops with the click session. It is not intended to evade detection, and movement is discrete rather than a smooth trajectory. Settings are applied at the next start.

Synthetic movement is marked so that the existing stop-on-movement monitor can distinguish it from user movement. This interaction, multiple displays, and Accessibility behavior require real-device validation.

The permissions view gives recovery guidance for stale macOS Accessibility entries. The build no longer runs `tccutil reset` against the user's existing grant. This does not prove or fix the cause of every denied Accessibility request.

`fork-build.yml` builds a macOS artifact for feature branches and manual runs, without publishing a release. Artifacts are ad-hoc signed, not notarized. Do not replace an existing installation until the artifact and real Accessibility interaction have been verified; changing the app signature may require the user to reauthorize it.

Outstanding upstream requests include idle activation, hold-to-run and hold input, fixed coordinates, sequences, update checks, and other distribution and localization requests. A macOS App Store build or notarization requires an authorized Apple signing identity. Upstream's existing dynamic menu icon setting addresses #65 in the current source; it still needs runtime confirmation.

## Timing and movement correction

Random intervals now schedule a new one-shot timer for every press; the displayed final time in range mode is an estimate. The completion notification is scheduled when the final press occurs. Reversed range endpoints are accepted safely.

When movement is enabled, the initial cursor position is captured once. A click-through circle shows the fixed area until the session stops. Movement begins immediately and then uses the configured interval; generated positions are restricted to that circle and connected display bounds. If the user moves outside the circle, an automated mouse click first returns to the center; the user can still move the mouse freely to retain control and use stop-on-movement. The circle is expressed in macOS screen points (which need not equal physical pixels on Retina displays). Display changes, full-screen windows, and the interaction with stop-on-movement require validation on real hardware.
