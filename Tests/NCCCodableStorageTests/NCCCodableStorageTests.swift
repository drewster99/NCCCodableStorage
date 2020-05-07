import XCTest
import Foundation

@testable import NCCCodableStorage

final class NCCCodableStorageTests: XCTestCase {
    // Can't wait until we can use propertywrappers inside of functions etc..
    @NCCCodableStorage(initialValue: "hello",
                       filename: "nccCodableStorageTests_string.json",
                       directoryType: .documentDirectory,
                       updateMode: .manual) var string: String

    // Super weak test -- don't hate me.  or do.  I dont' care.
    func simpleCodableStorageTest() {
        try? FileManager.default.removeItem(at: _string.url)

        string = "craziness"
        do { try _string.save() }
        catch {
            XCTFail("Failed saving 'craziness': \(error)")
            return
        }

        string = "afterSaving"

        do { try _string.load() }
        catch {
            XCTFail("Failed loading 'craziness': \(error)")
            return
        }
        XCTAssertEqual(string, "craziness", "String loaded '\(string)' != string saved previously 'craziness'")
        
    }

    static var allTests = [
        ("Simple codable storage test", simpleCodableStorageTest),
    ]
}
