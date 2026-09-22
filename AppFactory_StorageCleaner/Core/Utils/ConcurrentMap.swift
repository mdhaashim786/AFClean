//
//  ConcurrentMap.swift
//  AF Clean
//

import Foundation

/// Runs `transform` over `items` with at most `limit` operations in flight,
/// reporting each completion.
///
/// A plain `withTaskGroup` over a 20,000-photo library would ask PhotoKit for
/// 20,000 thumbnails at once and thrash. This keeps a fixed window of work in
/// flight instead, and stays cancellable throughout.
func concurrentForEach<Item: Sendable, Output: Sendable>(
    _ items: [Item],
    limit: Int,
    transform: @escaping @Sendable (Item) async -> Output?,
    onResult: (Output) -> Void
) async {
    guard !items.isEmpty else { return }
    let window = max(1, min(limit, items.count))

    await withTaskGroup(of: Output?.self) { group in
        var next = 0

        while next < window {
            let item = items[next]
            group.addTask { await transform(item) }
            next += 1
        }

        while let result = await group.next() {
            if let result { onResult(result) }

            guard !Task.isCancelled else {
                group.cancelAll()
                break
            }

            if next < items.count {
                let item = items[next]
                group.addTask { await transform(item) }
                next += 1
            }
        }
    }
}
