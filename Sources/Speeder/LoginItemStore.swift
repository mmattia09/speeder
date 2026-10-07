import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItemStore: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published var error: String?

    init() { refresh() }
    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = error.localizedDescription }
        refresh()
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
