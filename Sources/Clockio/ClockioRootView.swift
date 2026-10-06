import AppKit
import ClockioCore
import SwiftUI

struct ClockioRootView: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 256)

                if model.mode == .settings {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.mode == .todo {
                    TodoWorkspaceView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    StageView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    InspectorView()
                        .frame(width: 320)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppBackdrop())
        .tint(Theme.accent)
        .frame(minWidth: 1080, minHeight: 720)
        .preferredColorScheme(model.isNightModeActive ? .dark : .light)
        .animation(.smooth(duration: 0.35), value: model.isNightModeActive)
    }
}

private struct TopBar: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        HStack(spacing: Theme.s4) {
            Color.clear.frame(width: 72)
            Spacer()
            Text(model.currentBackground.name)
                .font(Theme.eyebrow(11))
                .tracking(1.6)
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
            Button {
                withAnimation(.smooth(duration: 0.3)) { model.mode = .settings }
            } label: {
                IconGlyph(systemName: "gearshape")
                    .foregroundStyle(model.mode == .settings ? Theme.accent : Theme.inkSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.clickable)
            .help("Open settings")
        }
        .padding(.horizontal, Theme.s5)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s6) {
            VStack(alignment: .leading, spacing: Theme.s5) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clockio")
                        .font(Theme.display(30, .bold))
                        .foregroundStyle(Theme.ink)
                    Text("STANDBY STUDIO")
                        .font(Theme.eyebrow(10))
                        .tracking(2.2)
                        .foregroundStyle(Theme.inkTertiary)
                }

                VStack(spacing: Theme.s1) {
                    ForEach(WorkspaceMode.sidebarModes) { mode in
                        NavRow(mode: mode, icon: icon(for: mode), isActive: model.mode == mode) {
                            withAnimation(.smooth(duration: 0.3)) { model.mode = mode }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Theme.s6)
        .padding(.horizontal, Theme.s4)
        .padding(.bottom, Theme.s5)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
    }

    private func icon(for mode: WorkspaceMode) -> String {
        switch mode {
        case .gallery: "square.grid.2x2"
        case .todo: "checkmark.circle"
        case .settings: "gearshape"
        }
    }
}

private struct NavRow: View {
    var mode: WorkspaceMode
    var icon: String
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s3) {
                IconGlyph(systemName: icon)
                Text(mode.label)
                    .font(Theme.body(15, .medium))
                Spacer()
            }
            .foregroundStyle(isActive ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, Theme.s3)
            .frame(height: 48)
            .background(isActive ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
        }
        .buttonStyle(.clickable)
    }
}

private struct TodoWorkspaceView: View {
    @EnvironmentObject private var model: ClockioAppModel
    @State private var draftTitle = ""
    @State private var draftHasSchedule = true
    @State private var draftTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) ?? Date()

    private var canAdd: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s6) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: Theme.s2) {
                        Eyebrow("TODAY")
                        Text("Plan the day")
                            .font(Theme.display(54, .bold))
                            .foregroundStyle(Theme.ink)
                    Text("\(model.activeTodos.count) active · \(model.scheduledTodos.count) scheduled")
                        .font(Theme.body(14, .medium))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
            }

                TodoComposer(
                    title: $draftTitle,
                    hasSchedule: $draftHasSchedule,
                    time: $draftTime,
                    add: addDraftTodo
                )

                HStack(alignment: .top, spacing: Theme.s5) {
                    VStack(alignment: .leading, spacing: Theme.s4) {
                        TodoSectionHeader(title: "Day plan", detail: "")
                        if model.activeTodos.isEmpty {
                            TodoEmptyState()
                        } else {
                            VStack(spacing: Theme.s2) {
                                ForEach(model.activeTodos) { todo in
                                    TodoPlanRow(todo: todo, isCompact: false)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: Theme.s5) {
                        if model.settings.showCalendarEvents {
                            CalendarPanel()
                        }
                        CompletedTodoPanel()
                    }
                    .frame(width: 340, alignment: .top)
                }
            }
            .padding(Theme.s6)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
        .onAppear { model.refreshCalendarEvents() }
    }

    private func addDraftTodo() {
        guard canAdd else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: draftTime)
        model.addTodo(
            title: draftTitle,
            scheduledHour: draftHasSchedule ? components.hour : nil,
            scheduledMinute: draftHasSchedule ? components.minute : nil
        )
        model.settings.showTodos = true
        draftTitle = ""
    }
}

private struct TodoComposer: View {
    @Binding var title: String
    @Binding var hasSchedule: Bool
    @Binding var time: Date
    var add: () -> Void

    var body: some View {
        HStack(spacing: Theme.s3) {
            HStack(spacing: Theme.s3) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text("Add a task or plan")
                            .font(Theme.body(18, .medium))
                            .foregroundStyle(Theme.inkSecondary)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $title)
                        .textFieldStyle(.plain)
                        .font(Theme.body(18, .medium))
                        .foregroundStyle(Theme.ink)
                        .onSubmit(add)
                }
            }
            .padding(.horizontal, Theme.s4)
            .frame(height: 58)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }

            Toggle("", isOn: $hasSchedule)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: 54)
                .help("Schedule task")

            CompactTimeControl(date: time, isEnabled: hasSchedule) { nextDate in
                time = nextDate
            }
            .frame(width: 116)
        }
    }
}

private struct CompactTimeControl: View {
    var date: Date
    var isEnabled: Bool = true
    var stepMinutes: Int = 15
    var onChange: (Date) -> Void

    var body: some View {
        HStack(spacing: Theme.s1) {
            Text(TodoTimeFormatters.display.string(from: date))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEnabled ? Theme.ink : Theme.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                stepButton(systemName: "chevron.up", minutes: stepMinutes)
                stepButton(systemName: "chevron.down", minutes: -stepMinutes)
            }
            .frame(width: 22)
        }
        .padding(.leading, Theme.s2)
        .padding(.trailing, 3)
        .frame(height: 30)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func stepButton(systemName: String, minutes: Int) -> some View {
        Button {
            guard isEnabled,
                  let next = Calendar.current.date(byAdding: .minute, value: minutes, to: date)
            else { return }
            onChange(next)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 20, height: 13)
        }
        .buttonStyle(.clickable)
        .disabled(!isEnabled)
        .help(minutes > 0 ? "Later" : "Earlier")
    }
}

private enum TodoTimeFormatters {
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct TodoSectionHeader: View {
    var title: String
    var detail: String

    var body: some View {
        HStack {
            Eyebrow(title.uppercased())
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(Theme.body(13, .medium))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }
}

private struct TodoEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            Text("Nothing planned")
                .font(Theme.body(18, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add a task above. Add a time when it belongs on the day plan.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(2)
        }
        .padding(Theme.s5)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
    }
}

private struct TodoPlanRow: View {
    @EnvironmentObject private var model: ClockioAppModel
    var todo: TodoItem
    var isCompact: Bool
    @State private var draftTitle: String

    init(todo: TodoItem, isCompact: Bool) {
        self.todo = todo
        self.isCompact = isCompact
        self._draftTitle = State(initialValue: todo.title)
    }

    var body: some View {
        HStack(spacing: Theme.s3) {
            Button {
                model.toggleTodoDone(id: todo.id)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(todo.isDone ? Theme.accent.opacity(0.25) : Theme.inkTertiary.opacity(0.42), lineWidth: 1.5)
                    if todo.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .frame(width: isCompact ? 22 : 28, height: isCompact ? 22 : 28)
            }
            .buttonStyle(.clickableCircle)
            .help(todo.isDone ? "Mark active" : "Complete task")

            TextField("Task", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(Theme.body(isCompact ? 13 : 16, .medium))
                .foregroundStyle(todo.isDone ? Theme.inkTertiary : Theme.ink)
                .strikethrough(todo.isDone, color: Theme.inkTertiary)
                .lineLimit(1)
                .onSubmit(commitTitle)
                .onDisappear(perform: commitTitle)
                .onChange(of: todo.title) { _, title in
                    if draftTitle != title {
                        draftTitle = title
                    }
                }

            Spacer(minLength: 0)

            scheduleControl

            Button {
                model.deleteTodo(id: todo.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.clickableCircle)
            .help("Delete task")
        }
        .padding(.horizontal, isCompact ? Theme.s3 : Theme.s4)
        .frame(height: isCompact ? 44 : 58)
        .background(todo.isDone ? Theme.surfaceSunken.opacity(0.58) : Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var scheduleControl: some View {
        if let scheduledDate {
            CompactTimeControl(date: scheduledDate) { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.setTodoSchedule(id: todo.id, hour: components.hour, minute: components.minute)
            }
            .frame(width: isCompact ? 104 : 114)
            Button {
                model.setTodoSchedule(id: todo.id, hour: nil, minute: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.clickableCircle)
            .help("Clear time")
        } else {
            Button {
                model.setTodoSchedule(id: todo.id, hour: 15, minute: 0)
            } label: {
                Label("Anytime", systemImage: "clock")
                    .font(Theme.body(12, .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, Theme.s2)
                    .frame(height: 28)
                    .background(Theme.surfaceSunken, in: Capsule())
            }
            .buttonStyle(.clickable)
            .help("Add time")
        }
    }

    private var scheduledDate: Date? {
        guard let hour = todo.scheduledHour, let minute = todo.scheduledMinute else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private func commitTitle() {
        model.updateTodoTitle(id: todo.id, title: draftTitle)
    }
}

private struct CompletedTodoPanel: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            TodoSectionHeader(title: "Done", detail: "")
            if model.completedTodos.isEmpty {
                Text("Completed tasks land here.")
                    .font(Theme.body(13, .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            } else {
                VStack(spacing: Theme.s2) {
                    ForEach(model.completedTodos.prefix(4)) { todo in
                        TodoPlanRow(todo: todo, isCompact: true)
                    }
                }
            }
        }
    }
}

private struct CalendarPanel: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            TodoSectionHeader(title: "Calendar", detail: "")
            if model.calendarStatus == .denied {
                Text("Calendar access was denied. Enable it in System Settings → Privacy & Security → Calendars.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.calendarEvents.isEmpty {
                Text("No events today.")
                    .font(Theme.body(13, .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            } else {
                VStack(spacing: Theme.s2) {
                    ForEach(model.calendarEvents.prefix(6)) { event in
                        CalendarEventRow(event: event)
                    }
                }
            }
        }
    }
}

private struct CalendarEventRow: View {
    var event: CalendarEvent

    var body: some View {
        HStack(spacing: Theme.s3) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent.opacity(0.85))
                .frame(width: 20)
            Text(event.timeText ?? "All-day")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 58, alignment: .leading)
            Text(event.title)
                .font(Theme.body(14, .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.s3)
        .frame(height: 44)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

private struct StageView: View {
    private let railHeight: CGFloat = 140
    private let stageSpacing: CGFloat = Theme.s4
    private let topBarAllowance: CGFloat = 56

    var body: some View {
        GeometryReader { geometry in
            let calculatedPreviewHeight = geometry.size.height - topBarAllowance - Theme.s5 - Theme.s4 - stageSpacing - railHeight
            let previewHeight = max(320, min(calculatedPreviewHeight, geometry.size.height * 0.64))

            VStack(spacing: stageSpacing) {
                PreviewCard()
                    .frame(maxWidth: .infinity)
                    .frame(height: previewHeight)
                BackgroundRail()
                    .frame(height: railHeight)
            }
            .padding(.top, Theme.s5)
            .padding(.horizontal, Theme.s6)
            .padding(.bottom, Theme.s4)
        }
    }
}

private struct PreviewCard: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        PointerParallax { unit in
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ZStack(alignment: .top) {
                    // Far layer: the animated scene, overscanned so parallax never bares an edge.
                    // Only the background drifts with the pointer — subtly. The slight
                    // overscan hides the edges as it moves. The clock stays put.
                    BackgroundSceneView(
                        background: model.renderedBackground,
                        speed: model.settings.motion / 100,
                        nightMode: model.isNightModeActive
                    )
                    .scaleEffect(1.06)
                    .parallaxOffset(unit, depth: -9)

                    PointerSheen(unit: unit, intensity: 0.14)

                    ClockFaceView(
                        style: model.settings.clockStyle,
                        date: timeline.date,
                        settings: model.settings,
                        background: model.renderedBackground,
                        todos: model.visibleTodos,
                        nightMode: model.isNightModeActive
                    )

                    // Controls stay anchored (not parallaxed) so they remain easy targets.
                    HStack {
                        PreviewControl(systemName: "arrow.up.left.and.arrow.down.right", help: "Open fullscreen preview") {
                            model.startScreensaver()
                        }
                        Spacer()
                    }
                    .padding(Theme.s4)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 50, x: 0, y: 28)
            }
        }
    }
}

private struct PreviewControl: View {
    var systemName: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            IconGlyph(systemName: systemName)
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.clickable)
        .help(help)
    }
}

private struct BackgroundRail: View {
    @EnvironmentObject private var model: ClockioAppModel
    @State private var focusedBackgroundId: String?

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: Theme.s2) {
                HStack(spacing: Theme.s3) {
                    Eyebrow("BACKGROUND")
                    Spacer()
                    RailControlButton(systemName: "chevron.left") { moveRail(by: -1, proxy: proxy) }
                        .help("Previous background")
                    RailControlButton(systemName: "chevron.right") { moveRail(by: 1, proxy: proxy) }
                        .help("Next background")
                }
                .padding(.horizontal, Theme.s1)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.s3) {
                        ForEach(model.availableBackgrounds) { background in
                            backgroundTile(background, proxy: proxy)
                                .id(background.id)
                        }
                    }
                    .padding(.horizontal, Theme.s1)
                    .padding(.bottom, Theme.s2)
                }
                .frame(height: 104)
                .onAppear {
                    focusedBackgroundId = model.settings.backgroundId
                    scrollToFocused(proxy: proxy)
                }
                .onChange(of: model.settings.backgroundId) { _, id in
                    focusedBackgroundId = id
                    scrollToFocused(proxy: proxy)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func backgroundTile(_ background: ClockBackground, proxy: ScrollViewProxy) -> some View {
        let isSelected = model.settings.backgroundId == background.id
        return Button {
            focusedBackgroundId = background.id
            model.selectBackground(background.id)
            withAnimation(.smooth(duration: 0.3)) {
                proxy.scrollTo(background.id, anchor: .center)
            }
        } label: {
            ZStack(alignment: .topLeading) {
                BackgroundThumb(background: background, cornerRadius: Theme.rMd)
                VStack(alignment: .leading) {
                    Text(background.scene.label.uppercased())
                        .font(Theme.eyebrow(9))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, Theme.s2)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.22), in: Capsule())
                    Spacer()
                    Text(background.name)
                        .font(Theme.body(13, .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.s3)
            }
            .frame(width: 134, height: 92)
            .contentShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2.5)
            }
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 16 : 8, y: 6)
        }
        .buttonStyle(.clickable)
    }

    private func moveRail(by offset: Int, proxy: ScrollViewProxy) {
        let backgrounds = model.availableBackgrounds
        guard !backgrounds.isEmpty else { return }
        let currentId = focusedBackgroundId ?? model.settings.backgroundId
        let currentIndex = backgrounds.firstIndex { $0.id == currentId } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), backgrounds.count - 1)
        let nextId = backgrounds[nextIndex].id
        focusedBackgroundId = nextId
        withAnimation(.smooth(duration: 0.3)) {
            proxy.scrollTo(nextId, anchor: .center)
        }
    }

    private func scrollToFocused(proxy: ScrollViewProxy) {
        guard let id = focusedBackgroundId else { return }
        withAnimation(.smooth(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

private struct RailControlButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            IconGlyph(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 30, height: 28)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.clickable)
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorPanel(title: "CLOCK STYLE") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.s3), count: 3), spacing: Theme.s3) {
                        ForEach(ClockStyle.allCases) { style in
                            Button {
                                model.selectClockStyle(style)
                            } label: {
                                VStack(spacing: Theme.s2) {
                                    StylePreview(style: style)
                                        .frame(width: 56, height: 56)
                                    Text(style.name)
                                        .font(Theme.body(12))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(minHeight: 28)
                                }
                                .foregroundStyle(model.settings.clockStyle == style ? Theme.accent : Theme.inkSecondary)
                                .padding(.vertical, Theme.s2)
                                .padding(.horizontal, Theme.s1)
                                .frame(maxWidth: .infinity)
                                .background(model.settings.clockStyle == style ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                            }
                            .buttonStyle(.clickable)
                        }
                    }
                }

                InspectorPanel(title: "BACKGROUND") {
                    Picker("Background", selection: Binding(get: {
                        model.settings.backgroundId
                    }, set: { id in
                        model.selectBackground(id)
                    })) {
                        ForEach(model.availableBackgrounds) { background in
                            Text(background.name).tag(background.id)
                        }
                    }
                    .labelsHidden()

                    HStack(spacing: Theme.s2) {
                        SecondaryButton(title: "Shuffle", systemName: "shuffle") {
                            model.shuffleBackground()
                        }
                        SecondaryButton(title: "Image", systemName: "photo") {
                            model.chooseCustomBackground()
                        }
                    }

                    if model.currentBackground.scene == .image,
                       model.settings.customBackgroundPath != nil,
                       !model.settings.customBackgroundName.isEmpty {
                        Text("Imported: \(model.settings.customBackgroundName)")
                            .font(Theme.body(12, .medium))
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, Theme.s1)
                    }

                    if model.currentBackground.customizable {
                        PaletteEditor(background: model.currentBackground)
                            .padding(.top, Theme.s2)
                    }
                }

                InspectorPanel(title: "MOTION") {
                    VStack(alignment: .leading, spacing: Theme.s3) {
                        HStack {
                            Text("Speed")
                                .font(Theme.body(13, .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(Int(model.settings.motion))")
                                .font(Theme.eyebrow(12))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        MinimalSlider(value: Binding(get: {
                            model.settings.motion
                        }, set: { value in
                            model.setMotion(value)
                        }), range: 8...100)
                    }
                }

                InspectorPanel(title: "INFO", divider: false) {
                    Group {
                        Toggle("Show Temperature", isOn: Binding(get: {
                            model.settings.showTemperature
                        }, set: { value in
                            model.settings.showTemperature = value
                        }))
                        Toggle("Show To-Dos", isOn: Binding(get: {
                            model.settings.showTodos
                        }, set: { value in
                            model.settings.showTodos = value
                        }))
                        Toggle("Show Date", isOn: Binding(get: {
                            model.settings.showDate
                        }, set: { value in
                            model.settings.showDate = value
                        }))
                        Toggle("Show Seconds", isOn: Binding(get: {
                            model.settings.showSeconds
                        }, set: { value in
                            model.settings.showSeconds = value
                        }))
                    }
                    .toggleStyle(.switch)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink)

                    if model.settings.showTemperature {
                        Text(model.temperatureStatus)
                            .font(Theme.body(12, .medium))
                            .foregroundStyle(Theme.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        model.startScreensaver()
                    } label: {
                        Label("Start Screensaver", systemImage: "play.fill")
                            .font(Theme.body(15, .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, Theme.s2)
                }
            }
            .padding(.top, Theme.s6)
            .padding(.horizontal, Theme.s4)
            .padding(.bottom, Theme.s5)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: ClockioAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s5) {
                Card(radius: Theme.rLg, padding: Theme.s6) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: Theme.s3) {
                            Eyebrow("SETTINGS")
                            Text("General")
                                .font(Theme.display(56, .bold))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: Theme.s2) {
                                Circle()
                                    .fill(model.screensaverRunning ? Theme.accent : Theme.accent.opacity(0.35))
                                    .frame(width: 8, height: 8)
                                Text(model.screensaverRunning ? "Active" : "Ready")
                                    .font(Theme.body(13, .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("\(NSScreen.screens.count) display\(NSScreen.screens.count == 1 ? "" : "s")")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                            .padding(.horizontal, Theme.s3)
                            .frame(height: 34)
                            .background(Theme.surfaceSunken, in: Capsule())

                            if let status = model.systemStatusMessage {
                                Text(status)
                                    .font(Theme.body(12, .medium))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        Button {
                            model.startScreensaver()
                        } label: {
                            Label("Start screensaver", systemImage: "play.fill")
                                .font(Theme.body(15, .semibold))
                                .frame(width: 184, height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

	                HStack(alignment: .top, spacing: Theme.s5) {
	                    SettingsPanel(title: "APP", trailing: "MACOS") {
	                        SettingsToggle("Launch at login", isOn: Binding(get: {
	                            model.settings.launchAtLogin
                        }, set: { value in
                            model.settings.launchAtLogin = value
                        }))
                        SettingsToggle("Hide Dock icon", isOn: Binding(get: {
                            model.settings.hideDock
                        }, set: { value in
                            model.settings.hideDock = value
                        }))
                    }

                    SettingsPanel(title: "IDLE TIMER", trailing: model.settings.autoStartScreensaver ? "\(model.settings.idleMinutes) MIN" : "OFF") {
                        SettingsToggle("Start after inactivity", isOn: Binding(get: {
                            model.settings.autoStartScreensaver
                        }, set: { value in
                            model.settings.autoStartScreensaver = value
                        }))
                        Picker("After", selection: Binding(get: {
                            model.settings.idleMinutes
                        }, set: { value in
                            model.settings.idleMinutes = value
                            model.settings.autoStartScreensaver = true
                        })) {
                            ForEach([1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
	                        .disabled(!model.settings.autoStartScreensaver)
	                    }
	                }

	                SettingsPanel(title: "APPEARANCE", trailing: model.appearanceStatusText.uppercased()) {
	                    SettingsToggle("Automatic day/night", isOn: Binding(get: {
	                        model.settings.autoDayNightMode
	                    }, set: { value in
	                        model.settings.autoDayNightMode = value
	                    }))

	                    HStack(spacing: Theme.s2) {
	                        Label(model.isNightModeActive ? "Night colors" : "Day colors", systemImage: model.isNightModeActive ? "moon.fill" : "sun.max.fill")
	                            .font(Theme.body(13, .semibold))
	                            .foregroundStyle(model.isNightModeActive ? Color(red: 0.95, green: 0.75, blue: 0.48) : Theme.accent)
	                        Spacer()
	                        Text(model.appearanceScheduleText)
	                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
	                            .foregroundStyle(Theme.inkTertiary)
	                    }
	                    .padding(.horizontal, Theme.s3)
	                    .frame(height: 38)
	                    .background(Theme.surfaceSunken, in: Capsule())

	                    Text("Follows your location's sunset and sunrise.")
	                        .font(Theme.body(12))
	                        .foregroundStyle(Theme.inkTertiary)
	                        .fixedSize(horizontal: false, vertical: true)
	                }

	                SettingsPanel(title: "CALENDAR", trailing: model.settings.showCalendarEvents ? "ON" : "OFF") {
                    SettingsToggle("Show calendar events", isOn: Binding(get: {
                        model.settings.showCalendarEvents
                    }, set: { value in
                        model.setShowCalendarEvents(value)
                    }))
                    Text("Shows today's events from your Calendar — including Google calendars added to macOS — in the to-do list and screensaver agenda.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.calendarStatus == .denied {
                        Text("Calendar access was denied. Turn it on in System Settings → Privacy & Security → Calendars.")
                            .font(Theme.body(12, .medium))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Theme.s6)
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    var title: String
    var trailing: String
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.s4) {
                Eyebrow(title, trailing: trailing)
                content
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsToggle: View {
    var title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(Theme.body(15, .medium))
                .foregroundStyle(Theme.ink)
        }
        .toggleStyle(.switch)
        .padding(Theme.s3)
        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
    }
}

private struct InspectorPanel<Content: View>: View {
    var title: String
    var divider: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            Eyebrow(title)
            content
        }
        .padding(.vertical, Theme.s5)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
    }
}

private struct SecondaryButton: View {
    var title: String
    var systemName: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s1) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(Theme.body(13, .medium))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
        }
        .buttonStyle(.clickable)
    }
}

private struct PaletteEditor: View {
    @EnvironmentObject private var model: ClockioAppModel
    var background: ClockBackground

    var body: some View {
        HStack(spacing: Theme.s2) {
            ForEach(Array(background.gradient.enumerated()), id: \.offset) { index, hex in
                ColorPicker("", selection: Binding(get: {
                    Color(hex: hex)
                }, set: { color in
                    model.setPaletteColor(backgroundId: background.id, index: index, hex: NSColor(color).hexString)
                }))
                .labelsHidden()
                .frame(width: 34, height: 34)
            }
            Spacer()
            Button("Reset") {
                model.resetPalette(backgroundId: background.id)
            }
            .buttonStyle(.bordered)
            .font(Theme.body(12, .medium))
        }
    }
}

private struct StylePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    var style: ClockStyle

    private var previewInk: Color {
        colorScheme == .dark ? .white.opacity(0.86) : .black.opacity(0.78)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .fill(background)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }

            switch style {
            case .analog:
                Circle().stroke(previewInk, lineWidth: 1.4).frame(width: 36, height: 36)
            case .flip:
                Text("12 24").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            case .terminal:
                Text("12:24").font(.system(size: 13, weight: .regular, design: .monospaced)).foregroundStyle(Color(red: 0.72, green: 1, blue: 0.86))
            case .paint:
                Text("Mar 13").font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(.white)
            default:
                Text("12:24").font(.system(size: 15, weight: .regular, design: .rounded)).foregroundStyle(previewInk)
            }
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .paint:
            AnyShapeStyle(LinearGradient(colors: [Color(hex: "C25A38"), Color(hex: "E0A04A")], startPoint: .leading, endPoint: .trailing))
        case .horizon:
            AnyShapeStyle(LinearGradient(colors: [Color(hex: "6BA9C8"), Color(hex: "E8B6A0")], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .flip:
            AnyShapeStyle(Color(hex: "201E1A"))
        case .terminal:
            AnyShapeStyle(Color(red: 0.02, green: 0.08, blue: 0.06))
        default:
            AnyShapeStyle(Theme.surfaceSunken)
        }
    }
}

private struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.canvas, Theme.canvasDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            if colorScheme == .light {
                RadialGradient(
                    colors: [.white.opacity(0.5), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 620
                )
            } else {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.045),
                        .clear,
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}
