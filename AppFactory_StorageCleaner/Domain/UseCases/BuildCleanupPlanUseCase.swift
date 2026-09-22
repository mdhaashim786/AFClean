//
//  BuildCleanupPlanUseCase.swift
//  AF Clean
//

import Foundation

/// Turns the user's selections into the explicit `CleanupPlan` that
/// `ExecuteCleanupUseCase` will act on.
///
/// Keeping plan construction here means there is exactly one description of
/// what "approved for removal" means, and it is expressed in domain terms
/// rather than assembled ad hoc by a view.
struct BuildCleanupPlanUseCase: Sendable {

    struct ContactDecision: Sendable, Equatable {
        let group: ContactDuplicateGroup
        let action: CleanupPlan.ContactOperation.Action
    }

    func callAsFunction(
        assets: [MediaAsset],
        contactDecisions: [ContactDecision]
    ) -> CleanupPlan {
        let operations = contactDecisions.compactMap { decision -> CleanupPlan.ContactOperation? in
            let removed = decision.group.duplicates
            guard !removed.isEmpty else { return nil }
            return CleanupPlan.ContactOperation(
                id: decision.group.id,
                action: decision.action,
                keeper: decision.group.keeper,
                removed: removed
            )
        }

        return CleanupPlan(assets: assets, contactOperations: operations)
    }
}
