//
//  ContactMergeBuilder.swift
//  AF Clean
//

import Contacts

/// Builds the surviving card when duplicates are merged.
///
/// The rule throughout is additive: the keeper never loses anything it already
/// had, and anything the duplicates knew that it did not is added. A merge
/// should only ever be information-preserving — the user is told this is a
/// merge, not a deletion, so losing a phone number would be a broken promise.
enum ContactMergeBuilder {

    static func fold(_ duplicates: [CNContact], into keeper: CNMutableContact) {
        for duplicate in duplicates {
            fillMissingNameFields(from: duplicate, into: keeper)
            keeper.phoneNumbers = unionPhones(keeper.phoneNumbers, duplicate.phoneNumbers)
            keeper.emailAddresses = unionStrings(keeper.emailAddresses, duplicate.emailAddresses)
            unionSimple(duplicate, into: keeper)

            // Only adopt a photo if the keeper has none.
            if keeper.imageData == nil, duplicate.imageDataAvailable, let data = duplicate.imageData {
                keeper.imageData = data
            }
            if keeper.birthday == nil, let birthday = duplicate.birthday {
                keeper.birthday = birthday
            }
        }
    }

    // MARK: - Names

    private static func fillMissingNameFields(from source: CNContact, into keeper: CNMutableContact) {
        if keeper.givenName.isEmpty { keeper.givenName = source.givenName }
        if keeper.middleName.isEmpty { keeper.middleName = source.middleName }
        if keeper.familyName.isEmpty { keeper.familyName = source.familyName }
        if keeper.namePrefix.isEmpty { keeper.namePrefix = source.namePrefix }
        if keeper.nameSuffix.isEmpty { keeper.nameSuffix = source.nameSuffix }
        if keeper.nickname.isEmpty { keeper.nickname = source.nickname }
        if keeper.organizationName.isEmpty { keeper.organizationName = source.organizationName }
        if keeper.jobTitle.isEmpty { keeper.jobTitle = source.jobTitle }
        if keeper.departmentName.isEmpty { keeper.departmentName = source.departmentName }
    }

    // MARK: - Labelled values

    /// Phone numbers are de-duplicated on their digits, so the same number
    /// stored in two formats does not survive twice.
    private static func unionPhones(
        _ existing: [CNLabeledValue<CNPhoneNumber>],
        _ incoming: [CNLabeledValue<CNPhoneNumber>]
    ) -> [CNLabeledValue<CNPhoneNumber>] {
        var seen = Set(existing.map { digits(of: $0.value.stringValue) })
        var result = existing
        for value in incoming {
            let key = digits(of: value.value.stringValue)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(value)
        }
        return result
    }

    private static func unionStrings(
        _ existing: [CNLabeledValue<NSString>],
        _ incoming: [CNLabeledValue<NSString>]
    ) -> [CNLabeledValue<NSString>] {
        var seen = Set(existing.map { ($0.value as String).lowercased() })
        var result = existing
        for value in incoming {
            let key = (value.value as String).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(value)
        }
        return result
    }

    private static func unionSimple(_ source: CNContact, into keeper: CNMutableContact) {
        var urls = Set(keeper.urlAddresses.map { ($0.value as String).lowercased() })
        for value in source.urlAddresses
        where urls.insert((value.value as String).lowercased()).inserted {
            keeper.urlAddresses.append(value)
        }

        var addresses = Set(keeper.postalAddresses.map { postalKey($0.value) })
        for value in source.postalAddresses
        where addresses.insert(postalKey(value.value)).inserted {
            keeper.postalAddresses.append(value)
        }
    }

    // MARK: - Keys

    private static func digits(of value: String) -> String {
        let all = value.filter(\.isNumber)
        // Match the domain matcher: compare on the last 10 digits so country
        // and trunk prefixes do not create false differences.
        return String(all.suffix(10))
    }

    private static func postalKey(_ address: CNPostalAddress) -> String {
        [address.street, address.city, address.postalCode, address.country]
            .joined(separator: "|")
            .lowercased()
    }
}
