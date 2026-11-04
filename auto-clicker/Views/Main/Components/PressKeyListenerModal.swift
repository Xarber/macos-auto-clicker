//
//  PressKeyListenerModal.swift
//  auto-clicker
//
//  Created by Ben Tindall on 07/04/2022.
//

import SwiftUI
import Defaults
import Carbon.HIToolbox

struct PressKeyListenerModal: View {
    @Environment(\.presentationMode) private var presentationMode

    @Default(.appearanceSelectedTheme) private var activeTheme
    @Default(.autoClickerState) private var formState

    @State private var escapeKeyStreak: Int = 0

    func handleInputEvent(input: Input) {
        guard !input.isMouseInput else {
            self.formState.pressInput = input

            return
        }

        if input.keyCode == kVK_Escape {
            self.escapeKeyStreak += 1
        }

        // Issue is, there is always an initial key press of escape before macOS triggers the repeat flag for holding the key
        if input.keyCode == kVK_Escape && input.isRepeat {
            self.presentationMode.wrappedValue.dismiss()

            return
        }

        if (input.keyCode != kVK_Escape || (input.keyCode == kVK_Escape && self.escapeKeyStreak > 1)) && !input.readable.isEmpty {
            self.formState.pressInput = input

            self.escapeKeyStreak = 0
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 22, weight: .medium))
                .accessibilityHidden(true)
            SmallText("key_listener_modal_press_prompt")

            Spacer()

            Text(self.formState.pressInput.readable)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .accessibilityLabel(self.formState.pressInput.readable)

            Spacer()

            SmallText("key_listener_modal_dismiss_key_prompt")
            SmallText("key_listener_modal_dismiss_key_override")
        }
        .frame(width: 340, height: 190)
        .padding(.vertical, 14)
        .padding(.horizontal, 5)
        .background(self.activeTheme.backgroundColour)
        .ignoresSafeArea()
        .overlay(InputAwareView(onPress: handleInputEvent))
    }
}
