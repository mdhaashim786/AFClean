//
//  UnionFind.swift
//  AF Clean
//

import Foundation

/// Disjoint-set forest with path compression and union by size.
///
/// Both scanners work the same way: cheaply propose "these two are the same",
/// then let this collapse those pairwise claims into final groups. That keeps
/// grouping linear-ish instead of needing an all-pairs comparison.
struct UnionFind {

    private var parent: [Int]
    private var size: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
    }

    mutating func find(_ element: Int) -> Int {
        var root = element
        while parent[root] != root { root = parent[root] }
        // Path compression: point everything on the way up at the root.
        var current = element
        while parent[current] != root {
            let next = parent[current]
            parent[current] = root
            current = next
        }
        return root
    }

    @discardableResult
    mutating func union(_ lhs: Int, _ rhs: Int) -> Bool {
        var a = find(lhs)
        var b = find(rhs)
        guard a != b else { return false }
        if size[a] < size[b] { swap(&a, &b) }
        parent[b] = a
        size[a] += size[b]
        return true
    }

    func connected(_ lhs: Int, _ rhs: Int) -> Bool {
        var copy = self
        return copy.find(lhs) == copy.find(rhs)
    }

    /// Every set with more than one member, as index lists in input order.
    mutating func groups(minimumSize: Int = 2) -> [[Int]] {
        var buckets: [Int: [Int]] = [:]
        for index in parent.indices {
            buckets[find(index), default: []].append(index)
        }
        return buckets.values
            .filter { $0.count >= minimumSize }
            .map { $0.sorted() }
    }
}
