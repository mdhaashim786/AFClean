//
//  ContactRepositoryImpl.swift
//  AF Clean
//

import Contacts
import Foundation

struct ContactRepositoryImpl: ContactRepository {

    private let source: ContactStoreDataSource

    init(source: ContactStoreDataSource) {
        self.source = source
    }

    func fetchContacts() async throws -> [ContactRecord] {
        let source = self.source
        return try await Task.detached(priority: .userInitiated) {
            // Contacts enumeration is synchronous and can take a moment on a
            // large address book, so it is kept off the caller's executor.
            try source.fetchAll().map(CNContactMapper.map)
        }.value
    }

    func merge(keeperID: String, removedIDs: [String]) async throws {
        let source = self.source
        try await Task.detached(priority: .userInitiated) {
            try source.merge(keeperID: keeperID, removedIDs: removedIDs)
        }.value
    }

    func delete(ids: [String]) async throws {
        let source = self.source
        try await Task.detached(priority: .userInitiated) {
            try source.delete(ids: ids)
        }.value
    }

    func observeContactChanges(_ onChange: @escaping @Sendable () -> Void) {
        source.addChangeHandler(onChange)
    }
}
