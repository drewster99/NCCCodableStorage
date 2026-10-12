import XCTest
import Foundation
#if os(macOS)
import AppKit
#endif

@testable import NCCCodableStorage

/// Regression tests for reads and flushes that didn't wait for an idle write already queued on
/// `storageWriteQueue`. Each test holds the queue with a blocker so the idle write is still in flight.
final class StorageWriteOrderingTests: TemporaryDirectoryTestCase {

    private let blockerDuration: TimeInterval = 0.3

    /// Blocks `storageWriteQueue` and schedules its release from another thread.
    private func holdWriteQueue() {
        let blocker = DispatchSemaphore(value: 0)
        storageWriteQueue.async { blocker.wait() }
        DispatchQueue.global().asyncAfter(deadline: .now() + blockerDuration) { blocker.signal() }
    }

    /// Lets the queued idle write finish, so it can't run after tearDown removes the directory.
    private func drainWriteQueue() {
        storageWriteQueue.sync {}
    }

    /// Changes the value and lets the idle timer fire, leaving the write queued behind the blocker.
    private func queueIdleWrite(of record: SampleRecord, in storage: SampleStorage) {
        holdWriteQueue()
        storage.value = record
        runMainRunLoop(for: 0.05)
    }

    #if os(macOS)
    // The lifecycle flush returned without waiting when the idle write had already been queued,
    // so the app could exit before the last edit reached the file.
    func testTerminationFlushWaitsForQueuedIdleWrite() throws {
        let url = fileURL(named: "terminate-in-flight.json")
        let storage = SampleStorage(SampleRecord(name: "start", count: 0), url: url, updateMode: .afterIdle(seconds: 0))
        let lastEdit = SampleRecord(name: "last edit", count: 1)
        queueIdleWrite(of: lastEdit, in: storage)

        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
        let fileExistedAfterFlush = FileManager.default.fileExists(atPath: url.path)

        drainWriteQueue()
        XCTAssertTrue(fileExistedAfterFlush, "flush returned before the queued write finished")
        XCTAssertEqual(try readRecord(from: url), lastEdit)
        withExtendedLifetime(storage) {}
    }
    #endif

    // A new storage read the file while another storage's write to it was still queued, so it started stale.
    func testLoadingInitializerWaitsForQueuedWrite() {
        let url = fileURL(named: "init-in-flight.json")
        let writer = SampleStorage(SampleRecord(name: "start", count: 0), url: url, updateMode: .afterIdle(seconds: 0))
        let written = SampleRecord(name: "written", count: 2)
        queueIdleWrite(of: written, in: writer)

        let reader = SampleStorage(loadingFrom: url,
                                   defaultValue: SampleRecord(name: "default", count: -1),
                                   updateMode: .manual)

        drainWriteQueue()
        XCTAssertEqual(reader.value, written)
        withExtendedLifetime(writer) {}
    }

    // load() read the file before a queued older write landed, leaving memory and file different.
    func testLoadWaitsForQueuedWrite() throws {
        let url = fileURL(named: "load-in-flight.json")
        writeRecord(SampleRecord(name: "on disk", count: 3), to: url)
        let storage = SampleStorage(SampleRecord(name: "start", count: 0), url: url, updateMode: .afterIdle(seconds: 0))
        queueIdleWrite(of: SampleRecord(name: "queued", count: 4), in: storage)

        try storage.load()

        drainWriteQueue()
        XCTAssertEqual(storage.value, try readRecord(from: url), "memory and file disagree after load()")
    }
}
