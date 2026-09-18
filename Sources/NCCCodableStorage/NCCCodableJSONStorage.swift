//
//  NCCCodableJSONStorage.swift
//  
//
//  Created by Andrew Benson on 5/4/24.
//

import Foundation
import NCCCoding

extension NCCCodableStorage {
    /// Handles writing of the underlying JSON data store.
    internal class NCCCodableJSONStorage<JSONCodableValue: Codable>: ObservableObject, NCCUnderlyingStorage {

        private(set) var url: URL
        private var updateTimerWorkItem: DispatchWorkItem?
        private var isStorageUpdateNeeded = false

        /// MARK: - NCCUnderlyingStorage conformance
        public var value: JSONCodableValue {
            willSet {
                objectWillChange.send()
            }
            didSet {
                updater?()
            }
        }

        /// Save to underlying storage
        public func save() throws {
            if let error = NCCCoding.encode(value, to: url) {
                throw error
            }
            isStorageUpdateNeeded = false
        }

        /// Load from underlying storage
        public func load() throws {
            let result: Result<JSONCodableValue, Error> = NCCCoding.decode(url)
            switch result {
            case .success(let loadedValue):
                self.value = loadedValue
            case .failure(let error):
                throw error
            }
        }

        private var updater: (() -> Void)?

        private func updateCodedStorage() {
            do {
                try save()
            } catch {
                fatalError("\(#function) failed: \(error)")
            }
        }

        init(_ value: JSONCodableValue, url: URL, updateMode: UpdateMode) {
            self.value = value
            self.url = url
            switch updateMode {
            case .immediate:
                updater = updateCodedStorage

            case .afterIdle(let seconds):
                updater = {
                    self.isStorageUpdateNeeded = true
                    self.updateTimerWorkItem?.cancel()
                    self.updateTimerWorkItem = DispatchWorkItem {
                        self.updateCodedStorage()
                    }
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + seconds,
                                                                      execute: self.updateTimerWorkItem!)
                }

            case .manual:
                updater = nil
            }
        }

        deinit {
            updateTimerWorkItem?.cancel()
            updateTimerWorkItem = nil
            if isStorageUpdateNeeded {
                updateCodedStorage()
            }
        }
    }
}
