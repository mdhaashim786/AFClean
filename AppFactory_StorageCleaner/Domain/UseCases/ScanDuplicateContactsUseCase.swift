//
//  ScanDuplicateContactsUseCase.swift
//  AF Clean
//

import Foundation

struct ScanDuplicateContactsUseCase: Sendable {

    private let contacts: ContactRepository
    private let matcher: ContactMatcher

    init(contacts: ContactRepository, matcher: ContactMatcher = ContactMatcher()) {
        self.contacts = contacts
        self.matcher = matcher
    }

    func callAsFunction() async throws -> [ContactDuplicateGroup] {
        let all = try await contacts.fetchContacts()
        guard !Task.isCancelled else { return [] }
        return matcher.group(contacts: all)
    }
}
