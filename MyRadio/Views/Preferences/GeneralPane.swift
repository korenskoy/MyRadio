//
//  GeneralPane.swift
//  MyRadio
//
//  Language + launch & startup + confirm-quit. Mirrors GeneralPane in
//  docs/design/myradio/project/preferences.jsx, but only the toggles that
//  are actually wired (close-behavior segmented control is omitted —
//  menu-bar mode is a separate feature, not a stubbed toggle).
//

import SwiftUI

struct GeneralPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General")
                    .font(.system(size: 22, weight: .bold))

                groupHeader("Language")
                languageGroup(state: state)

                groupHeader("Launch & startup")
                startupGroup(state: state)

                groupHeader("Behavior")
                behaviorGroup(state: state)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Language

    private func languageGroup(state: AppState) -> some View {
        @Bindable var state = state
        return groupBox {
            row(
                label: "App language",
                hint: "Takes effect after restart."
            ) {
                Picker("", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.nativeName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 180, maxWidth: 220)
            }
        }
    }

    // MARK: Launch & startup

    private func startupGroup(state: AppState) -> some View {
        @Bindable var state = state
        return groupBox {
            VStack(spacing: 0) {
                row(
                    label: "Launch at login",
                    hint: "Open MyRadio automatically when you sign in."
                ) {
                    Toggle(isOn: $state.launchAtLogin) { EmptyView() }
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                divider
                row(
                    label: "Restore last station on launch",
                    hint: "Re-selects the last station you played, but does not auto-play."
                ) {
                    Toggle(isOn: $state.restoreLastStation) { EmptyView() }
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                divider
                row(
                    label: "Resume playback on launch",
                    hint: "Auto-play the restored station if it was playing when you quit."
                ) {
                    Toggle(isOn: $state.resumePlaybackOnLaunch) { EmptyView() }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!state.restoreLastStation)
                }
            }
        }
    }

    // MARK: Behavior

    private func behaviorGroup(state: AppState) -> some View {
        @Bindable var state = state
        return groupBox {
            row(
                label: "Confirm quit while playing",
                hint: "Ask before quitting if a stream is currently playing."
            ) {
                Toggle(isOn: $state.confirmQuit) { EmptyView() }
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: Layout helpers — same shape as AdvancedPane / ShortcutsPane

    private func groupHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(.uppercase)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func groupBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func row<Trailing: View>(
        label: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}
