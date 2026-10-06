import ClockioCore
import SwiftUI

/// What a given screensaver window shows. With two or more displays the primary display shows
/// the clock and the others show the day plan, so the same content is never duplicated.
enum ScreensaverRole: Equatable {
    /// The clock face. `showsTodos` is false on the primary display when another display is
    /// presenting the dedicated agenda, so the day plan isn't shown twice.
    case clock(showsTodos: Bool)
    /// A full-screen day plan / to-do list, used on secondary displays.
    case agenda
}

struct ScreensaverView: View {
    @EnvironmentObject private var model: ClockioAppModel
    var role: ScreensaverRole = .clock(showsTodos: true)
    var globalPointerFrame: CGRect?

    var body: some View {
        PointerParallax(globalFrame: globalPointerFrame) { unit in
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ZStack(alignment: .bottom) {
                    // The screensaver canvas stays fixed; its animated elements bend toward the pointer.
                    BackgroundSceneView(
                        background: model.renderedBackground,
                        speed: model.settings.motion / 100,
                        saver: true,
                        nightMode: model.isNightModeActive,
                        pointerUnit: unit
                    )
                    .scaleEffect(1.06)
                    .ignoresSafeArea()

                    PointerSheen(unit: unit, intensity: 0.10)
                        .ignoresSafeArea()

                    content(date: timeline.date)

                    exitButton
                }
                .background(.black)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(model.isNightModeActive ? .dark : .light)
    }

    @ViewBuilder
    private func content(date: Date) -> some View {
        switch role {
        case .clock(let showsTodos):
            ClockFaceView(
                style: model.settings.clockStyle,
                date: date,
                settings: model.settings,
                background: model.renderedBackground,
                todos: showsTodos ? model.visibleTodos : [],
                saver: true,
                nightMode: model.isNightModeActive,
                morningGreetingText: model.screensaverGreeting
            )
        case .agenda:
            ScreensaverAgenda(
                date: date,
                background: model.renderedBackground,
                events: model.settings.showCalendarEvents ? model.calendarEvents : [],
                todos: model.activeTodos,
                completedCount: model.completedTodos.count,
                showTemperature: model.settings.showTemperature,
                temperature: model.settings.temperature,
                nightMode: model.isNightModeActive
            )
        }
    }

    private var exitButton: some View {
        Button {
            model.stopScreensaver()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "escape")
                    .font(.system(size: 11, weight: .semibold))
                Text("Click or press any key to exit")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.clickable)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 40)
        .padding(.bottom, 34)
        .opacity(0.5)
    }
}

/// Full-screen day plan shown on the secondary display while the primary shows the clock.
/// Today's calendar events (when enabled) sit above the to-do list as a "Schedule" section.
private struct ScreensaverAgenda: View {
    var date: Date
    var background: ClockBackground
    var events: [CalendarEvent]
    var todos: [TodoItem]
    var completedCount: Int
    var showTemperature: Bool
    var temperature: Int
    var nightMode: Bool

    private var foreground: Color {
        (background.isLightScene && !nightMode) ? Color.black.opacity(0.82) : Color.white.opacity(0.92)
    }

    // Cap the lists so a long day never overflows the screen; the rest stay in the app.
    private var visibleEvents: [CalendarEvent] {
        Array(events.prefix(4))
    }

    private var visibleTodos: [TodoItem] {
        Array(todos.prefix(visibleEvents.isEmpty ? 8 : 5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(foreground.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.system(size: 60, weight: .semibold, design: .rounded))
                        .foregroundStyle(foreground)
                    if showTemperature {
                        Text(DisplayFormat.temperature(temperature))
                            .font(.system(size: 38, weight: .regular, design: .rounded))
                            .foregroundStyle(foreground.opacity(0.6))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }

            if !visibleEvents.isEmpty {
                section(title: "SCHEDULE") {
                    ForEach(visibleEvents) { event in
                        AgendaEventRow(event: event, foreground: foreground)
                    }
                }
            }

            section(title: visibleEvents.isEmpty ? nil : "TO-DO") {
                if visibleTodos.isEmpty {
                    Text("Nothing planned for today.")
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundStyle(foreground.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(visibleTodos) { todo in
                        AgendaRow(todo: todo, foreground: foreground)
                    }
                }
            }

            HStack(spacing: 14) {
                Text("\(todos.count) to do")
                if completedCount > 0 {
                    Circle().fill(foreground.opacity(0.4)).frame(width: 6, height: 6)
                    Text("\(completedCount) done")
                }
            }
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(foreground.opacity(0.5))
        }
        .frame(width: 760, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(60)
    }

    @ViewBuilder
    private func section<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(foreground.opacity(0.4))
            }
            VStack(spacing: 14) {
                content()
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()
}

private struct AgendaEventRow: View {
    var event: CalendarEvent
    var foreground: Color

    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(foreground.opacity(0.55))
                .frame(width: 18)
            Text(event.timeText ?? "All-day")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.64))
                .frame(width: 92, alignment: .leading)
            Text(event.title)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .foregroundStyle(foreground.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(foreground.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(foreground.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AgendaRow: View {
    var todo: TodoItem
    var foreground: Color

    private var timeText: String? {
        guard let hour = todo.scheduledHour, let minute = todo.scheduledMinute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    var body: some View {
        HStack(spacing: 22) {
            Circle()
                .strokeBorder(foreground.opacity(0.4), lineWidth: 1.6)
                .frame(width: 18, height: 18)
            Text(timeText ?? "—")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(foreground.opacity(timeText == nil ? 0.3 : 0.64))
                .frame(width: 78, alignment: .leading)
            Text(todo.title)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .foregroundStyle(foreground.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(foreground.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(foreground.opacity(0.12), lineWidth: 1)
        )
    }
}
