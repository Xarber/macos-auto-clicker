//
//  AutoClickSimulator.swift
//  auto-clicker
//
//  Created by Ben Tindall on 12/05/2021.
//

import Foundation
import Combine
import SwiftUI
import Defaults
import UserNotifications

final class AutoClickSimulator: ObservableObject {
    static var shared: AutoClickSimulator = .init()
    private init() {}

    @Published var isAutoClicking = false

    @Published var remainingInterations: Int = 0

    @Published var nextClickAt: Date = .init()
    @Published var finalClickAt: Date = .init()

    // Said weird behaviour is still occuring in 12.2.1, thus having these defined in here instead of Published, I hate this though so much
    private var duration: Duration = .milliseconds
    private var interval: Int = DEFAULT_PRESS_INTERVAL
    private var amountOfPresses: Int = DEFAULT_REPEAT_AMOUNT
    private var input = Input()

    private var timer: Timer?
    private var movementTimer: Timer?
    private var movementOrigin: CGPoint?
    private var movementRadius: CGFloat = 0
    private var movementOverlay: NSWindow?
    private var lastWarp: (point: CGPoint, date: Date)?
    private var activity: Cancellable?

    private var monitorObject: Any?
    private var startMonitorObject: Any?
    private var initialMousePosition: NSPoint?
    private var mouseDeltaThreshold: CGFloat = 0.0

    func start() {
        self.isAutoClicking = true

        // Stop mouse start monitoring if it's running
        self.stopMouseStartMonitoring()

        if let startMenuItem = MenuBarService.startMenuItem {
            startMenuItem.isEnabled = false
        }

        if let stopMenuItem = MenuBarService.stopMenuItem {
            stopMenuItem.isEnabled = true
        }

        MenuBarService.changeImageColour(newColor: .systemBlue)

        self.activity = ProcessInfo.processInfo.beginActivity(.autoClicking)

        self.duration = Defaults[.autoClickerState].pressIntervalDuration
        self.input = Defaults[.autoClickerState].pressInput
        self.amountOfPresses = Defaults[.autoClickerState].pressAmount
        self.remainingInterations = Defaults[.autoClickerState].repeatAmount
        self.scheduleNextPress()

        if Defaults[.randomMouseMovement], let origin = CGEvent(source: nil)?.location {
            self.movementOrigin = origin
            self.movementRadius = CGFloat(max(1, min(1000, Defaults[.randomMouseRadius])))
            self.showMovementBoundary(origin: origin, radius: self.movementRadius)
            self.moveMouseRandomly()
            let seconds = max(1, Defaults[.randomMouseInterval])
            self.movementTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
                self?.moveMouseRandomly()
            }
        }

        if Defaults[.mouseStopOnMove] {
            self.initialMousePosition = nil
            self.mouseDeltaThreshold = CGFloat(Defaults[.mouseDeltaThreshold])
            startMouseMonitoring()
        }

        if Defaults[.notifyOnStart] {
            NotificationService.scheduleNotification(title: "Started", date: self.nextClickAt)
        }

    }

    func stop(triggeredByMouseMovement: Bool = false) {
        self.isAutoClicking = false
        self.movementTimer?.invalidate()
        self.movementTimer = nil
        self.movementOrigin = nil
        self.movementOverlay?.orderOut(nil)
        self.movementOverlay = nil
        self.lastWarp = nil

        if let monitorObject = self.monitorObject {
            NSEvent.removeMonitor(monitorObject)
            self.monitorObject = nil
        }

        if let startMenuItem = MenuBarService.startMenuItem {
            startMenuItem.isEnabled = true
        }

        if let stopMenuItem = MenuBarService.stopMenuItem {
            stopMenuItem.isEnabled = false
        }

        MenuBarService.resetImage()

        self.activity?.cancel()
        self.activity = nil

        // Force zero, as the user could stop the timer early
        self.remainingInterations = 0

        if let timer = self.timer {
            timer.invalidate()
        }

        if triggeredByMouseMovement {
            NotificationService.removePendingNotifications()

            if Defaults[.notifyOnFinish] {
                NotificationService.scheduleNotification(title: "Finished", date: Date())
            }
        } else {
            NotificationService.removePendingNotifications()
        }

        // Re-enable mouse start monitoring if it was enabled
        if Defaults[.mouseStartOnMove] && !self.isAutoClicking {
            self.startMouseStartMonitoring()
        }
    }

    func startMouseStartMonitoring() {
        // Stop any existing monitoring
        if let startMonitorObject = self.startMonitorObject {
            NSEvent.removeMonitor(startMonitorObject)
            self.startMonitorObject = nil
        }

        self.initialMousePosition = nil
        self.mouseDeltaThreshold = CGFloat(Defaults[.mouseDeltaThreshold])

        self.startMonitorObject = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.mouseMovedForStart(event)
        }
    }

    func stopMouseStartMonitoring() {
        if let startMonitorObject = self.startMonitorObject {
            NSEvent.removeMonitor(startMonitorObject)
            self.startMonitorObject = nil
        }
    }

    private func scheduleNextPress() {
        let state = Defaults[.autoClickerState]
        if state.intervalMode == .rangeInterval {
            let first = state.pressIntervalMin ?? DEFAULT_PRESS_INTERVAL_MIN
            let second = state.pressIntervalMax ?? DEFAULT_PRESS_INTERVAL_MAX
            self.interval = Int.random(in: max(1, min(first, second))...max(1, max(first, second)))
        } else {
            self.interval = max(1, state.pressInterval)
        }
        let delay = self.duration.asTimeInterval(interval: self.interval)
        self.nextClickAt = Date(timeIntervalSinceNow: delay)
        // Future random intervals are unknown; use their midpoint for the displayed estimate.
        let mean = state.intervalMode == .rangeInterval
            ? (Double(state.pressIntervalMin ?? DEFAULT_PRESS_INTERVAL_MIN) + Double(state.pressIntervalMax ?? DEFAULT_PRESS_INTERVAL_MAX)) / 2
            : Double(self.interval)
        let unit = self.duration.asTimeInterval(interval: 1)
        self.finalClickAt = self.nextClickAt.addingTimeInterval(unit * mean * Double(max(0, self.remainingInterations - 1)))
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard self.isAutoClicking else { return }
        self.remainingInterations -= 1
        self.press()
        if self.remainingInterations <= 0 {
            self.stop()
            if Defaults[.notifyOnFinish] {
                NotificationService.scheduleNotification(title: "Finished", date: Date())
            }
        } else {
            self.scheduleNextPress()
        }
    }

    private func startMouseMonitoring() {
        self.monitorObject = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.mouseMoved(event)
        }
    }

    private func mouseMoved(_ event: NSEvent) {
        if let warp = lastWarp, Date().timeIntervalSince(warp.date) < 0.2,
           let location = event.cgEvent?.location,
           hypot(location.x - warp.point.x, location.y - warp.point.y) < 2 {
            lastWarp = nil
            return
        }
        let position = event.locationInWindow
        if let initialPosition = self.initialMousePosition {
            let deltaX = position.x - initialPosition.x
            let deltaY = position.y - initialPosition.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            if distance > mouseDeltaThreshold {
                self.stop(triggeredByMouseMovement: true)
            }
        } else {
            self.initialMousePosition = position
        }
    }

    private func mouseMovedForStart(_ event: NSEvent) {
        let position = event.locationInWindow
        if let initialPosition = self.initialMousePosition {
            let deltaX = position.x - initialPosition.x
            let deltaY = position.y - initialPosition.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            if distance > mouseDeltaThreshold {
                // Stop monitoring and start the auto clicker
                self.stopMouseStartMonitoring()
                self.start()
            }
        } else {
            self.initialMousePosition = position
        }
    }

    // Sample uniformly within a circle around the position at the start of the session.
    // Reject points outside connected displays instead of jumping across a display gap.
    private func moveMouseRandomly() {
        guard let origin = movementOrigin else { return }
        let radius = movementRadius
        guard radius > 0 else { return }
        for _ in 0..<20 {
            let angle = Double.random(in: 0..<(2 * .pi))
            let distance = radius * CGFloat(sqrt(Double.random(in: 0...1)))
            let point = CGPoint(x: origin.x + distance * CGFloat(cos(angle)),
                                y: origin.y + distance * CGFloat(sin(angle)))
            guard NSScreen.screens.contains(where: { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayBounds(CGDirectDisplayID(number.uint32Value)).contains(point)
            }) else { continue }
            lastWarp = (point, Date())
            let result = CGWarpMouseCursorPosition(point)
            if result != .success { lastWarp = nil }
            return
        }
    }

    private func showMovementBoundary(origin: CGPoint, radius: CGFloat) {
        guard let mainScreen = NSScreen.screens.first else { return }
        // Quartz uses a top-left origin; AppKit windows use a bottom-left origin.
        let center = CGPoint(x: origin.x, y: mainScreen.frame.maxY - origin.y)
        let frame = CGRect(x: center.x - radius - 3, y: center.y - radius - 3,
                           width: radius * 2 + 6, height: radius * 2 + 6)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = RadiusBoundaryView(frame: CGRect(origin: .zero, size: frame.size))
        window.orderFrontRegardless()
        movementOverlay = window
    }

    private let mouseDownEventMap: [NSEvent.EventType: CGEventType] = [
        .leftMouseDown: .leftMouseDown,
        .leftMouseUp: .leftMouseDown,
        .rightMouseDown: .rightMouseDown,
        .rightMouseUp: .rightMouseDown,
        .otherMouseDown: .otherMouseDown,
        .otherMouseUp: .otherMouseDown
    ]

    private let mouseUpEventMap: [NSEvent.EventType: CGEventType] = [
        .leftMouseDown: .leftMouseUp,
        .leftMouseUp: .leftMouseUp,
        .rightMouseDown: .rightMouseUp,
        .rightMouseUp: .rightMouseUp,
        .otherMouseDown: .otherMouseUp,
        .otherMouseUp: .otherMouseUp
    ]

    private let mouseButtonEventMap: [NSEvent.EventType: CGMouseButton] = [
        .leftMouseDown: .left,
        .leftMouseUp: .left,
        .rightMouseDown: .right,
        .rightMouseUp: .right,
        .otherMouseDown: .center,
        .otherMouseUp: .center
    ]

    private func generateMouseClickEvents(source: CGEventSource?) -> [CGEvent?] {
        let clickingAtPoint = CGEvent(source: nil)?.location ?? .zero

        let mouseDownType: CGEventType = mouseDownEventMap[self.input.type]!
        let mouseUpType: CGEventType = mouseUpEventMap[self.input.type]!
        let mouseButton: CGMouseButton = mouseButtonEventMap[self.input.type]!

        let mouseDown = CGEvent(mouseEventSource: source,
                                mouseType: mouseDownType,
                                mouseCursorPosition: clickingAtPoint,
                                mouseButton: mouseButton)

        let mouseUp = CGEvent(mouseEventSource: source,
                              mouseType: mouseUpType,
                              mouseCursorPosition: clickingAtPoint,
                              mouseButton: mouseButton)

        return [mouseDown, mouseUp]
    }

    private func generateKeyPressEvents(source: CGEventSource?) -> [CGEvent?] {
        let keyDown = CGEvent(keyboardEventSource: source,
                              virtualKey: CGKeyCode(self.input.keyCode),
                              keyDown: true)

        let keyUp = CGEvent(keyboardEventSource: source,
                            virtualKey: CGKeyCode(self.input.keyCode),
                            keyDown: false)

        if self.input.modifiers.contains(.command) {
            keyDown?.flags = CGEventFlags.maskCommand
            keyUp?.flags = CGEventFlags.maskCommand
        }

        if self.input.modifiers.contains(.control) {
            keyDown?.flags = CGEventFlags.maskControl
            keyUp?.flags = CGEventFlags.maskControl
        }

        if self.input.modifiers.contains(.option) {
            keyDown?.flags = CGEventFlags.maskAlternate
            keyUp?.flags = CGEventFlags.maskAlternate
        }

        if self.input.modifiers.contains(.shift) {
            keyDown?.flags = CGEventFlags.maskShift
            keyUp?.flags = CGEventFlags.maskShift
        }

        return [keyDown, keyUp]
    }

    private func press() {
        // Keep automated clicks in the marked circle even if the user moved the pointer.
        if self.input.isMouseInput, let origin = self.movementOrigin,
           let current = CGEvent(source: nil)?.location,
           hypot(current.x - origin.x, current.y - origin.y) > self.movementRadius {
            self.lastWarp = (origin, Date())
            if CGWarpMouseCursorPosition(origin) != .success { return }
        }
        let source: CGEventSource? = CGEventSource(stateID: .hidSystemState)

        let pressEvents = self.input.isMouseInput
                            ? generateMouseClickEvents(source: source)
                            : generateKeyPressEvents(source: source)

        var completedPressesThisAction = 0

        while completedPressesThisAction < self.amountOfPresses {
            for event in pressEvents {
                event!.post(tap: .cghidEventTap)

                LoggerService.simPress(input: self.input, location: event!.location)
            }

            completedPressesThisAction += 1
        }
    }
}

private final class RadiusBoundaryView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        NSColor.systemBlue.withAlphaComponent(0.08).setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        circle.lineWidth = 4
        circle.stroke()
        NSColor.systemBlue.setStroke()
        circle.lineWidth = 2
        circle.stroke()
    }
}
