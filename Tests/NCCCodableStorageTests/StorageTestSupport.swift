import XCTest
import Foundation
import NCCCoding

@testable import NCCCodableStorage

/// Value type used by the storage tests.
struct SampleRecord: Codable, Equatable {
    var name: String
    var count: Int
}

typealias SampleStorage = NCCCodableStorage<SampleRecord>.NCCCodableJSONStorage<SampleRecord>
typealias SampleUpdateMode = NCCCodableStorage<SampleRecord>.UpdateMode

/// Base class giving each test its own empty temporary directory, removed afterward.
class TemporaryDirectoryTestCase: XCTestCase {
    private(set) var temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NCCCodableStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectoryURL)
        try super.tearDownWithError()
    }

    func fileURL(named filename: String) -> URL {
        temporaryDirectoryURL.appendingPathComponent(filename)
    }

    /// A URL whose parent directory does not exist, so every write to it fails.
    func unwritableFileURL() -> URL {
        temporaryDirectoryURL
            .appendingPathComponent("missing-directory", isDirectory: true)
            .appendingPathComponent("record.json")
    }

    func writeRecord(_ record: SampleRecord, to url: URL, file: StaticString = #filePath, line: UInt = #line) {
        if let error = NCCCoding.encode(record, to: url) {
            XCTFail("Test setup failed writing \(url.path): \(error)", file: file, line: line)
        }
    }

    func readRecord(from url: URL) throws -> SampleRecord {
        let result: Result<SampleRecord, Error> = NCCCoding.decode(url)
        return try result.get()
    }

    /// Waits, without blocking the main run loop, until the file at `url` decodes to `expected`.
    func waitForFile(at url: URL, toContain expected: SampleRecord, timeout: TimeInterval,
                     file: StaticString = #filePath, line: UInt = #line) {
        let fileMatches = expectation(description: "\(url.lastPathComponent) contains \(expected)")
        let deadline = Date().addingTimeInterval(timeout)
        func check() {
            let result: Result<SampleRecord, Error> = NCCCoding.decode(url)
            if case .success(let record) = result, record == expected {
                fileMatches.fulfill()
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { check() }
            }
        }
        check()
        wait(for: [fileMatches], timeout: timeout + 1)
    }

    /// Lets queued main-queue and storage-queue work run for the given time.
    func runMainRunLoop(for interval: TimeInterval) {
        let elapsed = expectation(description: "run loop ran for \(interval)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: interval + 5)
    }
}
