//
//  ContactStoreDataSource.swift
//  AF Clean
//

import Contacts
import Foundation

/// The only type in the app that touches `CNContact`.
final class ContactStoreDataSource: @unchecked Sendable {

    private let store = CNContactStore()
    private var observer: NSObjectProtocol?

    /// Only the keys we actually use.
    ///
    /// Contacts charges per key fetched, and a library of several thousand
    /// cards is noticeably slower if you ask for everything. Notes are
    /// deliberately absent: reading them needs a special entitlement, and AF
    /// Clean has no reason to see them.
    private static let readKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey,
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactImageDataAvailableKey
    ].map { $0 as CNKeyDescriptor }

    /// Everything a merge needs to read *and* write back.
    private static let mergeKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey,
        CNContactGivenNameKey,
        CNContactMiddleNameKey,
        CNContactFamilyNameKey,
        CNContactNamePrefixKey,
        CNContactNameSuffixKey,
        CNContactNicknameKey,
        CNContactOrganizationNameKey,
        CNContactJobTitleKey,
        CNContactDepartmentNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactPostalAddressesKey,
        CNContactUrlAddressesKey,
        CNContactSocialProfilesKey,
        CNContactInstantMessageAddressesKey,
        CNContactBirthdayKey,
        CNContactImageDataKey,
        CNContactImageDataAvailableKey
    ].map { $0 as CNKeyDescriptor }

    // MARK: - Reading

    /// Fetches unified contacts — the same cards the user sees in the Contacts
    /// app, with iOS's own account linking already applied. Anything still
    /// duplicated here is a duplicate the user can actually see.
    func fetchAll() throws -> [CNContact] {
        let request = CNContactFetchRequest(keysToFetch: Self.readKeys)
        request.unifyResults = true
        request.sortOrder = .givenName

        var contacts: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        return contacts
    }

    private func contact(withIdentifier id: String, keys: [CNKeyDescriptor]) throws -> CNContact {
        try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
    }

    // MARK: - Writing

    /// Folds the duplicates into the keeper and removes them, in a single save
    /// request so the union and the deletions cannot be applied by halves.
    func merge(keeperID: String, removedIDs: [String]) throws {
        let keeper = try contact(withIdentifier: keeperID, keys: Self.mergeKeys)
        let duplicates = try removedIDs.compactMap { id -> CNContact? in
            // A duplicate already gone is not an error worth failing the merge.
            try? contact(withIdentifier: id, keys: Self.mergeKeys)
        }
        guard !duplicates.isEmpty else { return }

        guard let merged = keeper.mutableCopy() as? CNMutableContact else {
            throw ContactWriteError.failed("Could not prepare the contact for merging.")
        }
        ContactMergeBuilder.fold(duplicates, into: merged)

        let request = CNSaveRequest()
        request.update(merged)
        for duplicate in duplicates {
            guard let mutable = duplicate.mutableCopy() as? CNMutableContact else { continue }
            request.delete(mutable)
        }

        try store.execute(request)
    }

    func delete(ids: [String]) throws {
        let request = CNSaveRequest()
        var hasWork = false

        for id in ids {
            guard let contact = try? contact(withIdentifier: id, keys: Self.mergeKeys),
                  let mutable = contact.mutableCopy() as? CNMutableContact
            else { continue }
            request.delete(mutable)
            hasWork = true
        }

        guard hasWork else { return }
        try store.execute(request)
    }

    // MARK: - Change observation

    func addChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: nil
        ) { _ in handler() }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
