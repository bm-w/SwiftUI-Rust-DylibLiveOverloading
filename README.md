# Tiny dylib-autoreloading SwiftUI app

Two projects in the repo:
 -  main SwiftUI app at `./Main`
 -  Rust library at `./lib-rs`

## Instructions

Open `./Main/Main.xcodeproj` in Xcode and open the `macOS/Debug.xcconfig` file. Note the `<overridden>` values for `MY_CARGO_BIN` and `MY_DYLIB_CARGO_TOML`. Create a new file `macOS/My-Debug.xcconfig` and set the overriding paths there. Also set a value for `DEVELOPMENT_TEAM` there.

Build and run the Xcode project on a macOS target (it will automatically build & copy the Rust library using Build Phase). Use the button to manually trigger a library (re)load, and/or check the toggle to start watching the `MY_DYLIB_DIR` (from `macOS/Debug.xcconfig`) directory and (re)load the library automatically as it changes. Manually build the Rust library, copy it into place, and observe the behavior:

```sh
cargo build --manifest-path ./lib-rs/Cargo.toml \
  && cp ./lib-rs/target/debug/liblib.dylib "${MY_DYLIB_DIR}/lib-$(date +%s).dylib"
```

_Note: Unlike with C libraries, `dlclose` does not actually purge loaded Rust libraries from the cache (something about TLS/TLV). As a result, when attempting to `dlopen` a library with an identical filename as another previously loaded and cached library the cached library will be loaded instead. Using distinct filenames every time avoids this behavior, but of course at the cost of leaking the cached libraries._

## To Do

 - [ ] Automatically include `.framework` bundle in the `.app` bundle instead of loading dynamic libary in _Release_ build configuration.
