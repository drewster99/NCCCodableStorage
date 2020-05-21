# NCCCodableStorage

**Automatic Codable storage to/from JSON**
Twitter *@DrewsterBenson*

Whenever a defaultValue is given, **NCCCodableStorage** will attempt to load the initial value from the existing JSON at initialization time.  If a saved value cannot be loaded or decoded, the defaultValue is used as the initial value.

As above, any changes are immediately and synchronously written to storage.

```swift
    struct MyData: Codable {
        var name: String = "Mister Default"
        var age: Double = 29
    }
    
    @NCCCodableStorage(defaultValue: MyData(), filename: "myData.json") var myData: MyData
```

At initialization, it will attempt to read an array of struct **MyData** from **myDataArray.json**.  If it cannot be read or decoded, the *defaultValue*, in this case an empty array, will initially be used.

Using **updateMode: .afterIdle(5.0)** will write updates back to the **myDataArray.json** storage only after the *wrappedValue* has not changed in at least 5.0 seconds.

```swift
    @NCCCodableStorage(defaultValue: [],
                       filename: "myDataArray.json",
                       updateMode: .afterIdle(5.0)) var myDataArray: [MyData]
```

Initializing using **initialValue: ...** is the same as including it after the declaration.

```swift
    // This:
    @NCCCodableStorage(initialValue: 8.675309, url: someURL) var jenny: Double
    
    // is equivalent to this:
    @NCCCodableStorage(url: someURL) var jenny: Double = 8.675309
```

We can initialize with manual value updates instead of automatic also.  Data can then be manually loaded with:  **_someData.load()** or manually saved with: ** _someData.save()**.

```swift
    @NCCCodableStorage(filename: "someData.json", updateMode: .manual) var someData: [MyData] = []
```

Creates the full path for the file based onthe given directoryType.

```swift
    @NCCCodableStorage(filename: "someFileName.json", directoryType: .desktopDirectory)
    private var fooooo: [String] = ["hello", "there"]
```

