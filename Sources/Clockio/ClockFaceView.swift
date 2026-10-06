import ClockioCore
import SwiftUI

struct ClockFaceView: View {
    var style: ClockStyle
    var date: Date
    var settings: ClockioSettings
    var background: ClockBackground
    var todos: [TodoItem] = []
    var saver: Bool = false
    var nightMode: Bool = false
    var morningGreetingText: String? = nil

    private var foreground: Color {
        isLightScene ? Color.black.opacity(0.68) : Color.white.opacity(0.9)
    }

    private var isLightScene: Bool {
        background.isLightScene && !nightMode
    }

    private var hasVisibleTodos: Bool {
        settings.showTodos && todos.contains { !$0.isDone }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch style {
                case .digital:
                    DigitalClock(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                case .paint:
                    PaintClock(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                case .horizon:
                    HorizonClock(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                case .flip:
                    FlipClock(date: date, settings: settings, foreground: foreground, background: background, todos: todos, saver: saver, nightMode: nightMode)
                case .analog:
                    VStack(spacing: saver ? (hasVisibleTodos ? 24 : 34) : (hasVisibleTodos ? 12 : 18)) {
                        AnalogClock(date: date, showSeconds: settings.showSeconds, foreground: foreground)
                            .frame(width: analogSize, height: analogSize)
                        ClockFooter(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                    }
                case .minimal:
                    MinimalClock(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                case .terminal:
                    TerminalClock(date: date, settings: settings, todos: todos, saver: saver)
                }
            }

            morningGreeting
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: isLightScene ? .white.opacity(0.4) : .black.opacity(0.36), radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private var morningGreeting: some View {
        if let greeting = morningGreetingText {
            Text(greeting)
                .font(.system(size: saver ? 38 : 19, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(foreground.opacity(saver ? 0.72 : 0.62))
                .padding(.horizontal, saver ? 22 : 12)
                .frame(height: saver ? 52 : 28)
                .background(foreground.opacity(saver ? 0.075 : 0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(foreground.opacity(saver ? 0.12 : 0.08), lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, saver ? 82 : 28)
                .padding(.leading, saver ? 92 : 30)
                .allowsHitTesting(false)
        }
    }

    private var analogSize: CGFloat {
        if saver {
            hasVisibleTodos ? 380 : 440
        } else {
            hasVisibleTodos ? 260 : 300
        }
    }
}

private struct DigitalClock: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var todos: [TodoItem]
    var saver: Bool

    var body: some View {
        VStack(spacing: saver ? 32 : 20) {
            HStack(alignment: .firstTextBaseline, spacing: saver ? 24 : 12) {
                Text(hours)
                Text(":")
                    .opacity(0.58)
                    .frame(minWidth: saver ? 52 : 28)
                Text(minutes)
                if settings.showSeconds {
                    Text(seconds)
                        .font(.system(size: saver ? 76 : 36, weight: .light, design: .rounded))
                        .opacity(0.7)
                        .padding(.leading, saver ? 18 : 8)
                }
            }
            .font(.system(size: saver ? 320 : 158, weight: .light, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.36)
            .foregroundStyle(foreground)

            ClockFooter(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
        }
        .padding(.horizontal, saver ? 90 : 54)
    }

    private var hours: String { DateFormatters.hours.string(from: date) }
    private var minutes: String { DateFormatters.minutes.string(from: date) }
    private var seconds: String { DateFormatters.seconds.string(from: date) }
}

private struct PaintClock: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var todos: [TodoItem]
    var saver: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text(line)
                .font(.system(size: saver ? 72 : 46, weight: .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.48)
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground.opacity(0.94))

            if settings.showTemperature {
                Text(DisplayFormat.temperature(settings.temperature))
                    .font(.system(size: saver ? 28 : 18, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.72))
            }

            TodoPreviewList(settings: settings, todos: todos, foreground: foreground, saver: saver)
        }
        .padding(.horizontal, saver ? 120 : 54)
    }

    private var line: String {
        if settings.showDate {
            let dateText = DateFormatters.paintDate.string(from: date)
            let timeText = DateFormatters.ampm.string(from: date).replacingOccurrences(of: " ", with: "").lowercased()
            return "\(dateText) at \(timeText)\(settings.showSeconds ? ":\(DateFormatters.seconds.string(from: date))" : "")"
        }
        return DateFormatters.ampm.string(from: date).replacingOccurrences(of: " ", with: "").lowercased()
    }
}

private struct HorizonClock: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var todos: [TodoItem]
    var saver: Bool

    var body: some View {
        ZStack {
            HStack(spacing: saver ? 84 : 48) {
                if settings.showTemperature { Text(DisplayFormat.temperature(settings.temperature)) }
                if settings.showDate {
                    Text(DateFormatters.monthDay.string(from: date).uppercased())
                    Text(DateFormatters.weekday.string(from: date).uppercased())
                }
            }
            .font(.system(size: saver ? 26 : 17, weight: .semibold, design: .monospaced))
            .foregroundStyle(foreground.opacity(0.44))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, saver ? 110 : 70)
            .padding(.trailing, saver ? 130 : 72)

            VStack(alignment: .trailing, spacing: saver ? 20 : 12) {
                HStack(alignment: .top, spacing: saver ? 24 : 14) {
                    Text(DateFormatters.ampmNoMarker.string(from: date))
                        .font(.system(size: saver ? 180 : 96, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                    Text(DateFormatters.period.string(from: date))
                        .font(.system(size: saver ? 42 : 24, weight: .semibold, design: .monospaced))
                        .padding(.top, saver ? 42 : 22)
                    if settings.showSeconds {
                        Text(DateFormatters.seconds.string(from: date))
                            .font(.system(size: saver ? 48 : 28, weight: .semibold, design: .monospaced))
                            .padding(.top, saver ? 32 : 18)
                            .opacity(0.55)
                    }
                }
                TodoPreviewList(settings: settings, todos: todos, foreground: foreground, saver: saver)
            }
            .foregroundStyle(foreground.opacity(0.52))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, saver ? 128 : 70)
            .padding(.bottom, saver ? 98 : 56)
        }
    }
}

private struct FlipClock: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var background: ClockBackground
    var todos: [TodoItem]
    var saver: Bool
    var nightMode: Bool

    var body: some View {
        VStack(spacing: saver ? 32 : 18) {
            HStack(spacing: saver ? 22 : 14) {
                FlipUnit(value: DateFormatters.hours.string(from: date), saver: saver, light: background.isLightScene && !nightMode)
                Text(":")
                    .font(.system(size: saver ? 150 : 84, weight: .light, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.7))
                FlipUnit(value: DateFormatters.minutes.string(from: date), saver: saver, light: background.isLightScene && !nightMode)
                if settings.showSeconds {
                    FlipUnit(value: DateFormatters.seconds.string(from: date), saver: saver, light: background.isLightScene && !nightMode, small: true)
                }
            }
            ClockFooter(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
        }
    }
}

private struct FlipUnit: View {
    var value: String
    var saver: Bool
    var light: Bool
    var small: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: small ? 18 : 28, style: .continuous)
                .fill(light ? .white.opacity(0.54) : .white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: small ? 18 : 28, style: .continuous)
                        .stroke(.white.opacity(light ? 0.72 : 0.18), lineWidth: 1)
                }
            Rectangle()
                .fill(.black.opacity(light ? 0.16 : 0.38))
                .frame(height: 1)
            Text(value)
                .font(.system(size: small ? 44 : (saver ? 132 : 86), weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(light ? .black.opacity(0.74) : .white.opacity(0.92))
                .minimumScaleFactor(0.5)
        }
        .frame(width: small ? 82 : (saver ? 210 : 138), height: small ? 82 : (saver ? 190 : 126))
    }
}

private struct MinimalClock: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var todos: [TodoItem]
    var saver: Bool

    private var hasVisibleTodos: Bool {
        settings.showTodos && todos.contains { !$0.isDone }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(DateFormatters.hours.string(from: date))
            Text(DateFormatters.minutes.string(from: date))
                .opacity(0.52)
            if settings.showSeconds {
                Text(DateFormatters.seconds.string(from: date))
                    .font(.system(size: saver ? 58 : 32, weight: .light, design: .rounded))
                    .padding(.top, 22)
                    .opacity(0.58)
            }
            ClockFooter(date: date, settings: settings, foreground: foreground, todos: todos, saver: saver)
                .padding(.top, saver ? (hasVisibleTodos ? 26 : 38) : (hasVisibleTodos ? 14 : 22))
        }
        .font(.system(size: clockSize, weight: .ultraLight, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(foreground)
    }

    private var clockSize: CGFloat {
        if saver {
            hasVisibleTodos ? 184 : 212
        } else {
            hasVisibleTodos ? 104 : 124
        }
    }
}

private struct TerminalClock: View {
    var date: Date
    var settings: ClockioSettings
    var todos: [TodoItem]
    var saver: Bool

    var body: some View {
        VStack(spacing: saver ? 28 : 20) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .green.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: saver ? 820 : 520, height: 1)
            HStack(alignment: .firstTextBaseline, spacing: saver ? 22 : 12) {
                Text(DateFormatters.hours.string(from: date))
                Text(":").opacity(0.62).frame(minWidth: saver ? 42 : 24)
                Text(DateFormatters.minutes.string(from: date))
                if settings.showSeconds {
                    Text(DateFormatters.seconds.string(from: date))
                        .font(.system(size: saver ? 48 : 26, weight: .regular, design: .monospaced))
                        .opacity(0.62)
                        .padding(.leading, saver ? 16 : 8)
                }
            }
            .font(.system(size: saver ? 178 : 104, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.42)
            .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.86))

            HStack(spacing: 18) {
                Text("LOCAL")
                if settings.showDate { Text(DateFormatters.date.string(from: date).uppercased()) }
                if settings.showTemperature { Text(DisplayFormat.temperature(settings.temperature)) }
            }
            .font(.system(size: saver ? 18 : 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.86).opacity(0.62))

            TodoPreviewList(
                settings: settings,
                todos: todos,
                foreground: Color(red: 0.72, green: 1, blue: 0.86),
                saver: saver
            )
        }
        .padding(.horizontal, saver ? 120 : 50)
    }
}

private struct ClockFooter: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var todos: [TodoItem]
    var saver: Bool

    var body: some View {
        VStack(spacing: saver ? 18 : 10) {
            MetaLine(date: date, settings: settings, foreground: foreground, saver: saver)
            TodoPreviewList(settings: settings, todos: todos, foreground: foreground, saver: saver)
        }
    }
}

private struct TodoPreviewList: View {
    var settings: ClockioSettings
    var todos: [TodoItem]
    var foreground: Color
    var saver: Bool

    private var visibleTodos: [TodoItem] {
        guard settings.showTodos else { return [] }
        return Array(todos.filter { !$0.isDone }.prefix(3))
    }

    var body: some View {
        if !visibleTodos.isEmpty {
            VStack(spacing: saver ? 10 : 6) {
                ForEach(visibleTodos) { todo in
                    HStack(spacing: saver ? 8 : 8) {
                        Circle()
                            .strokeBorder(foreground.opacity(saver ? 0.34 : 0.42), lineWidth: saver ? 1.1 : 1.4)
                            .frame(width: saver ? 9 : 10, height: saver ? 9 : 10)
                        if let time = timeText(for: todo) {
                            Text(time)
                                .font(.system(size: saver ? 10 : 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(foreground.opacity(saver ? 0.48 : 0.62))
                                .frame(width: saver ? 34 : 42, alignment: .leading)
                        }
                        Text(todo.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: saver ? 13 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(saver ? 0.58 : 0.78))
                    .padding(.horizontal, saver ? 12 : 14)
                    .frame(width: saver ? 340 : 360, height: saver ? 25 : 28)
                    .background(foreground.opacity(saver ? 0.055 : 0.095), in: Capsule())
                    .overlay(Capsule().strokeBorder(foreground.opacity(saver ? 0.075 : 0.12), lineWidth: 1))
                }
            }
            .frame(maxWidth: saver ? 360 : 390)
        }
    }

    private func timeText(for todo: TodoItem) -> String? {
        guard let hour = todo.scheduledHour, let minute = todo.scheduledMinute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }
}

private struct MetaLine: View {
    var date: Date
    var settings: ClockioSettings
    var foreground: Color
    var saver: Bool

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: saver ? 18 : 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Circle()
                            .fill(foreground.opacity(0.48))
                            .frame(width: saver ? 7 : 5, height: saver ? 7 : 5)
                    }
                    Text(item)
                }
            }
            .font(.system(size: saver ? 44 : 27, weight: .regular, design: .rounded))
            .lineLimit(2)
            .minimumScaleFactor(0.58)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground.opacity(0.86))
        }
    }

    private var items: [String] {
        var values: [String] = []
        if settings.showDate {
            values.append(DateFormatters.date.string(from: date))
        }
        if settings.showTemperature {
            values.append(DisplayFormat.temperature(settings.temperature))
        }
        return values
    }
}

private struct AnalogClock: View {
    var date: Date
    var showSeconds: Bool
    var foreground: Color

    private var components: DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let seconds = Double(components.second ?? 0)
            let minutes = Double(components.minute ?? 0) + seconds / 60
            let hours = Double((components.hour ?? 0) % 12) + minutes / 60

            Canvas { context, _ in
                let radius = size * 0.42
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(foreground.opacity(0.55)), lineWidth: 1.5)

                for tick in 0..<60 {
                    let angle = Double(tick) * 6 - 90
                    let major = tick % 5 == 0
                    let outer = point(center: center, radius: radius * 0.92, angle: angle)
                    let inner = point(center: center, radius: radius * (major ? 0.78 : 0.84), angle: angle)
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(path, with: .color(foreground.opacity(major ? 0.72 : 0.34)), lineWidth: major ? 2.2 : 1.0)
                }

                drawHand(context: &context, center: center, radius: radius * 0.52, angle: hours * 30 - 90, width: 8, color: foreground.opacity(0.9))
                drawHand(context: &context, center: center, radius: radius * 0.72, angle: minutes * 6 - 90, width: 5, color: foreground.opacity(0.76))
                if showSeconds {
                    drawHand(context: &context, center: center, radius: radius * 0.78, angle: seconds * 6 - 90, width: 2, color: .orange.opacity(0.9))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(foreground))
            }
        }
    }

    private func drawHand(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double, width: CGFloat, color: Color) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: point(center: center, radius: radius, angle: angle))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}

private enum DateFormatters {
    static let hours: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH"
        return formatter
    }()

    static let minutes: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "mm"
        return formatter
    }()

    static let seconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ss"
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    static let paintDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let ampm: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mma"
        return formatter
    }()

    static let ampmNoMarker: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    static let period: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "a"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
