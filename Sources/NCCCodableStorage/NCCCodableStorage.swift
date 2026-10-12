//
//  NCCCodableStorage.swift
//
//
//  Created by Andrew Benson on 4/24/20.
//  Copyright (c) 2020-2026 Andrew Benson. Licensed under the MIT License. See LICENSE in the package root.
//

import Foundation
import SwiftUI
import NCCCoding

/// Creates a property that stores changes to JSON local file storage, encoded with Codable.
///
/// Declare it as a property of a SwiftUI `View`. The underlying storage is a `@StateObject`, so it is
/// created once per view identity and only behaves correctly when SwiftUI installs it in a view.
///
/// A failed automatic write (`.immediate` or `.afterIdle`) terminates the app with `fatalError`.
/// Use `.manual` and ``save()`` to handle write errors yourself.
@propertyWrapper public struct NCCCodableStorage<T: Codable>: DynamicProperty {

    /// Composes a file URL from the given filename and directoryType
    private static func getUrl(for filename: String, directoryType: FileManager.SearchPathDirectory) -> URL {
        let urlResult = NCCCoding.url(for: filename, in: directoryType)
        switch urlResult {
        case .success(let url):
            return url
        case .failure(let error):
            fatalError("Failed to create URL for filename \(filename) in directoryType \(directoryType): \(error)")
        }
    }

    /// The underlying data storage
    @StateObject private var storage: NCCCodableJSONStorage<T>

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
        Binding<T>(get: { self.storage.value },
                   set: { newValue in self.storage.value = newValue })
    }

    /// Writes the current value to storage synchronously, cancelling any pending `.afterIdle` write.
    /// Required in `.manual` mode; also useful to force a write in the other modes.
    /// - Throws: The encoding or file-writing error if the write failed.
    public func save() throws {
        try storage.save()
    }

    /// Replaces the current value with the one decoded from storage. Does not write the file back.
    /// - Throws: The file-reading or decoding error if the value could not be loaded.
    public func load() throws {
        try storage.load()
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// The existing file, if any, is not read; it is overwritten on the next automatic write.
    ///
    /// - Parameters:
    ///
    ///   - wrappedValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(wrappedValue initialValue: T,
                filename: String,
                directoryType: FileManager.SearchPathDirectory = .documentDirectory,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(initialValue: initialValue, filename: filename, directoryType: directoryType, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// The existing file, if any, is not read; it is overwritten on the next automatic write.
    ///
    /// - Parameters:
    ///
    ///   - initialValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(initialValue: T,
                filename: String,
                directoryType: FileManager.SearchPathDirectory = .documentDirectory,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(makeStorage: {
            NCCCodableJSONStorage(initialValue,
                                  url: Self.getUrl(for: filename, directoryType: directoryType),
                                  updateMode: updateMode)
        })
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - defaultValue: The initial value to assign if one could not be loaded from the underlying storage.
    ///   - filename: The name of the file that is used for underlying storage.
    ///   - directoryType: The directory type in which to locate or create the storage file.  Defaults to .documentDirectory.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(defaultValue: T,
                filename: String,
                directoryType: FileManager.SearchPathDirectory = .documentDirectory,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(makeStorage: {
            NCCCodableJSONStorage(loadingFrom: Self.getUrl(for: filename, directoryType: directoryType),
                                  defaultValue: defaultValue,
                                  updateMode: updateMode)
        })
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// The existing file, if any, is not read; it is overwritten on the next automatic write.
    ///
    /// - Parameters:
    ///
    ///   - wrappedValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(wrappedValue initialValue: T,
                url: URL,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(initialValue: initialValue, url: url, updateMode: updateMode)
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// The existing file, if any, is not read; it is overwritten on the next automatic write.
    ///
    /// - Parameters:
    ///
    ///   - initialValue: The initial value to assign to the property.  Subsequent updates are written to storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(initialValue: T,
                url: URL,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(makeStorage: {
            NCCCodableJSONStorage(initialValue, url: url, updateMode: updateMode)
        })
    }

    /// Initializes a property which has underlying storage backed by a "Codable" encoded local JSON file.
    ///
    /// - Parameters:
    ///
    ///   - defaultValue: The initial value to assign if one could not be loaded from the underlying storage.
    ///   - url: The file URL to be used for underlying storage.
    ///   - updateMode: The way data storage updates are to be applied.  Defaults to ``UpdateMode/default``.
    ///
    public init(defaultValue: T,
                url: URL,
                updateMode: UpdateMode = UpdateMode.default) {

        self.init(makeStorage: {
            NCCCodableJSONStorage(loadingFrom: url, defaultValue: defaultValue, updateMode: updateMode)
        })
    }

    /// SwiftUI re-runs a view's initializer on every parent re-render, but `StateObject` evaluates
    /// `makeStorage` only once per view identity, so URL lookup and file reads happen once.
    private init(makeStorage: @escaping () -> NCCCodableJSONStorage<T>) {
        self._storage = StateObject(wrappedValue: makeStorage())
    }
}

extension NCCCodableStorage {
    /// The manner in which updates to the underlying JSON storage are made when the wrapped value is changed.
    public enum UpdateMode {
        /// Every change is encoded and written on the shared write queue while the thread that made the change
        /// waits. That thread may also wait for writes already queued by other storages.
        case immediate
        /// A change is written once the value has not changed for `seconds`. The value is copied on the
        /// main thread and written on a background queue.
        case afterIdle(seconds: TimeInterval)
        /// Nothing is written automatically; call `save()` on the property wrapper (`_property.save()`).
        case manual

        /// `.afterIdle(seconds: 2.0)`.
        public static var `default`: UpdateMode { .afterIdle(seconds: 2.0) }
    }
}
