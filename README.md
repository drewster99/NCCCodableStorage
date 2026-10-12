# NCCCodableStorage

A SwiftUI property wrapper that keeps a `Codable` value in a local JSON file. It works like `@State`, but the value is saved to disk when it changes.

## Requirements

- iOS 14+ / macOS 11+
- Swift 5.5+

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/drewster99/NCCCodableStorage.git", from: "1.1.2")
]
```

Then add `"NCCCodableStorage"` to your target's dependencies.

## Usage

Declare the property inside a SwiftUI `View`. The storage behind it is a `@StateObject`, so it is created once per view identity and only works correctly when SwiftUI installs it in a view. Outside a `View`, each access creates a new storage object and changes are not kept in memory.

```swift
import SwiftUI
import NCCCodableStorage

struct Profile: Codable {
    var name: String = "Mister Default"
    var age: Double = 29
}

struct ProfileView: View {
    // Loads profile.json from the Documents directory if it exists and decodes;
    // otherwise starts with Profile(). Changes are written 2 seconds after the last edit.
    @NCCCodableStorage(defaultValue: Profile(), filename: "profile.json") var profile: Profile

    var body: some View {
        TextField("Name", text: $profile.name)
    }
}
```

### Initial value

- **`defaultValue:`** reads the existing file when the storage is created. If the file is missing or can't be decoded, `defaultValue` is used.
- **`initialValue:`** or a value after the declaration (`var x: T = value`) does **not** read the file. The property starts with the given value and the next automatic write overwrites any existing file.

```swift
// Loads the saved array, or starts empty.
@NCCCodableStorage(defaultValue: [], filename: "items.json") var items: [Profile]

// Starts with 8.675309 without reading someURL. Equivalent to:
// @NCCCodableStorage(url: someURL) var jenny: Double = 8.675309
@NCCCodableStorage(initialValue: 8.675309, url: someURL) var jenny: Double
```

### Where the file lives

Use `filename:` with an optional `directoryType:` (default `.documentDirectory`, user domain), or pass a full file `url:`. The parent directory of a custom URL must already exist.

```swift
@NCCCodableStorage(defaultValue: [], filename: "cache.json", directoryType: .cachesDirectory)
var cachedItems: [String]
```

### Update modes

| Mode | When changes are written |
| --- | --- |
| `.afterIdle(seconds:)` (default: `.afterIdle(seconds: 2.0)`) | Once the value has not changed for the given time. Pending changes are also written when the app moves to the background or terminates, and when the storage is released. |
| `.immediate` | Synchronously, on every change. |
| `.manual` | Only when you call `save()`. |

```swift
@NCCCodableStorage(defaultValue: [], filename: "items.json", updateMode: .afterIdle(seconds: 5.0))
var items: [Profile]

@NCCCodableStorage(filename: "draft.json", updateMode: .manual) var draft: [Profile] = []
// Later, through the wrapper:
try _draft.save()
try _draft.load()
```

`save()` writes synchronously and throws on failure. `load()` replaces the value with the file's contents and throws if the file can't be read or decoded.

### Errors

A failed automatic write (`.immediate`, `.afterIdle`, or the flush when the app moves to the background, terminates, or the storage is released) logs a fault with `os.Logger` (subsystem `com.nuclearcyborg.NCCCodableStorage`) and then terminates the app with `fatalError`. To handle write errors yourself, use `.manual` and call `save()`, which throws.

Files are written atomically, so a failed or interrupted write leaves the previous file intact.

## License

MIT. See [LICENSE](LICENSE).
