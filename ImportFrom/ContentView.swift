import SwiftUI

struct ContentView: View {
    @StateObject private var helper = SidecarHelper.shared
    @State private var receivedImage: NSImage?
    @State private var isRefreshing = false
    @State private var selectedDeviceIndex: Int = 0
    @State private var selectedServiceIndex: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            if let image = receivedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if helper.devices.isEmpty {
                    Text("No devices found")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Button(action: refreshDevices) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh devices")
            }

            if helper.devices.isEmpty {
                Button(action: {
                    SidecarHelper.shared.triggerImportFromIPhone()
                }) {
                    Label("Import from iPhone", systemImage: "iphone.and.arrow.forward")
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Device", selection: $selectedDeviceIndex) {
                        ForEach(0..<helper.devices.count, id: \.self) { index in
                            Text(helper.devices[index].name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    let device = helper.devices[selectedDeviceIndex]
                    
                    Picker("Action", selection: $selectedServiceIndex) {
                        ForEach(0..<device.services.count, id: \.self) { index in
                            Text(device.services[index].name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Button(action: {
                        let service = device.services[selectedServiceIndex]
                        SidecarHelper.shared.triggerService(service)
                    }) {
                        Label("Import", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .onAppear {
            SidecarHelper.shared.onImageReceived = { image in
                DispatchQueue.main.async {
                    self.receivedImage = image
                }
            }
            refreshDevices()
        }
        .onChange(of: helper.devices) { _, _ in
            selectedDeviceIndex = 0
            selectedServiceIndex = 0
        }
        .onChange(of: selectedDeviceIndex) { _, _ in
            selectedServiceIndex = 0
        }
    }

    private func refreshDevices() {
        isRefreshing = true
        DispatchQueue.global(qos: .userInitiated).async {
            SidecarHelper.shared.refreshDevices()
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
        }
    }
}
