//
//  ExecuteCleanupUseCase.swift
//  AF Clean
//

import Foundation

/// The only code path in AF Clean that removes anything.
///
/// It takes an explicit `CleanupPlan` — the exact list the user approved on the
/// review screen — and nothing else. No view, view model or scanner can delete
/// an asset or a contact without building one of these first.
///
/// Media and contacts are handled separately and independently: photos go
/// through iOS's own confirmation sheet and land in Recently Deleted, while
/// contact writes are immediate and permanent. A failure or cancellation in one
/// never silently takes the other with it.
struct ExecuteCleanupUseCase: Sendable {

    private let photos: PhotoAssetRepository
    private let contacts: ContactRepository

    init(photos: PhotoAssetRepository, contacts: ContactRepository) {
        self.photos = photos
        self.contacts = contacts
    }

    func callAsFunction(plan: CleanupPlan) async -> CleanupOutcome {
        var outcome = CleanupOutcome()
        guard !plan.isEmpty else { return outcome }

        await deleteMedia(in: plan, into: &outcome)
        await applyContactOperations(in: plan, into: &outcome)

        return outcome
    }

    // MARK: - Photos and videos

    private func deleteMedia(in plan: CleanupPlan, into outcome: inout CleanupOutcome) async {
        guard !plan.assets.isEmpty else { return }

        let sizeByID = Dictionary(
            plan.assets.map { ($0.id, $0.byteSize) },
            uniquingKeysWith: { first, _ in first }
        )

        do {
            let deleted = try await photos.deleteAssets(ids: plan.assets.map(\.id))
            outcome.deletedAssetCount = deleted.count
            // Only count what actually went away.
            outcome.bytesFreed = deleted.reduce(0) { $0 + (sizeByID[$1] ?? 0) }
        } catch PhotoDeletionError.cancelledByUser {
            outcome.wasCancelled = true
        } catch PhotoDeletionError.notAuthorised {
            outcome.failures.append("AF Clean no longer has permission to change your photo library.")
        } catch {
            outcome.failures.append("Some photos could not be deleted. \(error.localizedDescription)")
        }
    }

    // MARK: - Contacts

    private func applyContactOperations(in plan: CleanupPlan, into outcome: inout CleanupOutcome) async {
        for operation in plan.contactOperations {
            let removedIDs = operation.removed.map(\.id)
            guard !removedIDs.isEmpty else { continue }

            do {
                switch operation.action {
                case .merge:
                    try await contacts.merge(keeperID: operation.keeper.id, removedIDs: removedIDs)
                    outcome.mergedContactCount += removedIDs.count
                case .delete:
                    try await contacts.delete(ids: removedIDs)
                    outcome.deletedContactCount += removedIDs.count
                }
            } catch {
                let verb = operation.action == .merge ? "merge" : "delete"
                outcome.failures.append(
                    "Could not \(verb) \(operation.keeper.displayName). \(error.localizedDescription)"
                )
            }
        }
    }
}
