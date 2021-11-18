//
//  Created by Bastiaan Marinus van de Weerd on 18-11-21.
//

import SwiftUI
import UniformTypeIdentifiers


@main struct MainApp: App {

	@State private var _lastLoadedDylib: URL?
	@State private var _stopAutoloadingDylib: (() -> Void)?

	private var _isAutoloadingDylib: Bool {
		get { _stopAutoloadingDylib != nil }
		nonmutating set {
			switch (_stopAutoloadingDylib, newValue) {
			case (nil, true):
				_stopAutoloadingDylib = _startAutoloadingDylib(lastLoaded: _lastLoadedDylib) { dylib in
					print(dylib.map({ "Did load (at \($0.path)" }) ?? "Couldn’t load…")
					if dylib != nil { _lastLoadedDylib = dylib }
				}
			case (let stop?, false):
				stop()
				_stopAutoloadingDylib = nil
			default: break
			}
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView(
				loadDylib: {
					precondition(!_isAutoloadingDylib)
					_lastLoadedDylib = _loadDylib()
				},
				isAutoloadingDylib: Binding()
					{ _isAutoloadingDylib }
					set: { _isAutoloadingDylib = $0 }
			)
		}
	}
}


// MARK: - Dylib

private let _myDylibDirectoryInfoKey = "_MyDylibDirectory"

private func _dylibDirectory() -> URL? {
	guard let directoryPath = Bundle.main.infoDictionary?[_myDylibDirectoryInfoKey]
	else { print("?A"); return nil } // No dylib loading

	guard let directory = (directoryPath as? String).map({ URL.init(fileURLWithPath: $0, isDirectory: true) })
	else { preconditionFailure("Info value for key \(_myDylibDirectoryInfoKey) is not a valid directory path") }

	return directory
}

private let _dylibResourceKeys: [URLResourceKey] = [
	.contentModificationDateKey,
	.isRegularFileKey,
	.contentTypeKey,
]

private func _selectDylib(in directory: URL) -> URL? {
	do {
		var selectedLib: (modificationDate: Date, url: URL)? = nil

		for lib in try FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: _dylibResourceKeys,options: []) {
			let resourceValues = try lib.resourceValues(forKeys: Set(_dylibResourceKeys))
			guard
				resourceValues.isRegularFile ?? false,
				resourceValues.contentType == UTType("com.apple.mach-o-dylib"),
				let modificationDate = resourceValues.contentModificationDate
			else { continue }

			if selectedLib.map({ modificationDate > $0.modificationDate }) ?? true {
				selectedLib = (modificationDate, lib)
			}
		}

		return selectedLib?.url

	} catch {
		print("Error selecting dylib in directory at '\(directory.path)':\n\(error)")
		return nil
	}
}

private func _loadDylib(atURL dylib: URL) {

	func dlerrorSuffix() -> String { "(error: \"\(String(cString: dlerror()))\")" }

	guard let loadedLibrary = dylib.path.withCString({ dlopen($0, RTLD_LAZY) }) else {
		fatalError("Failed to load library at '\(dylib.path)'\(dlerrorSuffix())")
	}

	guard let loadedTestSymbol = dlsym(loadedLibrary, "test") else {
		fatalError("Failed to load 'test' symbol in library at '\(dylib.path)'\(dlerrorSuffix())")
	}

	unsafeBitCast(loadedTestSymbol, to: (@convention(c) () -> Void).self)()

	guard dlclose(loadedLibrary) == 0 else {
		fatalError("Failed to close library\(dlerrorSuffix())")
	}
}

private func _loadDylib() -> URL? {
	_dylibDirectory().flatMap({ directory in
		guard let dylib = _selectDylib(in: directory) else { return nil }
		_loadDylib(atURL: dylib)
		return dylib
	})
}

private typealias _DylibAutoloadingStopper = () -> Void

private func _startAutoloadingDylib(lastLoaded: URL?, didLoad: @escaping (URL?) -> Void) -> _DylibAutoloadingStopper? {
	guard let directory = _dylibDirectory() else { return nil }

	print("Starting to auto-(re)load Dylib in watched directory '\(directory.path)'...")

	struct Info {
		let directory: URL
		let didLoad: (URL?) -> Void
		var lastLoaded: URL?
	}

	let infoPtr = UnsafeMutablePointer<Info>.allocate(capacity: 1)
	infoPtr.initialize(to: Info(
		directory: directory,
		didLoad: didLoad,
		lastLoaded: {
			guard
				let dylib = _selectDylib(in: directory),
				dylib != lastLoaded
			else { return nil }
			_loadDylib(atURL: dylib)
			return dylib
		}()
	))

	var context = FSEventStreamContext(
		version: 0,
		info: UnsafeMutableRawPointer(infoPtr),
		retain: nil,
		release: { $0?.deallocate() },
		copyDescription: nil
	)

	guard let stream = FSEventStreamCreate(
		nil,
		{ stream, context, numberOfEvents, eventPaths, eventFlags, eventIds in
			guard let info = context?.assumingMemoryBound(to: Info.self) else { return }

			let dylib = _selectDylib(in: info.pointee.directory)
			if let dylib = dylib, dylib != info.pointee.lastLoaded {
				_loadDylib(atURL: dylib)
			}
			info.pointee.didLoad(dylib)
		},
		&context,
		[directory.path as CFString] as CFArray,
		UInt64(kFSEventStreamEventIdSinceNow),
		1,
		UInt32(kFSEventStreamEventFlagItemCreated)
	) else {
		fatalError("Failed to create FS even stream watching directory at '\(directory.path)'")
	}

	FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
	FSEventStreamStart(stream)

	return {
		FSEventStreamStop(stream)
	}
}
