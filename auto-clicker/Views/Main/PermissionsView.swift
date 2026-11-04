//
//  PermissionsView.swift
//  auto-clicker
//
//  Created by Ben Tindall on 10/04/2022.
//

import SwiftUI
import Defaults

struct PermissionsView: View {
    @Default(.appearanceSelectedTheme) private var activeTheme

    func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 30, weight: .medium))
                .padding(20)
                .background(Color.black.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("permissions_help_title", comment: "Permissions helper splash window title")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                Text("permissions_help_first_paragraph", comment: "Permissions helper splash window description")
                    .font(.body)
                Text("permissions_help_second_paragraph", comment: "Permissions helper splash window description extended")
                    .font(.callout)
            }
            .multilineTextAlignment(.center)

            Button(action: openSystemPreferences) {
                Label("permissions_help_open_sys_pref_btn", systemImage: "gearshape")
            }
            .buttonStyle(ThemedButtonStyle(fontSize: 16, width: 220))

            VStack(spacing: 8) {
                Text("permissions_help_unlock_note", comment: "Permissions helper splash window unlock note")
                Text("If access was already enabled, remove the old AutoClicker entry in Privacy & Security → Accessibility, quit and reopen the app, then grant access again. A rebuilt app may need a new approval.")
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .opacity(0.85)
        }
        .foregroundColor(self.activeTheme.fontColour)
        .padding(28)
        .frame(maxWidth: 520)
    }

}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView()
    }
}
