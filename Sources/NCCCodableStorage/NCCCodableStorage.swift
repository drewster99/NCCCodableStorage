//
//  NCCCodableStorage.swift
//  
//
//  Created by Andrew Benson on 4/24/20.
//  Copyright © 2020 Nuclear Cyborg Corp. All rights reserved.
//

import Foundation
import SwiftUI
import NCCCoding

/// Creates a property that stores changes to JSON local file storage, encoded with Codable.
@propertyWrapper public struct NCCCodableStorage<T: Codable>: DynamicProperty {

    /// Composes a file URL from the given filename and directoryType
    private static func getUrl(for filename: String, directoryType: FileManager.SearchPathDirectory) -> URL {
        // Figure out that URL now, so we're not always re-fetching this info
        let urlResult = NCCCoding.url(for: filename, in: directoryType)
        switch urlResult {
        case .success(let url):
            return url
        case .failure(let error):
            fatalError("Failed to create URL for filename \(filename) in directoryType \(directoryType): \(error)")
        }
    }

    /// The underlying data storage
    @ObservedObject private var storage: NCCCodableJSONStorage<T>

    /// URL of underlying storage file
    public var url: URL {
        storage.url
    }

    /// Returns/updates the wrapped property's value.
    public var wrappedValue: T {
        get {
            storage.value
        }
        nonmutating set {
            storage.value = newValue
        }
    }

    /// Returns a Binding to the property's value, suitable for use with SwiftUI
    public var projectedValue: Binding<T> {
        // These SEEM to be equivalent.  But are they?

        // Better?
        $storage.value

        // Clearer?
        // Binding<T>(get: { self.storage.value },
        //            set: { (newValue) in self.storage.value = newValue }
        // )
    }

    /// Saves the stored underlying value.  Used in manual mode.
    /// - Throws: Error if failed.
    public func save() throws {
        try storage.save()
    }

    /// Saves the stored underlying value.  Used in manual mode.
    /// - Throws: Error if failed.
    public func load() throws {
        try storage.load()
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - wrappedValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(wrappedValue initialValue: T,
         filename: String,
         directoryType: FileManager.SearchPathDirectory = .documentDirectory,
         updateMode: UpdateMode = UpdateMode.default) {

        self.init(initialValue: initialValue, filename: filename, directoryType: directoryType, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - initialValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(initialValue: T,
         filename: String,
         directoryType: FileManager.SearchPathDirectory = .documentDirectory,
         updateMode: UpdateMode = UpdateMode.default) {

        let url = Self.getUrl(for: filename, directoryType: directoryType)
        self.init(initialValue: initialValue, url: url, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - defaultValue: The initial value to assign if one could not be loaded from the underlying storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(defaultValue: T,
         filename: String,
         directoryType: FileManager.SearchPathDirectory = .documentDirectory,
         updateMode: UpdateMode = UpdateMode.default) {

        let url = Self.getUrl(for: filename, directoryType: directoryType)
        self.init(defaultValue: defaultValue, url: url, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - wrappedValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(wrappedValue initialValue: T,
         url: URL,
         updateMode: UpdateMode = UpdateMode.default) {

        self.init(initialValue: initialValue, url: url, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - initialValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(initialValue: T,
         url: URL,
         updateMode: UpdateMode = UpdateMode.default) {

        self.storage = NCCCodableJSONStorage(initialValue, url: url, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - defaultValue: The initial value to assign if one could not be loaded from the underlying storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Default is .afterIdle(seconds: 1.0).
    ///
    init(defaultValue: T,
         url: URL,
         updateMode: UpdateMode = UpdateMode.default) {

        if let initialValue: T = NCCCoding.decode(url) {
            self.storage = NCCCodableJSONStorage(initialValue, url: url, updateMode: updateMode)
        } else {
            self.storage = NCCCodableJSONStorage(defaultValue, url: url, updateMode: updateMode)
        }
    }
}

extension NCCCodableStorage {
    /// The manner in which updates to the underlying JSON storage are made when the wrapped value is changed.
    public enum UpdateMode {
        case immediate
        case afterIdle(seconds: TimeInterval)
        case manual

        static var `default`: UpdateMode { .afterIdle(seconds: 2.0) }
    }
}

protocol NCCUnderlyingStorage: ObservableObject {
    associatedtype T
    var value: T { get set }
    func save() throws
}

extension NCCCodableStorage {
    /// Handles writing of the underlying JSON data store.
    private class NCCCodableJSONStorage<T: Codable>: ObservableObject, NCCUnderlyingStorage {

        private(set) var url: URL
        private var updateTimerWorkItem: DispatchWorkItem?
        private var isStorageUpdateNeeded = false

        /// MARK: - NCCUnderlyingStorage conformance
        public var value: T {
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
            let result: Result<T, Error> = NCCCoding.decode(url)
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

        init(_ value: T, url: URL, updateMode: UpdateMode) {
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
