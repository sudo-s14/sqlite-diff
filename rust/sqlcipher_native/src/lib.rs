// This crate builds SQLCipher as a cdylib, re-exporting all sqlite3_* C API
// symbols so that Dart's `package:sqlite3` can load it via DynamicLibrary.open().
//
// The actual work is done by `libsqlite3-sys` with the `bundled-sqlcipher` feature.

extern crate libsqlite3_sys;

use libsqlite3_sys::sqlite3_libversion;

/// Dummy function to prevent the linker from stripping sqlite3 symbols.
#[no_mangle]
pub extern "C" fn sqlcipher_native_init() -> *const std::os::raw::c_char {
    unsafe { sqlite3_libversion() }
}
