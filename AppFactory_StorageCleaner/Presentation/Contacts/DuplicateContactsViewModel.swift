//
//  DuplicateContactsViewModel.swift
//  AF Clean
//

import Observation

@MainActor
@Observable
final class DuplicateContactsViewModel {

    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let permissions: PermissionsViewModel

    init(
        scans: ScanCoordinator,
        selection: CleanupSelectionStore,
        permissions: PermissionsViewModel
    ) {
        self.scans = scans
        self.selection = selection
        self.permissions = permissions
    }

    // MARK: - View state

    var groups: [ContactDuplicateGroup] { scans.contactGroups }
    var state: ScanCoordinator.CategoryState { scans.state(for: .duplicateContacts) }

    var summary: String {
        guard !groups.isEmpty else { return "Nothing to clean" }
        let duplicates = groups.reduce(0) { $0 + $1.duplicates.count }
        return "\(groups.count) groups · \(Format.count(duplicates, singular: "duplicate"))"
    }

    func action(for group: ContactDuplicateGroup) -> CleanupPlan.ContactOperation.Action? {
        selection.decision(for: group.id)?.action
    }

    var decidedCount: Int { selection.itemCount(in: .duplicateContacts) }

    // MARK: - Intents

    func onAppear() {
        scans.scanIfNeeded(.duplicateContacts)
    }

    /// Nothing is chosen by default. Contacts, unlike photos, have no Recently
    /// Deleted to fall back on, so every group is an explicit decision.
    func choose(_ action: CleanupPlan.ContactOperation.Action, for group: ContactDuplicateGroup) {
        selection.toggleDecision(action, for: group)
    }

    func mergeAll() {
        for group in groups {
            selection.setDecision(.merge, for: group)
        }
    }

    func clearAll() {
        selection.clear(.duplicateContacts)
    }
}
