//
//  NCCCodableJSONStorage.swift
//
//
//  Created by Andrew Benson on 5/4/24.
//  Licensed under the MIT License. See LICENSE in the package root.
//

import Foundation
import NCCCoding
import os
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// All file reads and writes from every storage go through this one serial queue, so writes to the same
/// file can never interleave or land out of order, and a read always sees every write queued before it.
let storageWriteQueue = DispatchQueue(label: "com.nuclearcyborg.NCCCodableStorage.write",
                                              qos: .utility)

let storageLogger = Logger(subsystem: "com.nuclearcyborg.NCCCodableStorage", category: "storage")

extension NCCCodableStorage {
    /// Handles writing of the underlying JSON data store.
    ///
    /// `value` and the bookkeeping state are owned by the main thread, where SwiftUI reads and writes them.
    /// Debounced writes copy `value` on the main thread and only encode and write that copy on
    /// `storageWriteQueue`.
    internal final class NCCCodableJSONStorage<JSONCodableValue: Codable>: ObservableObject, NCCUnderlyingStorage {

        private(set) var url: URL
        private let updateMode: UpdateMode
        private var pendingWriteWorkItem: DispatchWorkItem?
        private var isStorageUpdateNeeded = false
        private var isApplyingLoadedValue = false
        private var lifecycleObservers: [NSObjectProtocol] = []

        // MARK: - NCCUnderlyingStorage conformance

        var value: JSONCodableValue {
            willSet {
                objectWillChange.send()
            }
            didSet {
                // A value that was just read from the file doesn't need to be written back to it.
                guard !isApplyingLoadedValue else { return }
                valueDidChange()
            }
        }

        /// Writes the current value to the file synchronously.
        func save() throws {
            try Self.write(value, to: url)
            cancelPendingWrite()
            isStorageUpdateNeeded = false
        }

        /// Replaces the current value with the one decoded from the file.
        func load() throws {
            let loadedValue = try Self.read(from: url).get()
            isApplyingLoadedValue = true
            defer { isApplyingLoadedValue = false }
            value = loadedValue
            cancelPendingWrite()
            isStorageUpdateNeeded = false
        }

        init(_ value: JSONCodableValue, url: URL, updateMode: UpdateMode) {
            self.value = value
            self.url = url
            self.updateMode = updateMode
            switch updateMode {
            case .immediate, .afterIdle:
                observeAppLifecycle()
            case .manual:
                break
            }
        }

        /// Starts with the value decoded from the file at `url`, or `defaultValue` if it can't be loaded.
        convenience init(loadingFrom url: URL, defaultValue: JSONCodableValue, updateMode: UpdateMode) {
            let initialValue: JSONCodableValue
            switch Self.read(from: url) {
            case .success(let loadedValue):
                initialValue = loadedValue
            case .failure:
                // Any read failure falls back to defaultValue, as it always has; see issue #3.
                initialValue = defaultValue
            }
            self.init(initialValue, url: url, updateMode: updateMode)
        }

        deinit {
            pendingWriteWorkItem?.cancel()
            for observer in lifecycleObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            if isStorageUpdateNeeded {
                do {
                    try Self.write(value, to: url)
                } catch {
                    Self.automaticWriteFailed(error, url: url)
                }
            }
        }

        // MARK: - Automatic writes

        private func valueDidChange() {
            switch updateMode {
            case .immediate:
                isStorageUpdateNeeded = true
                writePendingChangesNow()
            case .afterIdle(let seconds):
                isStorageUpdateNeeded = true
                schedulePendingWrite(after: seconds)
            case .manual:
                break
            }
        }

        private func schedulePendingWrite(after seconds: TimeInterval) {
            pendingWriteWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.writePendingChangesInBackground()
            }
            pendingWriteWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
        }

        private func cancelPendingWrite() {
            pendingWriteWorkItem?.cancel()
            pendingWriteWorkItem = nil
        }

        /// Writes any unsaved change synchronously, so it is on disk before the app suspends or exits.
        private func writePendingChangesNow() {
            cancelPendingWrite()
            // An idle write may already be queued; wait for it so it is on disk before returning.
            // This runs on the main thread, never on storageWriteQueue, so it can't deadlock.
            storageWriteQueue.sync {}
            guard isStorageUpdateNeeded else { return }
            do {
                try Self.write(value, to: url)
                isStorageUpdateNeeded = false
            } catch {
                Self.automaticWriteFailed(error, url: url)
            }
        }

        /// Copies the value on the main thread, then encodes and writes the copy on the write queue.
        private func writePendingChangesInBackground() {
            pendingWriteWorkItem = nil
            guard isStorageUpdateNeeded else { return }
            let snapshot = value
            let url = self.url
            isStorageUpdateNeeded = false
            // The write queue never holds a reference to self; otherwise the last release, and so deinit's
            // synchronous write, could happen on that queue.
            storageWriteQueue.async {
                if let error = NCCCoding.encode(snapshot, to: url) {
                    Self.automaticWriteFailed(error, url: url)
                }
            }
        }

        /// A failed automatic write (`.immediate`, `.afterIdle`, lifecycle flush or release) terminates the app,
        /// as it always has; see issue #9 for replacing this with a reported error.
        private static func automaticWriteFailed(_ error: Error, url: URL) -> Never {
            storageLogger.fault("Write to \(url.path, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            fatalError("Automatic write to \(url.path) failed: \(error)")
        }

        /// Decodes the file on the write queue, after every write already queued for it.
        private static func read(from url: URL) -> Result<JSONCodableValue, Error> {
            storageWriteQueue.sync {
                NCCCoding.decode(url)
            }
        }

        private static func write(_ snapshot: JSONCodableValue, to url: URL) throws {
            var writeError: Error?
            storageWriteQueue.sync {
                writeError = NCCCoding.encode(snapshot, to: url)
            }
            if let writeError = writeError {
                throw writeError
            }
        }

        // MARK: - App lifecycle

        private func observeAppLifecycle() {
            #if canImport(UIKit) && !os(watchOS)
            let notificationNames = [UIApplication.didEnterBackgroundNotification,
                                     UIApplication.willTerminateNotification]
            #elseif os(macOS)
            let notificationNames = [NSApplication.willTerminateNotification]
            #else
            let notificationNames: [Notification.Name] = []
            #endif
            lifecycleObservers = notificationNames.map { name in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.writePendingChangesNow()
                }
            }
        }
    }
}
