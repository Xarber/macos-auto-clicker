//
//  MainView.swift
//  auto-clicker
//
//  Created by Ben Tindall on 27/03/2022.
//

import SwiftUI
import DateStrings
import KeyboardShortcuts
import Defaults

struct MainView: View {
    @Default(.appearanceSelectedTheme) private var activeTheme
    @Default(.autoClickerState) private var formState
    @Default(.randomMouseMovement) private var randomMouseMovement
    @Default(.randomMouseRadius) private var randomMouseRadius
    @Default(.randomMouseInterval) private var randomMouseInterval

    @StateObject private var autoClickSimulator = AutoClickSimulator.shared
    @StateObject private var delayTimer = DelayTimer.shared

    @State private var showThemeName = false

    var hasStarted: Bool {
        self.autoClickSimulator.isAutoClicking || self.delayTimer.isCountingDown
    }

    var hasStopped: Bool {
        !self.autoClickSimulator.isAutoClicking && !self.delayTimer.isCountingDown
    }

    var estNextClickAt: Date {
        .init(timeInterval: self.formState.pressIntervalDuration.asTimeInterval(interval: self.formState.pressInterval),
              since: .init())
    }

    var estFinalClickAt: Date {
        .init(timeInterval: self.formState.pressIntervalDuration.asTimeInterval(interval: self.formState.pressInterval * self.formState.repeatAmount),
              since: .init())
    }

    func start() {
        if !self.hasStarted {
            self.delayTimer.start(onFinish: self.autoClickSimulator.start)
            MenuBarService.changeImageColour(newColor: .systemOrange)
        }
    }

    func stop() {
        self.delayTimer.stop()
        self.autoClickSimulator.stop()
    }

    func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .pressStartButton) { [self] in
            if KeyboardShortcuts.Name.pressStopButton.shortcut == nil && self.hasStarted {
                self.stop()
            } else {
                self.start()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pressStopButton) { [self] in
            self.stop()
        }
    }

    func changeColour() {
        self.activeTheme.randomise()

        withAnimation {
            self.showThemeName = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                self.showThemeName = false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AutoClicker")
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                        Text("fork_setup_subtitle")
                            .font(.callout)
                            .opacity(0.8)
                    }
                    Spacer()
                    Label(NSLocalizedString(self.hasStarted ? (self.delayTimer.isCountingDown ? "fork_starting" : "fork_running") : "fork_ready", comment: "Session status"),
                          systemImage: self.hasStarted ? "play.circle.fill" : "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.16), in: Capsule())
                        .accessibilityLabel(LocalizedStringKey(self.hasStarted ? "fork_active_accessibility" : "fork_ready_accessibility"))
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("fork_click_setup", systemImage: "cursorarrow.click")
                            .font(.headline)
                        Spacer()
                        Picker("fork_timing", selection: self.$formState.intervalMode) {
                            Text("fork_fixed").tag(IntervalMode.staticInterval)
                            Text("fork_random").tag(IntervalMode.rangeInterval)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        .disabled(self.hasStarted)
                    }
                    Divider().overlay(self.activeTheme.fontColour.opacity(0.2))
                ActionStageLine {
                    Text("main_window_every", comment: "Main window 'Every'")

                    if self.formState.intervalMode == .staticInterval {
                        DynamicWidthNumberField(placeholder: "",
                                                min: MIN_PRESS_INTERVAL,
                                                max: MAX_PRESS_INTERVAL,
                                                number: self.$formState.pressInterval)
                            .disabled(self.hasStarted)
                        DurationSelector(selectedDuration: self.$formState.pressIntervalDuration)
                            .disabled(self.hasStarted)
                    } else {
                        DynamicWidthNumberField(placeholder: "Min",
                                                min: MIN_PRESS_INTERVAL,
                                                max: MAX_PRESS_INTERVAL,
                                                number: Binding(get: { self.formState.pressIntervalMin ?? DEFAULT_PRESS_INTERVAL_MIN }, set: { self.formState.pressIntervalMin = $0 }))
                            .disabled(self.hasStarted)
                        Text("main_window_to", comment: "Range separator 'to'")
                        DynamicWidthNumberField(placeholder: "Max",
                                                min: MIN_PRESS_INTERVAL,
                                                max: MAX_PRESS_INTERVAL,
                                                number: Binding(get: { self.formState.pressIntervalMax ?? DEFAULT_PRESS_INTERVAL_MAX }, set: { self.formState.pressIntervalMax = $0 }))
                            .disabled(self.hasStarted)
                        DurationSelector(selectedDuration: self.$formState.pressIntervalDuration)
                            .disabled(self.hasStarted)
                    }

                    Text("main_window_comma", comment: "Main window comma")
                }

                ActionStageLine {
                    Text("main_window_press", comment: "Main window 'press'")

                    PressKeyListener()
                        .disabled(self.hasStarted)

                    DynamicWidthNumberField(placeholder: "",
                                            min: MIN_PRESS_AMOUNT,
                                            max: MAX_PRESS_AMOUNT,
                                            number: self.$formState.pressAmount)
                        .disabled(self.hasStarted)

                    Text(self.formState.pressAmount == 1 ? "main_window_time" : "main_window_times", comment: "Main window 'time(s)'") + Text("main_window_comma", comment: "Main window comma")
                }

                ActionStageLine {
                    Text("main_window_repeat", comment: "Main window 'repeat'")

                    DynamicWidthNumberField(placeholder: "",
                                            min: MIN_REPEAT_AMOUNT,
                                            max: MAX_REPEAT_AMOUNT,
                                            number: self.$formState.repeatAmount)
                        .disabled(self.hasStarted)

                    Text(self.formState.repeatAmount == 1 ? "main_window_time" : "main_window_times", comment: "Main window 'time(s)'") + Text("main_window_full_stop", comment: "Main window full stop")
                }

                ActionStageLine {
                    Text("main_window_wait", comment: "Main window 'Wait'")

                    DynamicWidthNumberField(placeholder: "",
                                            min: MIN_START_DELAY,
                                            max: MAX_START_DELAY,
                                            number: self.$formState.startDelay)
                        .disabled(self.hasStarted)

                    Text(self.formState.startDelay == 1 ? "main_window_second" : "main_window_seconds", comment: "Main window 'second(s)'") + Text("main_window_before_starting", comment: "Main window 'before starting'") + Text("main_window_full_stop", comment: "Main window full stop")
                }
                }
                .padding(18)
                .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("fork_cursor_area", systemImage: "scope")
                            .font(.headline)
                        Spacer()
                        Toggle("fork_random_movement", isOn: self.$randomMouseMovement)
                            .toggleStyle(.switch)
                            .disabled(self.hasStarted)
                    }
                    if self.randomMouseMovement {
                        HStack {
                            Text("fork_radius")
                            NumberField(text: "", min: 1, max: 1000, number: self.$randomMouseRadius)
                                .frame(width: 64)
                            Text("fork_points")
                            Slider(value: Binding(get: { Double(self.randomMouseRadius) }, set: { self.randomMouseRadius = Int($0) }), in: 1...1000, onEditingChanged: { editing in
                                if editing { self.autoClickSimulator.updateRadiusPreview(self.randomMouseRadius) }
                                else { self.autoClickSimulator.endRadiusPreview() }
                            })
                            .accessibilityLabel("fork_radius")
                            Spacer(minLength: 12)
                            Text("fork_move_every")
                            NumberField(text: "", min: 1, max: 3600, number: self.$randomMouseInterval)
                                .frame(width: 64)
                            Text("fork_seconds_short")
                        }
                        .font(.callout)
                        .disabled(self.hasStarted)
                        Text("fork_area_help")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
                .padding(18)
                .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 5) {
                        Button(action: self.start) {
                            Label(self.hasStarted && self.delayTimer.isCountingDown ? self.delayTimer.countdownText : NSLocalizedString("fork_start", comment: "Start"),
                                  systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ThemedButtonStyle(fontSize: 18, width: 130, height: 42))
                        .disabled(self.hasStarted)
                        if let shortcut = KeyboardShortcuts.Name.pressStartButton.shortcut {
                            KeyboardShortcutHint(shortcut: shortcut)
                        }
                    }
                    VStack(spacing: 5) {
                        Button(action: self.stop) {
                            Label("fork_stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ThemedButtonStyle(fontSize: 18, width: 130, height: 42))
                        .disabled(self.hasStopped)
                        if let shortcut = KeyboardShortcuts.Name.pressStopButton.shortcut {
                            KeyboardShortcutHint(shortcut: shortcut)
                        }
                    }
                    Spacer()
                    if self.autoClickSimulator.isAutoClicking {
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("fork_remaining").font(.caption).opacity(0.8)
                            Text("\(self.autoClickSimulator.remainingInterations)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }

                if self.autoClickSimulator.isAutoClicking {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("fork_next_click").font(.caption)
                            Text(timerInterval: Date()...max(Date(), self.autoClickSimulator.nextClickAt), countsDown: true)
                                .monospacedDigit()
                                .font(.headline)
                        }
                        Button { FloatingCountdown.shared.show() } label: {
                            Image(systemName: "pip.enter")
                        }
                        .help("fork_floating_countdown")
                        .accessibilityLabel("fork_floating_countdown")
                        StatBox(title: "main_window_stat_box_next_press_at",
                                value: self.autoClickSimulator.nextClickAt.asString(inFormat: "HH:mm:ss.SSS"))
                        StatBox(title: "main_window_stat_box_final_press_at",
                                value: (self.formState.intervalMode == .rangeInterval ? "~" : "") + self.autoClickSimulator.finalClickAt.asString(inFormat: "HH:mm:ss.SSS"))
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack {
                    Spacer()
                    Button(action: self.changeColour) {
                        Text(self.showThemeName ? self.activeTheme.currentColour.localised : "main_window_repo_vanity")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.7)
                    .accessibilityLabel("fork_change_theme")
                }
            }
            .foregroundColor(self.activeTheme.fontColour)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear(perform: self.registerKeyboardShortcuts)
        .onChange(of: self.randomMouseRadius) { value in
            if !self.hasStarted { self.autoClickSimulator.updateRadiusPreview(value) }
        }
        .onChange(of: self.randomMouseMovement) { enabled in
            if !enabled { self.autoClickSimulator.endRadiusPreview() }
        }
        .onDisappear { self.autoClickSimulator.endRadiusPreview() }
    }

}

// struct ActionStageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ActionStageView()
//            .frame(minWidth: WindowSize.width)
//            .frame(maxWidth: WindowSize.width)
//            .padding(10)
//    }
// }

private final class FloatingCountdown: NSObject, NSWindowDelegate {
    static let shared = FloatingCountdown()
    private var panel: NSPanel?
    private weak var mainWindow: NSWindow?

    func show() {
        if let panel = panel {
            panel.orderFrontRegardless()
            return
        }
        mainWindow = NSApp.mainWindow
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 84),
                            styleMask: [.titled, .closable, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = NSLocalizedString("fork_next_click", comment: "Next click")
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FloatingCountdownView(onExpand: { [weak self] in self?.close() }))
        if let screen = mainWindow?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - panel.frame.width - 16,
                                               y: visible.maxY - 16))
        }
        self.panel = panel
        panel.orderFrontRegardless()
        mainWindow?.miniaturize(nil)
    }

    func close() { panel?.close() }

    func windowWillClose(_ notification: Notification) {
        panel = nil
        mainWindow?.deminiaturize(nil)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct FloatingCountdownView: View {
    @ObservedObject private var simulator = AutoClickSimulator.shared
    @ObservedObject private var delay = DelayTimer.shared
    var onExpand: () -> Void

    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                if simulator.isAutoClicking {
                    Text(String(format: "%.1f s", max(0, simulator.nextClickAt.timeIntervalSince(context.date))))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                } else if delay.isCountingDown {
                    Text(delay.countdownText).font(.title2).monospacedDigit()
                } else {
                    Text("fork_ready").font(.headline)
                }
            }
            Spacer()
            Button(action: onExpand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .buttonStyle(.plain)
                .help("fork_expand")
                .accessibilityLabel("fork_expand")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
