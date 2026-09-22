//
//  main.swift
//  AF Clean — domain layer checks
//
//  The domain layer is deliberately free of PhotoKit, Contacts and SwiftUI, so
//  its algorithms can be compiled and exercised on their own. Run with:
//
//      ./DomainTests/run.sh
//
//  This lives outside the app's synchronized source folder so it never becomes
//  part of the shipped target.
//

import Foundation

func check(_ label: String, _ condition: Bool) {
    print("\(condition ? "PASS" : "FAIL")  \(label)")
    if !condition { exit(1) }
}

func photo(_ id: String, at seconds: TimeInterval, mp: Double = 12, bytes: Int64 = 3_000_000,
           favorite: Bool = false, edited: Bool = false, w: Int = 4000, h: Int = 3000) -> MediaAsset {
    MediaAsset(id: id, kind: .photo, byteSize: bytes, pixelWidth: w, pixelHeight: h,
               creationDate: Date(timeIntervalSince1970: seconds), modificationDate: nil,
               duration: 0, isFavorite: favorite, hasAdjustments: edited)
}

// ---------- UnionFind ----------
var uf = UnionFind(count: 6)
uf.union(0, 1); uf.union(1, 2); uf.union(4, 5)
let groups = uf.groups().sorted { $0[0] < $1[0] }
check("union-find collapses transitive pairs", groups == [[0,1,2],[4,5]])

// ---------- PerceptualHash ----------
check("hamming of identical is 0", PerceptualHash.hammingDistance(0xDEADBEEF, 0xDEADBEEF) == 0)
check("hamming counts differing bits", PerceptualHash.hammingDistance(0b1011, 0b1110) == 2)
let bands = PerceptualHash.bands(of: 0xAAAA_BBBB_CCCC_DDDD, bandCount: 4)
check("bands split 64 bits into 4", bands.count == 4 && bands[0] == 0xDDDD && bands[3] == 0xAAAA)

// ---------- BestShotSelector ----------
let selector = BestShotSelector()
check("favourite beats a bigger, sharper rival", selector.best(in: [
    photo("big", at: 0, bytes: 9_000_000, w: 6000, h: 4000),
    photo("fav", at: 0, bytes: 1_000_000, favorite: true, w: 1000, h: 800)
])?.id == "fav")
check("higher resolution wins when nothing else differs", selector.best(in: [
    photo("small", at: 0, w: 1000, h: 800),
    photo("large", at: 0, w: 4000, h: 3000)
])?.id == "large")
check("edited beats unedited at equal resolution", selector.best(in: [
    photo("plain", at: 0),
    photo("edited", at: 0, edited: true)
])?.id == "edited")

// ---------- SimilarityGrouper ----------
let grouper = SimilarityGrouper()

// Exact duplicates, far apart in time.
let exact = [photo("a", at: 0), photo("b", at: 900_000)]
let exactGroups = grouper.group(assets: exact, hashes: ["a": 0xFF00FF00FF00FF00, "b": 0xFF00FF00FF00FF00])
check("identical hashes group as exact duplicates",
      exactGroups.count == 1 && exactGroups[0].count == 2 && exactGroups[0].reason == .exactDuplicate)

// Burst: seconds apart, a few bits different.
let burst = [photo("b1", at: 100), photo("b2", at: 103), photo("b3", at: 106)]
let burstHashes: [String: UInt64] = ["b1": 0x0F0F_0F0F_0F0F_0F0F,
                                     "b2": 0x0F0F_0F0F_0F0F_0F1F,   // 2 bits off
                                     "b3": 0x0F0F_0F0F_0F0F_0F3F]   // 4 bits off
let burstGroups = grouper.group(assets: burst, hashes: burstHashes)
check("burst shots seconds apart group together",
      burstGroups.count == 1 && burstGroups[0].count == 3 && burstGroups[0].reason == .burst)

// Unrelated photos must NOT group.
let unrelated = [photo("u1", at: 0), photo("u2", at: 500_000)]
let unrelatedGroups = grouper.group(assets: unrelated,
                                    hashes: ["u1": 0x0000_0000_0000_0000, "u2": 0xFFFF_FFFF_FFFF_FFFF])
check("unrelated photos are left alone", unrelatedGroups.isEmpty)

// Loose match far apart in time must NOT group (stricter threshold applies).
let farApart = [photo("f1", at: 0), photo("f2", at: 500_000)]
let farGroups = grouper.group(assets: farApart,
                              // 6 bits apart, and sharing three of four LSH
                              // bands so the candidate search definitely sees
                              // the pair and the distance check is what rejects it.
                              hashes: ["f1": 0x0F0F_0F0F_0F0F_0F0F, "f2": 0x0F0F_0F0F_0F0F_7F7F])
check("a loose match far apart in time is not grouped", farGroups.isEmpty)

// Best is excluded from the removable set.
check("group reports only non-keepers as reclaimable",
      burstGroups[0].others.count == 2 &&
      burstGroups[0].reclaimableBytes == burstGroups[0].others.reduce(0) { $0 + $1.byteSize })

// ---------- Performance on a large synthetic library ----------
var many: [MediaAsset] = []
var manyHashes: [String: UInt64] = [:]
var rng = SystemRandomNumberGenerator()
for i in 0..<20_000 {
    let id = "p\(i)"
    many.append(photo(id, at: Double(i) * 7))
    // Every 50th photo is a duplicate of its predecessor.
    manyHashes[id] = (i % 50 == 0 && i > 0) ? manyHashes["p\(i-1)"]! : UInt64.random(in: .min ... .max, using: &rng)
}
let start = Date()
let bigGroups = grouper.group(assets: many, hashes: manyHashes)
let elapsed = Date().timeIntervalSince(start)
print(String(format: "       20,000 photos grouped in %.3fs -> %d groups", elapsed, bigGroups.count))
check("20k-photo grouping stays well under a second", elapsed < 1.0)
check("planted duplicates are all found", bigGroups.count == 399)

// ---------- ContactMatcher ----------
func contact(_ id: String, _ given: String, _ family: String,
             phones: [String] = [], emails: [String] = [], image: Bool = false) -> ContactRecord {
    ContactRecord(id: id, givenName: given, familyName: family, organizationName: "",
                  phoneNumbers: phones, emailAddresses: emails, hasImage: image, creationHint: nil)
}
let matcher = ContactMatcher()

check("phone formats normalise to the same key",
      matcher.normalisePhone("+91 98765 43210") == matcher.normalisePhone("098765 43210"))
check("accents and order are stripped from names",
      matcher.normaliseName(contact("x", "Seán", "O'Brien")) == matcher.normaliseName(contact("y", "obrien", "sean")))

let sharedPhone = matcher.group(contacts: [
    contact("1", "Ann", "Lee", phones: ["+1 (555) 010-2030"]),
    contact("2", "Annie", "Lee", phones: ["5550102030"], emails: ["a@b.com"])
])
check("same phone groups different spellings of a name",
      sharedPhone.count == 1 && sharedPhone[0].reasons.contains(.samePhone))
check("merge keeps the richer card", sharedPhone[0].keeper.id == "2")
check("merged group unions the contact points",
      sharedPhone[0].mergedEmailAddresses == ["a@b.com"] && sharedPhone[0].mergedPhoneNumbers.count == 2)

let sameNameDifferentPeople = matcher.group(contacts: [
    contact("1", "John", "Smith", phones: ["5551111111"]),
    contact("2", "John", "Smith", phones: ["5552222222"])
])
check("two different people with one name stay separate", sameNameDifferentPeople.isEmpty)

let bareDuplicate = matcher.group(contacts: [
    contact("1", "Jo", "Blake", phones: ["5551111111"], image: true),
    contact("2", "Jo", "Blake")
])
check("a bare duplicate folds into the full card",
      bareDuplicate.count == 1 && bareDuplicate[0].keeper.id == "1")

print("\nAll domain checks passed.")
