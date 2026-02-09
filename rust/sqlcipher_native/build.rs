fn main() {
    // On macOS, tell the linker to export all sqlite3_* symbols from the dylib
    if std::env::var("CARGO_CFG_TARGET_OS").unwrap() == "macos" {
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        println!(
            "cargo:rustc-link-arg=-Wl,-exported_symbols_list,{}/exported_symbols.txt",
            manifest_dir
        );
    }
}
