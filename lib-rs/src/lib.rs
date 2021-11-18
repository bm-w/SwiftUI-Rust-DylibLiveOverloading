use std::io::{self, Write};


#[no_mangle]
pub extern "C" fn test() {
	io::stdout().write_all(b"Dung!\n").unwrap();
}
