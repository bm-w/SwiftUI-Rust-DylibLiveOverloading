//
//  Created by Bastiaan Marinus van de Weerd on 18-11-21.
//

import SwiftUI


struct ContentView: View {

	let loadDylib: () -> Void
	@Binding var isAutoloadingDylib: Bool

	var body: some View {
		VStack {
			Button() {
				loadDylib()
			} label: {
				Text("(Re)load Dylib now")
			}
			.disabled(isAutoloadingDylib)
			.padding()

			Toggle(isOn: $isAutoloadingDylib) {
				Text("Automatically (Re)load Dylib")
			}
			.padding()
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(loadDylib: {}, isAutoloadingDylib: Binding.constant(false))
	}
}
