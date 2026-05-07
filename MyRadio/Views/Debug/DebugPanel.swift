import SwiftUI

struct DebugPanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            debugHeader
            debugContent
        }
        .background(colors.bgDebug)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(colors.borderDebug)
                .frame(height: 0.5)
        }
    }

    // MARK: - Header

    private var debugHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(colors.statusOk)
                    .frame(width: 6, height: 6)
                Text("DEVTOOLS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
            }
            .padding(.leading, 12)

            debugTabs
                .padding(.leading, 12)

            Spacer()

            debugActions
                .padding(.trailing, 8)
        }
        .frame(height: AppLayout.debugHeadHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.borderDebug)
                .frame(height: 0.5)
        }
    }

    private var debugTabs: some View {
        HStack(spacing: 2) {
            ForEach(DebugTab.allCases) { tab in
                DebugTabButton(
                    tab: tab,
                    isActive: state.activeDebugTab == tab,
                    badge: badgeCount(for: tab)
                ) {
                    state.activeDebugTab = tab
                }
            }
        }
    }

    private func badgeCount(for tab: DebugTab) -> Int? {
        switch tab {
        case .logs:    return MockDebug.logs.count
        case .network: return MockDebug.network.count
        case .stream:  return nil
        case .icy:     return nil
        case .servers: return MockDebug.servers.count
        }
    }

    private var debugActions: some View {
        HStack(spacing: 2) {
            debugActionButton("line.3.horizontal.decrease")
            debugActionButton("doc.on.doc")
            debugActionButton("arrow.down.doc")
            debugActionButton("trash")
            debugActionButton("chevron.down") {
                state.logsVisible = false
            }
        }
    }

    private func debugActionButton(_ systemName: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var debugContent: some View {
        switch state.activeDebugTab {
        case .logs:    LogsTabView()
        case .network: NetworkTabView()
        case .stream:  StreamTabView()
        case .icy:     ICYTabView()
        case .servers: ServersTabView()
        }
    }
}

// MARK: - Tab button

private struct DebugTabButton: View {
    @Environment(\.appColors) private var colors

    let tab: DebugTab
    let isActive: Bool
    let badge: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tab.label.uppercased())
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.3)

                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isActive ? colors.accent.fg : colors.fgDebug2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isActive
                                ? colors.accent.accent.opacity(0.25)
                                : colors.fgDebug2.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(isActive ? colors.accent.accent : colors.fgDebug2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? colors.accent.accent.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logs tab

private struct LogsTabView: View {
    @Environment(\.appColors) private var colors
    @State private var levelFilter: LogLine.LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            filterToolbar
            Divider().overlay(colors.borderDebug)
            logList
        }
    }

    private var filterToolbar: some View {
        HStack(spacing: 6) {
            ForEach(filterOptions, id: \.label) { option in
                Button {
                    levelFilter = option.level
                } label: {
                    Text(option.label.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.3)
                        .foregroundStyle(
                            levelFilter == option.level
                                ? (option.level == nil ? colors.fgDebug : levelColor(option.level!))
                                : colors.fgDebug2
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            levelFilter == option.level
                                ? (option.level == nil ? colors.fgDebug : levelColor(option.level!)).opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 3)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("filter logs… ↵")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(colors.fgDebug2)
                        .padding(.leading, 8)
                }
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )

            Button {
                autoScroll.toggle()
            } label: {
                HStack(spacing: 3) {
                    Text("auto-scroll")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Circle()
                        .fill(autoScroll ? colors.statusOk : colors.fgDebug2.opacity(0.4))
                        .frame(width: 5, height: 5)
                }
                .foregroundStyle(colors.fgDebug2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var filterOptions: [(label: String, level: LogLine.LogLevel?)] {
        [
            ("all", nil),
            ("info", .info),
            ("warn", .warn),
            ("error", .error),
            ("debug", .debug),
        ]
    }

    private var filteredLogs: [LogLine] {
        MockDebug.logs.filter { line in
            if let filter = levelFilter, line.level != filter { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return line.message.lowercased().contains(q)
                    || line.source.lowercased().contains(q)
            }
            return true
        }
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredLogs) { line in
                    logRow(line)
                }
            }
        }
    }

    private func logRow(_ line: LogLine) -> some View {
        HStack(spacing: 12) {
            Text(line.time)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)

            levelBadge(line.level)
                .frame(width: 50, alignment: .center)

            HStack(spacing: 0) {
                Text(line.message)
                    .font(Typography.debugLog)
                    .foregroundStyle(colors.fgDebug)
                    .lineLimit(1)
                Text(line.source)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(colors.bgDebug)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colors.borderDebug)
                .frame(height: 0.5)
        }
    }

    private func levelBadge(_ level: LogLine.LogLevel) -> some View {
        Text(level.rawValue.uppercased())
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(levelFg(level))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(levelColor(level).opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
    }

    private func levelColor(_ level: LogLine.LogLevel) -> Color {
        switch level {
        case .info:  return colors.statusInfo
        case .warn:  return colors.statusWarn
        case .error: return colors.statusErr
        case .debug: return colors.fgDebug2
        }
    }

    private func levelFg(_ level: LogLine.LogLevel) -> Color {
        switch level {
        case .info:  return colors.statusInfo
        case .warn:  return colors.statusWarn
        case .error: return colors.statusErr
        case .debug: return colors.fgDebug2
        }
    }
}

// MARK: - Network tab

private struct NetworkTabView: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                netHeader
                ForEach(MockDebug.network) { line in
                    netRow(line)
                }
            }
        }
    }

    private var netHeader: some View {
        HStack(spacing: 0) {
            headerCell("Time",   width: 70)
            headerCell("Method", width: 50)
            headerCell("Status", width: 60)
            headerCell("URL",    width: nil)
            headerCell("Time",   width: 70)
            headerCell("Size",   width: 60)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(colors.bgDebugRow)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.borderDebug).frame(height: 0.5)
        }
    }

    private func headerCell(_ title: String, width: CGFloat?) -> some View {
        Group {
            if let w = width {
                Text(title)
                    .frame(width: w, alignment: .leading)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        .tracking(0.3)
        .foregroundStyle(colors.fgDebug2)
    }

    private func netRow(_ line: MockDebug.NetLine) -> some View {
        HStack(spacing: 0) {
            Text(line.time)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 70, alignment: .leading)

            Text(line.method)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(colors.statusInfo)
                .frame(width: 50, alignment: .leading)

            statusBadge(line.status)
                .frame(width: 60, alignment: .leading)

            HStack(spacing: 4) {
                if line.isStream {
                    Text("STREAM")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(colors.accent.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(colors.accent.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                }
                Text(line.url)
                    .font(Typography.debugLog)
                    .foregroundStyle(colors.fgDebug)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(line.ms)ms")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(line.ms > 1000 ? colors.statusWarn : colors.fgDebug2)
                .frame(width: 70, alignment: .trailing)

            Text(line.size)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.borderDebug).frame(height: 0.5)
        }
    }

    private func statusBadge(_ status: Int) -> some View {
        Text("\(status)")
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: Int) -> Color {
        if status == 0 { return colors.statusErr }
        if status == 304 { return colors.statusWarn }
        if status >= 200 && status < 300 { return colors.statusOk }
        if status >= 400 { return colors.statusErr }
        return colors.fgDebug2
    }
}

// MARK: - Stream tab

private struct StreamTabView: View {
    @Environment(\.appColors) private var colors

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                statCard(title: "Bitrate", value: "128", unit: "kbps")
                statCard(title: "Codec", value: "MP3", detail: "44.1 kHz · 2ch")
                meterCard(title: "Buffer", value: "8.2", unit: "s", fill: 0.82, color: colors.accent.accent)
                meterCard(title: "Latency", value: "142", unit: "ms", fill: 0.30, color: colors.statusOk)
                statCard(title: "Reconnects", value: "2", unit: nil)
                statCard(title: "Data received", value: "12.4", unit: "MB")
                statCard(title: "Drops", value: "0", unit: nil)
                urlCard(title: "Stream URL", url: "https://stream.radiofrance.fr/fip/fip.m3u8")
            }
            .padding(12)
        }
    }

    private func statCard(title: String, value: String, unit: String? = nil, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(colors.fgDebug2)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
                if let u = unit {
                    Text(u)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(colors.fgDebug2)
                }
            }

            if let d = detail {
                Text(d)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 6))
    }

    private func meterCard(title: String, value: String, unit: String, fill: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(colors.fgDebug2)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
                Text(unit)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colors.fgDebug2.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 6))
    }

    private func urlCard(title: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(colors.fgDebug2)

            Text(url)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.accent.accent)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - ICY metadata tab

private struct ICYTabView: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("Last frame")
                        .foregroundStyle(colors.fgDebug)
                    Text("·")
                        .foregroundStyle(colors.fgDebug2)
                    Text("14:48:02.412")
                        .foregroundStyle(colors.fgDebug2)
                    Text("·")
                        .foregroundStyle(colors.fgDebug2)
                    Text("refresh interval 16000 bytes")
                        .foregroundStyle(colors.fgDebug2)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().overlay(colors.borderDebug)

                ForEach(Array(MockDebug.icyData.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 0) {
                        Text(pair.key)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(colors.statusInfo)
                            .frame(width: 140, alignment: .leading)

                        Text(pair.value)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(colors.fgDebug)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(colors.borderDebug).frame(height: 0.5)
                    }
                }
            }
            .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 6))
            .padding(12)
        }
    }
}

// MARK: - Servers tab

private struct ServersTabView: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Active server pool")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.fgDebug)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("DNS:")
                            .foregroundStyle(colors.fgDebug2)
                        Text("all.api.radio-browser.info")
                            .foregroundStyle(colors.fgDebug)
                        Text("·")
                            .foregroundStyle(colors.fgDebug2)
                        Text("resolved \(MockDebug.servers.count) hosts")
                            .foregroundStyle(colors.fgDebug2)
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(MockDebug.servers) { server in
                        serverRow(server)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func serverRow(_ server: MockDebug.ServerEntry) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor(server))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.host)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
                HStack(spacing: 4) {
                    Text(server.ip)
                        .foregroundStyle(colors.fgDebug2)
                    Text("·")
                        .foregroundStyle(colors.fgDebug2)
                    Text(server.region)
                        .foregroundStyle(colors.fgDebug2)
                }
                .font(.system(size: 9.5, design: .monospaced))
            }

            Spacer()

            if let lat = server.latency {
                Text("\(lat)ms")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(lat > 100 ? colors.statusWarn : colors.fgDebug2)
            } else {
                Text("—")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
            }

            Text(statusLabel(server))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(statusLabelColor(server))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusLabelColor(server).opacity(0.12), in: RoundedRectangle(cornerRadius: 3))

            if !server.isActive && !server.isBroken {
                Button {
                } label: {
                    Text("Switch")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(colors.accent.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(colors.accent.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(server.isActive ? colors.accent.accent.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.borderDebug).frame(height: 0.5)
        }
    }

    private func dotColor(_ server: MockDebug.ServerEntry) -> Color {
        if server.isBroken { return colors.statusErr }
        if server.isActive { return colors.accent.accent }
        return colors.statusOk
    }

    private func statusLabel(_ server: MockDebug.ServerEntry) -> String {
        if server.isBroken { return "DOWN" }
        if server.isActive { return "ACTIVE" }
        return "OK"
    }

    private func statusLabelColor(_ server: MockDebug.ServerEntry) -> Color {
        if server.isBroken { return colors.statusErr }
        if server.isActive { return colors.accent.accent }
        return colors.statusOk
    }
}
