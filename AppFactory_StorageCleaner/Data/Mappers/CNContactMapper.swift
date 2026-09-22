//
//  CNContactMapper.swift
//  AF Clean
//

import Contacts

/// Converts `CNContact` into the domain's `ContactRecord`.
enum CNContactMapper {

    static func map(_ contact: CNContact) -> ContactRecord {
        ContactRecord(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            organizationName: contact.organizationName,
            phoneNumbers: contact.phoneNumbers.map(\.value.stringValue),
            emailAddresses: contact.emailAddresses.map { $0.value as String },
            hasImage: contact.imageDataAvailable,
            creationHint: nil
        )
    }
}
