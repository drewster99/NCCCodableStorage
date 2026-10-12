import XCTest
import Foundation
#if os(macOS)
import AppKit
#endif

@testable import NCCCodableStorage

/// Regression tests for defects found in the 1.1.1 code review.
final class StorageRegressionTests: TemporaryDirectoryTestCase {

    // The updater closure captured self strongly, so storage objects in .immediate mode never deallocated.
    func testImmediateModeStorageIsReleased() {
        weak var weakStorage: SampleStorage?
        do {
            let storage = SampleStorage(SampleRecord(name: "start", count: 0),
                                        url: fileURL(named: "immediate.json"),
                                        updateMode: .immediate)
            storage.value = SampleRecord(name: "changed", count: 1)
            weakStorage = storage
        }
        XCTAssertNil(weakStorage, "storage leaked")
    }

    // The updater closure and the pending work item captured self strongly, so storage objects in
    // .afterIdle mode never deallocated.
    func testAfterIdleModeStorageIsReleased() {
        weak var weakStorage: SampleStorage?
        do {
            let storage = SampleStorage(SampleRecord(name: "start", count: 0),
                                        url: fileURL(named: "idle.json"),
                                        updateMode: .afterIdle(seconds: 60))
            storage.value = SampleRecord(name: "changed", count: 1)
            weakStorage = storage
        }
        XCTAssertNil(weakStorage, "storage leaked")
    }

    // Because of the leak, the flush in deinit never ran and a pending idle write was never written.
    func testPendingIdleWriteIsWrittenWhenStorageIsReleased() throws {
        let url = fileURL(named: "flush-on-release.json")
        do {
            let storage = SampleStorage(SampleRecord(name: "start", count: 0),
                                        url: url,
                                        updateMode: .afterIdle(seconds: 60))
            storage.value = SampleRecord(name: "pending", count: 7)
        }
        XCTAssertEqual(try readRecord(from: url), SampleRecord(name: "pending", count: 7))
    }

    // load() assigned value through the change path, so .immediate mode re-wrote the file it had just read.
    func testLoadDoesNotRewriteTheFile() throws {
        let url = fileURL(named: "load.json")
        let externallyWrittenBytes = Data("{\n  \"name\" : \"external\",\n  \"count\" : 3\n}\n".utf8)
        try externallyWrittenBytes.write(to: url)

        let storage = SampleStorage(SampleRecord(name: "start", count: 0), url: url, updateMode: .immediate)
        try storage.load()

        XCTAssertEqual(storage.value, SampleRecord(name: "external", count: 3))
        XCTAssertEqual(try Data(contentsOf: url), externallyWrittenBytes, "load() rewrote the file")
    }

    // The defaultValue initializer read and decoded the file in the wrapper's init. Inside a View that
    // init runs on every parent re-render, so the read must be deferred until the storage is created.
    func testDefaultValueInitializerDoesNotReadTheFileDuringInit() {
        let url = fileURL(named: "deferred.json")
        writeRecord(SampleRecord(name: "before init", count: 1), to: url)

        let wrapper = NCCCodableStorage(defaultValue: SampleRecord(name: "default", count: 0),
                                        url: url,
                                        updateMode: .manual)
        writeRecord(SampleRecord(name: "after init", count: 2), to: url)

        XCTAssertEqual(wrapper.wrappedValue, SampleRecord(name: "after init", count: 2))
    }

    #if os(macOS)
    // Pending idle writes were lost when the app terminated before the idle delay elapsed.
    func testPendingIdleWriteIsWrittenWhenAppTerminates() throws {
        let url = fileURL(named: "flush-on-terminate.json")
        let storage = SampleStorage(SampleRecord(name: "start", count: 0),
                                    url: url,
                                    updateMode: .afterIdle(seconds: 60))
        storage.value = SampleRecord(name: "pending", count: 9)

        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)

        XCTAssertEqual(try readRecord(from: url), SampleRecord(name: "pending", count: 9))
        withExtendedLifetime(storage) {}
    }
    #endif

    // The idle write read `value` on a global queue while the main thread mutated it. Run with
    // `swift test --sanitize=thread` to detect the race.
    func testIdleWritesWhileValueIsMutatedOnMainThread() {
        let url = fileURL(named: "race.json")
        let storage = SampleStorage(SampleRecord(name: "start", count: 0),
                                    url: url,
                                    updateMode: .afterIdle(seconds: 0))
        let finalRecord = SampleRecord(name: String(repeating: "x", count: 200), count: 500)
        for count in 1...500 {
            storage.value = SampleRecord(name: String(repeating: "x", count: count % 200 + 1), count: count)
            if count.isMultiple(of: 50) {
                runMainRunLoop(for: 0.01)
            }
        }
        storage.value = finalRecord
        waitForFile(at: url, toContain: finalRecord, timeout: 5)
    }
}
