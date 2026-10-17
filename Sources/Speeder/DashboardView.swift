import Charts
import SpeederCore
import SwiftUI

enum AppPage: String, CaseIterable {
    case session = "Session"
    case statistics = "Statistics"
    case settings = "Settings"
    var icon: String { switch self { case .session: return "chart.xyaxis.line"; case .statistics: return "chart.bar.xaxis"; case .settings: return "slider.horizontal.3" } }
}

@MainActor
final class WindowRoute: ObservableObject {
    @Published var page: AppPage = .session
    @Published var showsOnboarding = false
}

struct DashboardView: View {
    @Environment(\.speederAccent) private var accent
    @ObservedObject var store: SpeedStore
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var route: WindowRoute
    @StateObject private var loginItem = LoginItemStore()
    @State private var confirmReset = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 9) {
                    Image(systemName: "waveform.path").font(.system(size: 20)).foregroundStyle(accent)
                    Text("Speeder").font(.system(size: 17, weight: .semibold, design: .rounded))
                }.padding(.top, 15)
                VStack(spacing: 6) {
                    ForEach(AppPage.allCases, id: \.self) { page in
                        Button { route.page = page } label: {
                            Label(LocalizedStringKey(page.rawValue), systemImage: page.icon)
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(route.page == page ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(route.page == page ? accent : .secondary)
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 7) {
                    Label("Made for your rhythm", systemImage: "leaf")
                    Text("Private. Local. In the moment.").font(.system(size: 10))
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(18).frame(width: 172).frame(maxHeight: .infinity)
                .background(.ultraThinMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if route.page == .session { session }
                    else if route.page == .statistics { StatisticsView(store: store) }
                    else { settings }
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in loginItem.refresh() }
        .sheet(isPresented: $route.showsOnboarding) {
            OnboardingView(store: store, preferences: preferences) { route.showsOnboarding = false }
        }
        .alert("Start a fresh session?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset session", role: .destructive) { store.reset() }
        } message: { Text("This clears the current session and graph. Your long-term history is kept.") }
    }

    private var session: some View {
        Group {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your typing, in focus.").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("A little insight into the way you work.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: store.togglePaused) {
                    Label(LocalizedStringKey(store.isPaused ? "Resume" : "Pause"), systemImage: store.isPaused ? "play" : "pause")
                }.controlSize(.small)
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT PACE").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(WPMFormatter.string(store.stats.currentWPM)).font(.system(size: 56, weight: .light, design: .rounded)).monospacedDigit()
                                Text("wpm").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        CaptureIndicator(store: store)
                    }
                    SpeedChart(points: store.history, goal: preferences.goal).frame(height: 160)
                    HStack {
                        Text("Recent rhythm").fontWeight(.medium)
                        Spacer()
                        Text("Hover for speed · pauses excluded")
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Surface { MetricView(title: "Session average", value: WPMFormatter.string(store.stats.averageWPM), unit: "wpm") }
                Surface { MetricView(title: "Session peak", value: WPMFormatter.string(store.stats.peakWPM), unit: "wpm") }
                Surface { MetricView(title: "Current burst", value: WPMFormatter.string(store.stats.burstWPM), unit: "wpm") }
            }
            HStack(alignment: .top, spacing: 12) {
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The session so far").font(.system(size: 13, weight: .semibold))
                        detail("Words completed", value: "\(store.stats.totalWords)")
                        detail("Keystrokes", value: "\(store.stats.totalKeystrokes)")
                        detail("Time spent typing", value: WPMFormatter.duration(store.stats.activeDuration))
                    }.frame(maxWidth: .infinity)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Find your pace").font(.system(size: 13, weight: .semibold))
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(preferences.goal))").font(.system(size: 28, weight: .light, design: .rounded))
                            Text("wpm goal").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(accent.opacity(0.12))
                                Capsule().fill(accent)
                                    .frame(width: geometry.size.width * min(store.stats.averageWPM / preferences.goal, 1))
                            }
                        }.frame(height: 5)
                            .accessibilityLabel("Goal progress")
                            .accessibilityValue("\(Int(min(store.stats.averageWPM / preferences.goal, 1) * 100)) percent")
                        Text("Based on your session average. Set a comfortable goal in Settings.")
                            .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Label("History is saved on this Mac.", systemImage: "lock.shield").foregroundStyle(.secondary)
                Spacer()
                Button("Copy stats", action: store.copyStats)
                Button("Reset…") { confirmReset = true }
            }.font(.system(size: 11)).buttonStyle(.borderless)
        }
    }

    private var settings: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("Make it yours.").font(.system(size: 25, weight: .semibold, design: .rounded))
                Text("Small adjustments. A rhythm that suits you.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("APPEARANCE", icon: "paintpalette")
                    ColorPicker("Accent color", selection: Binding(get: { preferences.accent }, set: { preferences.setAccent($0) }), supportsOpacity: false)
                    HStack(spacing: 10) {
                        ForEach(["1F9E7D", "3478F6", "8B5CF6", "D94D80", "C87520"], id: \.self) { hex in
                            Button { preferences.accentHex = hex } label: {
                                let value = UInt32(hex, radix: 16)!
                                Circle().fill(Color(red: Double(value >> 16 & 255) / 255, green: Double(value >> 8 & 255) / 255, blue: Double(value & 255) / 255))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(preferences.accentHex == hex ? 0.8 : 0), lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel("Accent \(hex)")
                        }
                        Spacer()
                        Button("Reset color") { preferences.accentHex = "1F9E7D" }.buttonStyle(.borderless)
                    }
                }.font(.system(size: 12))
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("STARTUP", icon: "power")
                    Toggle(isOn: Binding(get: { loginItem.enabled }, set: { loginItem.setEnabled($0) })) {
                        Text("Launch Speeder at login").frame(maxWidth: .infinity, alignment: .leading)
                    }.toggleStyle(.switch)
                    Text("Keep Speeder.app in Applications before enabling this option.").font(.system(size: 11)).foregroundStyle(.secondary)
                    if loginItem.needsApproval {
                        Button("Approve in Login Items…") { loginItem.openSettings() }
                    }
                    if let error = loginItem.error { Text(error).font(.caption).foregroundStyle(.orange) }
                }.font(.system(size: 12))
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    sectionLabel("MENU BAR", icon: "menubar.rectangle")
                    Toggle(isOn: $preferences.showSpeed) { Text("Show typing speed beside the spider").frame(maxWidth: .infinity, alignment: .leading) }
                    Divider()
                    Toggle(isOn: $preferences.animateSpider) { Text("Animate the spider while typing").frame(maxWidth: .infinity, alignment: .leading) }
                    Text("The number averages five keystrokes; the last partial batch appears when you pause. Animation respects Reduce Motion.").font(.system(size: 11)).foregroundStyle(.secondary)
                }.toggleStyle(.switch).font(.system(size: 12))
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("YOUR PACE", icon: "scope")
                    Stepper(value: $preferences.goal, in: 10...200, step: 5) {
                        HStack { Text("Typing goal"); Spacer(); Text("\(Int(preferences.goal)) wpm").monospacedDigit().foregroundStyle(.secondary) }
                    }
                    Text("A reference line in your graph, not a limit. There is no need to rush.").font(.system(size: 11)).foregroundStyle(.secondary)
                }.font(.system(size: 12))
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("PRIVACY & ACCESS", icon: "lock.shield")
                    HStack {
                        CaptureIndicator(store: store)
                        Spacer()
                        Button("Accessibility Settings…", action: store.requestAccess)
                    }
                    Text("Speeder classifies keystrokes and immediately discards their text. Numeric minute summaries are saved locally for long-term statistics and export. No uploads, no saved text, no account.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Button("Show introduction again") { route.showsOnboarding = true }.buttonStyle(.borderless)
                }
            }
            Text("Speeder 0.2.1 · Built for macOS").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        HStack { Text(LocalizedStringKey(label)).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }.font(.system(size: 12))
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(LocalizedStringKey(title), systemImage: icon).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
    }
}
