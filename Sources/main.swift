import AppKit
import EventKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = EKEventStore()
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setStatusSymbol()

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            startUpdating()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.startUpdating() } else { self?.showNoAccess() }
                }
            }
        default:
            showNoAccess()
        }
    }

    // MARK: - Updating

    private func startUpdating() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let now = Date()
        guard let horizon = Calendar.current.date(byAdding: .hour, value: 36, to: now) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: horizon, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && !isDeclined($0) }
            .sorted { $0.startDate < $1.startDate }

        if let next = events.first {
            let title = truncate(next.title ?? "Untitled", 28)
            setStatusText("\(title) · \(timeLabel(for: next, now: now))")
        } else {
            setStatusSymbol()
        }
        statusItem.menu = buildMenu(events: Array(events.prefix(6)))
    }

    // MARK: - Status item

    private func setStatusText(_ text: String) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.title = text
    }

    private func setStatusSymbol() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "No upcoming meetings")
        image?.isTemplate = true
        button.image = image
        button.title = ""
    }

    private func timeLabel(for event: EKEvent, now: Date) -> String {
        if event.startDate <= now { return "now" }
        let minutes = Int((event.startDate.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes)m" }
        if Calendar.current.isDateInToday(event.startDate) {
            return Self.timeFormatter.string(from: event.startDate)
        }
        if Calendar.current.isDateInTomorrow(event.startDate) {
            return "tmrw " + Self.timeFormatter.string(from: event.startDate)
        }
        return Self.dayFormatter.string(from: event.startDate) + " "
            + Self.timeFormatter.string(from: event.startDate)
    }

    // MARK: - Menu

    private func buildMenu(events: [EKEvent]) -> NSMenu {
        let menu = NSMenu()
        if events.isEmpty {
            menu.addItem(disabledItem("No meetings in the next 36 hours"))
        } else {
            for event in events {
                let label = "\(menuTimeLabel(for: event))   \(truncate(event.title ?? "Untitled", 40))"
                menu.addItem(disabledItem(label))
            }
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("Open Calendar", #selector(openCalendar), ""))
        menu.addItem(actionItem("Quit", #selector(quit), "q"))
        return menu
    }

    private func menuTimeLabel(for event: EKEvent) -> String {
        let now = Date()
        if event.startDate <= now { return "Now" }
        if Calendar.current.isDateInToday(event.startDate) {
            return Self.timeFormatter.string(from: event.startDate)
        }
        if Calendar.current.isDateInTomorrow(event.startDate) {
            return "Tomorrow " + Self.timeFormatter.string(from: event.startDate)
        }
        return Self.dayFormatter.string(from: event.startDate) + " "
            + Self.timeFormatter.string(from: event.startDate)
    }

    private func showNoAccess() {
        if let button = statusItem.button {
            button.image = nil
            button.title = "⚠︎ Calendar"
        }
        let menu = NSMenu()
        menu.addItem(disabledItem("Calendar access is required"))
        menu.addItem(actionItem("Open Privacy Settings…", #selector(openPrivacySettings), ""))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit", #selector(quit), "q"))
        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func openCalendar() {
        let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func isDeclined(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        for attendee in attendees where attendee.isCurrentUser {
            return attendee.participantStatus == .declined
        }
        return false
    }

    private func truncate(_ string: String, _ max: Int) -> String {
        guard string.count > max else { return string }
        return String(string.prefix(max - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
