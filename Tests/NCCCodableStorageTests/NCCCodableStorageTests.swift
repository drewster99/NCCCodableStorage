import XCTest
import Foundation

@testable import NCCCodableStorage

class Foo {
    // someString will have initial value of "Hello!" and all changes will be synchronously
    // written to "someString.json" immediately every time someString is updated.
    //
    // The file will be placed in the documents directory in the userDomainMask
    @NCCCodableStorage(filename: "someString.json") var someString: String = "Hello!"

    // Whenever a defaultValue is given, NCCCodableStorage will attempt to load the initial value
    // from the existing JSON at initialization time.  If a saved value cannot be loaded or decoded,
    // the defaultValue is used as the initial value.
    //
    // As above, any changes are immediately and synchronously written to storage.
    struct MyData: Codable {
        var name: String = "Mister Default"
        var age: Double = 29
    }
    @NCCCodableStorage(defaultValue: MyData(), filename: "myData.json") var myData: MyData

    // At initialization, it will attempt to read an array of struct MyData from "myDataArray.json".
    // If it cannot be read or decoded, the defaultValue, in this case an empty array, will initially
    // be used.
    //
    // Using "updateMode: .afterIdle(5.0)" will write updates back to the myDataArray.json storage only
    // after the wrappedValue has not changed in at least 5.0 seconds.
    @NCCCodableStorage(defaultValue: [],
                       filename: "myDataArray.json",
                       updateMode: .afterIdle(seconds: 5.0)) var myDataArray: [MyData]
    
    // We can initialize with manual value updates instead of automatic also.
    //
    // Data can then be manually loaded with:  _someData.load()
    // or manually saved with:  _someData.save()
    @NCCCodableStorage(filename: "someData.json", updateMode: .manual) var someData: [MyData] = []

    // Creates the full path for the file based onthe given directoryType.
    @NCCCodableStorage(filename: "someFileName.json", directoryType: .desktopDirectory)
    private var fooooo: [String] = ["hello", "there"]
}


final class NCCCodableStorageTests: XCTestCase {
    // Can't wait until we can use propertywrappers inside of functions etc..
    @NCCCodableStorage(initialValue: "hello",
                       filename: "nccCodableStorageTests_string.json",
                       directoryType: .documentDirectory,
                       updateMode: .manual) var string: String

    @NCCCodableStorage(defaultValue: 10.0, filename: "someDouble.json") var someDouble: Double

    // Super weak test -- don't hate me.  or do.  I dont' care.
    func simpleCodableStorageTest() {
        XCTFail("Screwed")
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

        print("All done.  string at \(_string.url.absoluteString)")
        print("All done.  someDouble at \(_someDouble.url.absoluteString)")
    }

    static var allTests = [
        ("Simple codable storage test", simpleCodableStorageTest),
    ]
}
