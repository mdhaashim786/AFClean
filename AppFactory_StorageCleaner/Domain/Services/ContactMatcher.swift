//
//  ContactMatcher.swift
//  AF Clean
//

import Foundation

/// Finds contacts that look like the same person.
///
/// Same shape as the photo scan: index the contacts on a few normalised keys,
/// propose matches from shared keys, and let union-find collapse them. Nothing
/// here compares all pairs.
struct ContactMatcher {

    struct Configuration {
        /// Phone numbers are compared on their last N digits, so
        /// "+91 98765 43210", "098765 43210" and "9876543210" all match.
        var phoneSignificantDigits: Int = 10
        /// A shared name alone is weaker evidence than a shared phone or email
        /// — there are real different people called "Mum". Require the cards to
        /// not actively contradict each other before grouping on name alone.
        var requireCompatibleContactPoints: Bool = true

        static let `default` = Configuration()
    }

    let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func group(contacts: [ContactRecord]) -> [ContactDuplicateGroup] {
        guard contacts.count > 1 else { return [] }

        var sets = UnionFind(count: contacts.count)
        var reasons: [Int: Set<ContactDuplicateGroup.MatchReason>] = [:]

        let normalisedPhones = contacts.map { Set($0.phoneNumbers.compactMap(normalisePhone)) }
        let normalisedEmails = contacts.map { Set($0.emailAddresses.compactMap(normaliseEmail)) }
        let normalisedNames = contacts.map { normaliseName($0) }

        // Strong signals first: a shared phone or email is near-conclusive.
        joinOnKeys(normalisedPhones, reason: .samePhone, sets: &sets, reasons: &reasons)
        joinOnKeys(normalisedEmails, reason: .sameEmail, sets: &sets, reasons: &reasons)

        joinOnNames(
            normalisedNames,
            phones: normalisedPhones,
            emails: normalisedEmails,
            sets: &sets,
            reasons: &reasons
        )

        return buildGroups(contacts, sets: &sets, reasons: reasons)
    }

    // MARK: - Joining

    private func joinOnKeys(
        _ keysPerContact: [Set<String>],
        reason: ContactDuplicateGroup.MatchReason,
        sets: inout UnionFind,
        reasons: inout [Int: Set<ContactDuplicateGroup.MatchReason>]
    ) {
        var owners: [String: Int] = [:]
        for index in keysPerContact.indices {
            for key in keysPerContact[index] {
                if let first = owners[key] {
                    sets.union(first, index)
                    reasons[first, default: []].insert(reason)
                    reasons[index, default: []].insert(reason)
                } else {
                    owners[key] = index
                }
            }
        }
    }

    private func joinOnNames(
        _ names: [String],
        phones: [Set<String>],
        emails: [Set<String>],
        sets: inout UnionFind,
        reasons: inout [Int: Set<ContactDuplicateGroup.MatchReason>]
    ) {
        var byName: [String: [Int]] = [:]
        for index in names.indices where !names[index].isEmpty {
            byName[names[index], default: []].append(index)
        }

        for indices in byName.values where indices.count > 1 {
            for i in 0..<(indices.count - 1) {
                for j in (i + 1)..<indices.count {
                    let lhs = indices[i]
                    let rhs = indices[j]
                    guard namesMayBeSamePerson(
                        lhsPhones: phones[lhs], rhsPhones: phones[rhs],
                        lhsEmails: emails[lhs], rhsEmails: emails[rhs]
                    ) else { continue }

                    sets.union(lhs, rhs)
                    reasons[lhs, default: []].insert(.sameName)
                    reasons[rhs, default: []].insert(.sameName)
                }
            }
        }
    }

    /// Two same-named cards are treated as one person unless their contact
    /// points actively disagree — that is, both have phone numbers and share
    /// none. Two different "John Smith"s with different numbers stay separate;
    /// a bare duplicate with no details still merges into the full card.
    private func namesMayBeSamePerson(
        lhsPhones: Set<String>, rhsPhones: Set<String>,
        lhsEmails: Set<String>, rhsEmails: Set<String>
    ) -> Bool {
        guard configuration.requireCompatibleContactPoints else { return true }

        if !lhsPhones.isEmpty, !rhsPhones.isEmpty, lhsPhones.isDisjoint(with: rhsPhones) {
            return false
        }
        if !lhsEmails.isEmpty, !rhsEmails.isEmpty, lhsEmails.isDisjoint(with: rhsEmails) {
            return false
        }
        return true
    }

    // MARK: - Normalisation

    func normalisePhone(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return String(digits.suffix(configuration.phoneSignificantDigits))
    }

    func normaliseEmail(_ raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Case, accents, punctuation and word order are all stripped, so
    /// "O'Brien, Seán" and "sean obrien" land on the same key.
    func normaliseName(_ contact: ContactRecord) -> String {
        let raw = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let source = raw.isEmpty ? contact.organizationName : raw

        // Split on whitespace only, then strip punctuation *inside* each word.
        // Splitting on punctuation instead would turn "O'Brien" into "o" plus
        // "brien" and stop it matching "OBrien". Sorting the words makes the
        // key order-independent, so "Smith, John" matches "John Smith".
        let folded = source
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.filter(\.isLetter) + $0.filter(\.isNumber) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined()

        // One-letter "names" are noise, not a match signal.
        return folded.count > 1 ? folded : ""
    }

    // MARK: - Assembling results

    private func buildGroups(
        _ contacts: [ContactRecord],
        sets: inout UnionFind,
        reasons: [Int: Set<ContactDuplicateGroup.MatchReason>]
    ) -> [ContactDuplicateGroup] {
        var groups: [ContactDuplicateGroup] = []

        for indices in sets.groups() {
            // Richest card first — that is the one a merge should keep.
            let members = indices
                .map { contacts[$0] }
                .sorted(by: Self.richestFirst)
            guard members.count > 1, let keeper = members.first else { continue }

            var groupReasons: Set<ContactDuplicateGroup.MatchReason> = []
            for index in indices {
                groupReasons.formUnion(reasons[index] ?? [])
            }
            if groupReasons.isEmpty { groupReasons = [.sameName] }

            groups.append(
                ContactDuplicateGroup(
                    id: keeper.id,
                    contacts: members,
                    keeperID: keeper.id,
                    reasons: groupReasons
                )
            )
        }

        return groups.sorted(by: Self.largestGroupFirst)
    }

    /// Most complete card first, id as a stable tiebreak.
    private static func richestFirst(_ lhs: ContactRecord, _ rhs: ContactRecord) -> Bool {
        if lhs.completeness != rhs.completeness {
            return lhs.completeness > rhs.completeness
        }
        return lhs.id < rhs.id
    }

    /// Biggest pile of duplicates first, then alphabetical.
    private static func largestGroupFirst(
        _ lhs: ContactDuplicateGroup,
        _ rhs: ContactDuplicateGroup
    ) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count > rhs.count
        }
        let comparison = lhs.keeper.displayName
            .localizedCaseInsensitiveCompare(rhs.keeper.displayName)
        return comparison == .orderedAscending
    }
}
