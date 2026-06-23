import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RadioBrowserKit

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
        case .logs:    return state.debugLog.entries.count
        case .network: return NetworkActivityLog.shared.records.isEmpty ? nil : NetworkActivityLog.shared.records.count
        case .stream:  return nil
        case .servers: return state.servers.isEmpty ? nil : state.servers.count
        }
    }

    private var debugActions: some View {
        HStack(spacing: 2) {
            debugActionButton("line.3.horizontal.decrease",
                              active: state.debugLog.logsNewestFirst) {
                state.debugLog.logsNewestFirst.toggle()
            }
            debugActionButton("doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.debugLog.asText(), forType: .string)
            }
            debugActionButton("arrow.down.doc") {
                saveLogsToFile()
            }
            debugActionButton("trash") {
                state.debugLog.clear()
            }
        }
    }

    private func saveLogsToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "myradio-debug.log"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // DevTools is intentionally English-only (see DebugTab.label), so the
        // alert text isn't localized.
        do {
            try state.debugLog.asText().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            state.debugLog.append(.error, "Failed to save logs: \(error.localizedDescription)", source: "devtools")
            let alert = NSAlert()
            alert.messageText = "Couldn’t save logs"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func debugActionButton(_ systemName: String, active: Bool = false, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(active ? colors.accent.accent : colors.fgDebug2)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }

    // MARK: - Tab content

    @ViewBuilder
    private var debugContent: some View {
        switch state.activeDebugTab {
        case .logs:    LogsTabView()
        case .network: NetworkTabView()
        case .stream:  StreamTabView()
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

// MARK: - Logs tab (real data from DebugLog)

private struct LogsTabView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var levelFilter: LogEntry.Level? = nil
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

    private var filterOptions: [(label: String, level: LogEntry.Level?)] {
        [
            ("all", nil),
            ("info", .info),
            ("warn", .warn),
            ("error", .error),
            ("debug", .debug),
        ]
    }

    private var filteredLogs: [LogEntry] {
        let base = state.debugLog.entries.filter { entry in
            if let filter = levelFilter, entry.level != filter { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return entry.message.lowercased().contains(q)
                    || entry.source.lowercased().contains(q)
            }
            return true
        }
        return state.debugLog.logsNewestFirst ? base.reversed() : base
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLogs) { entry in
                        logRow(entry).id(entry.id)
                    }
                }
            }
            .onChange(of: filteredLogs.count) { _, _ in scrollToNewest(proxy) }
            .onChange(of: autoScroll) { _, _ in scrollToNewest(proxy) }
        }
    }

    private func scrollToNewest(_ proxy: ScrollViewProxy) {
        guard autoScroll else { return }
        // Newest entry is first when sorted newest-first, otherwise last.
        let newest = state.debugLog.logsNewestFirst ? filteredLogs.first : filteredLogs.last
        guard let id = newest?.id else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(id, anchor: state.debugLog.logsNewestFirst ? .top : .bottom)
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.time)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)

            levelBadge(entry.level)
                .frame(width: 50, alignment: .center)

            HStack(spacing: 0) {
                Text(entry.message)
                    .font(Typography.debugLog)
                    .foregroundStyle(colors.fgDebug)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(entry.source)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
                    .padding(.leading, 8)
                    .textSelection(.enabled)
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

    private func levelBadge(_ level: LogEntry.Level) -> some View {
        Text(level.rawValue.uppercased())
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(levelFg(level))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(levelColor(level).opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
    }

    private func levelColor(_ level: LogEntry.Level) -> Color {
        switch level {
        case .info:  return colors.statusInfo
        case .warn:  return colors.statusWarn
        case .error: return colors.statusErr
        case .debug: return colors.fgDebug2
        }
    }

    private func levelFg(_ level: LogEntry.Level) -> Color {
        switch level {
        case .info:  return colors.statusInfo
        case .warn:  return colors.statusWarn
        case .error: return colors.statusErr
        case .debug: return colors.fgDebug2
        }
    }
}

// MARK: - Network tab (mock for now)

private struct NetworkTabView: View {
    @Environment(\.appColors) private var colors

    private var records: [NetworkActivityLog.Record] {
        NetworkActivityLog.shared.records.reversed()   // newest first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    netHeader
                    if records.isEmpty {
                        Text(verbatim: "No requests recorded yet")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(colors.fgDebug2)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ForEach(records) { rec in
                            netRow(rec)
                        }
                    }
                }
            }
            // Honest scope note — RadioBrowserKit issues its API calls through an
            // internal client we can't hook, so only our own requests show here.
            Text(verbatim: "App-issued requests only · RadioBrowserKit API calls aren’t captured")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colors.bgDebugRow)
        }
    }

    private static func sizeString(_ bytes: Int) -> String {
        bytes <= 0 ? "—" : ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    private var netHeader: some View {
        HStack(spacing: 0) {
            headerCell("Time",   width: 88)
            headerCell("Method", width: 50)
            headerCell("Status",   width: 60)
            headerCell("URL",      width: nil)
            headerCell("Duration", width: 70)
            headerCell("Size",     width: 60)
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

    private func netRow(_ rec: NetworkActivityLog.Record) -> some View {
        HStack(spacing: 0) {
            Text(rec.time)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(colors.fgDebug2)
                .frame(width: 88, alignment: .leading)

            Text(rec.method)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(colors.statusInfo)
                .frame(width: 50, alignment: .leading)

            statusBadge(rec.status)
                .frame(width: 60, alignment: .leading)

            Text(rec.url)
                .font(Typography.debugLog)
                .foregroundStyle(colors.fgDebug)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(rec.ms)ms")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(rec.ms > 1000 ? colors.statusWarn : colors.fgDebug2)
                .frame(width: 70, alignment: .trailing)

            Text(Self.sizeString(rec.bytes))
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

// MARK: - Stream tab (real data from StreamPlayer)

private struct StreamTabView: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        let player = state.streamPlayer
        let station = state.currentStation

        ScrollView {
            VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 12) {
                statCard(title: "Bitrate", value: player.currentBitrate > 0 ? String(format: "%.0f", player.currentBitrate) : (station?.bitrateFormatted ?? "—"), unit: player.currentBitrate > 0 ? "kbps" : nil)
                statCard(title: "Codec", value: station?.codec?.uppercased() ?? "—")
                meterCard(title: "Buffer", value: String(format: "%.1f", player.bufferHealth), unit: "s", fill: min(1, player.bufferHealth / 10), color: colors.accent.accent)
                statCard(title: "Latency", value: player.latency > 0 ? String(format: "%.1f", player.latency) : "—", unit: "s")
                statCard(title: "Reconnects", value: "\(player.reconnectCount)", unit: nil)
                statCard(title: "Data", value: formatBytes(player.dataReceived), unit: nil)
                statCard(title: "Status", value: player.isPlaying ? "Playing" : "Stopped", unit: nil)
                urlCard(title: "Stream URL", url: station?.urlResolved ?? station?.url ?? "—")
            }
            .padding(12)

            icySection
            }
        }
    }

    private var icySection: some View {
        let meta = state.streamPlayer.icyMetadata
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("ICY metadata")
                    .foregroundStyle(colors.fgDebug)
                Text("·")
                    .foregroundStyle(colors.fgDebug2)
                Text(meta.isEmpty ? "No stream active" : "\(meta.count) fields")
                    .foregroundStyle(colors.fgDebug2)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(colors.borderDebug)

            if meta.isEmpty {
                Text("Start playing a station to see ICY metadata")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(meta.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(spacing: 0) {
                        Text(key)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(colors.statusInfo)
                            .frame(width: 140, alignment: .leading)

                        Text(value)
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
        }
        .background(colors.bgDebugRow, in: RoundedRectangle(cornerRadius: 6))
        .padding(12)
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

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "—" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var idx = 0
        while value >= 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return idx == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[idx])
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

// MARK: - Servers tab (real Radio Browser mirrors)

private struct ServersTabView: View {
    @Environment(AppState.self) private var state
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
                        Text("resolved \(state.servers.count) hosts")
                            .foregroundStyle(colors.fgDebug2)
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                if state.servers.isEmpty {
                    Text(verbatim: "Loading mirrors…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(colors.fgDebug2)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    VStack(spacing: 0) {
                        ForEach(state.servers) { server in
                            serverRow(server)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .task { await state.loadServers() }
    }

    private func serverRow(_ server: StreamingServerMirror) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colors.statusOk)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.fgDebug)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    if let ip = server.ip, !ip.isEmpty {
                        Text(ip).foregroundStyle(colors.fgDebug2)
                    }
                    if let location = server.location, !location.isEmpty {
                        Text("·").foregroundStyle(colors.fgDebug2)
                        Text(location).foregroundStyle(colors.fgDebug2)
                    }
                }
                .font(.system(size: 9.5, design: .monospaced))
            }

            Spacer()

            if let url = server.url, !url.isEmpty {
                Text(url)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(colors.fgDebug2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.borderDebug).frame(height: 0.5)
        }
    }
}
