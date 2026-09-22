//
//  Item.swift
//  AppFactory_StorageCleaner
//
//  Created by Muhammad Haashim on 22/09/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
