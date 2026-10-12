import XCTest
import Foundation

@testable import NCCCodableStorage

/// Behavior of the underlying JSON storage in each update mode, using a temporary directory.
final class StorageBehaviorTests: TemporaryDirectoryTestCase {

    private let initialRecord = SampleRecord(name: "initial", count: 0)
    private let changedRecord = SampleRecord(name: "changed", count: 1)

    // MARK: - Initial value

    func testLoadingInitializerUsesDefaultValueWhenFileIsMissing() {
        let storage = SampleStorage(loadingFrom: fileURL(named: "missing.json"),
                                    defaultValue: initialRecord,
                                    updateMode: .manual)
        XCTAssertEqual(storage.value, initialRecord)
    }

    func testLoadingInitializerUsesSavedValueWhenFileExists() {
        let url = fileURL(named: "existing.json")
        writeRecord(changedRecord, to: url)
        let storage = SampleStorage(loadingFrom: url, defaultValue: initialRecord, updateMode: .manual)
        XCTAssertEqual(storage.value, changedRecord)
    }

    // MARK: - Manual mode

    func testManualModeDoesNotWriteOnChange() {
        let url = fileURL(named: "manual.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .manual)
        storage.value = changedRecord
        withExtendedLifetime(storage) {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveThenLoadRoundTrips() throws {
        let url = fileURL(named: "round-trip.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .manual)
        storage.value = changedRecord
        try storage.save()

        storage.value = SampleRecord(name: "unsaved", count: 2)
        try storage.load()

        XCTAssertEqual(storage.value, changedRecord)
        XCTAssertEqual(try readRecord(from: url), changedRecord)
    }

    func testLoadThrowsWhenFileIsMissing() {
        let storage = SampleStorage(initialRecord, url: fileURL(named: "missing.json"), updateMode: .manual)
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(storage.value, initialRecord)
    }

    func testSaveThrowsWhenWriteFails() {
        let storage = SampleStorage(initialRecord, url: unwritableFileURL(), updateMode: .manual)
        XCTAssertThrowsError(try storage.save())
    }

    // MARK: - Immediate mode

    func testImmediateModeWritesSynchronously() throws {
        let url = fileURL(named: "immediate.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .immediate)
        storage.value = changedRecord
        XCTAssertEqual(try readRecord(from: url), changedRecord)
    }

    // MARK: - After-idle mode

    func testAfterIdleModeWritesOnlyAfterTheDelay() {
        let url = fileURL(named: "idle.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .afterIdle(seconds: 0.2))
        storage.value = changedRecord
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "wrote before the idle delay")

        waitForFile(at: url, toContain: changedRecord, timeout: 3)
        withExtendedLifetime(storage) {}
    }

    func testAfterIdleModeWritesOnlyTheLatestValue() {
        let url = fileURL(named: "debounce.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .afterIdle(seconds: 0.1))
        for count in 1...20 {
            storage.value = SampleRecord(name: "change", count: count)
        }
        waitForFile(at: url, toContain: SampleRecord(name: "change", count: 20), timeout: 3)
        withExtendedLifetime(storage) {}
    }

    func testSaveCancelsPendingIdleWrite() throws {
        let url = fileURL(named: "save-cancels.json")
        let storage = SampleStorage(initialRecord, url: url, updateMode: .afterIdle(seconds: 0.1))
        storage.value = changedRecord
        try storage.save()

        let externalRecord = SampleRecord(name: "external", count: 5)
        writeRecord(externalRecord, to: url)
        runMainRunLoop(for: 0.3)

        XCTAssertEqual(try readRecord(from: url), externalRecord, "cancelled idle write still ran")
        withExtendedLifetime(storage) {}
    }
}
