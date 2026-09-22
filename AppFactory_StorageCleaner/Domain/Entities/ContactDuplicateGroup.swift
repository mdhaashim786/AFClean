//
//  ContactDuplicateGroup.swift
//  AF Clean
//

import Foundation

/// Contacts that look like the same person.
struct ContactDuplicateGroup: Identifiable, Hashable, Sendable {

    enum MatchReason: String, Sendable {
        case sameName
        case samePhone
        case sameEmail

        var label: String {
            switch self {
            case .sameName: "Same name"
            case .samePhone: "Same phone number"
            case .sameEmail: "Same email"
            }
        }
    }

    let id: String
    /// Richest card first, so the default keeper is the obvious one.
    let contacts: [ContactRecord]
    let keeperID: String
    let reasons: Set<MatchReason>

    var keeper: ContactRecord {
        contacts.first { $0.id == keeperID } ?? contacts[0]
    }

    var duplicates: [ContactRecord] {
        contacts.filter { $0.id != keeperID }
    }

    var count: Int { contacts.count }

    var reasonLabel: String {
        reasons
            .map(\.label)
            .sorted()
            .joined(separator: " · ")
    }

    /// The union of every phone number across the group — what a merge keeps.
    var mergedPhoneNumbers: [String] {
        orderedUnique(contacts.flatMap(\.phoneNumbers))
    }

    var mergedEmailAddresses: [String] {
        orderedUnique(contacts.flatMap(\.emailAddresses))
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
