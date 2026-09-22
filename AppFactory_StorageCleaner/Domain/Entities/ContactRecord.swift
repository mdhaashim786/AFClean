//
//  ContactRecord.swift
//  AF Clean
//

import Foundation

/// Framework-free view of a contact card.
struct ContactRecord: Identifiable, Hashable, Sendable {

    /// `CNContact.identifier`.
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let hasImage: Bool
    let creationHint: Date?

    var displayName: String {
        let name = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        if !organizationName.isEmpty { return organizationName }
        if let phone = phoneNumbers.first { return phone }
        if let email = emailAddresses.first { return email }
        return "Unnamed contact"
    }

    var initials: String {
        let letters = [givenName, familyName]
            .filter { !$0.isEmpty }
            .compactMap(\.first)
        if letters.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return String(letters.prefix(2)).uppercased()
    }

    /// How much information this card carries. Used to pick which duplicate
    /// survives a merge — we keep the richest one.
    var completeness: Int {
        var score = phoneNumbers.count * 3 + emailAddresses.count * 2
        if hasImage { score += 4 }
        if !givenName.isEmpty { score += 2 }
        if !familyName.isEmpty { score += 2 }
        if !organizationName.isEmpty { score += 1 }
        return score
    }

    var subtitle: String {
        if let phone = phoneNumbers.first { return phone }
        if let email = emailAddresses.first { return email }
        if !organizationName.isEmpty { return organizationName }
        return "No phone or email"
    }
}
