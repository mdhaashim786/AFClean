//
//  ContactRepository.swift
//  AF Clean
//

import Foundation

enum ContactWriteError: Error, Equatable {
    case notAuthorised
    case failed(String)
}

protocol ContactRepository: Sendable {

    func fetchContacts() async throws -> [ContactRecord]

    /// Folds `removed` into `keeper` (union of phones, emails and any missing
    /// name fields), saves the keeper, then deletes the duplicates.
    func merge(keeperID: String, removedIDs: [String]) async throws

    func delete(ids: [String]) async throws

    func observeContactChanges(_ onChange: @escaping @Sendable () -> Void)
}
