import Photos
import SwiftUI

struct PhotoGridView: View {
    @StateObject private var photoLibrary = PhotoLibraryManager()
    @State private var selectedAsset: PHAsset?
    @State private var showingEditor = false
    @State private var showingPermissionAlert = false
    @State private var showingSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if photoLibrary.authorizationStatus == .authorized
                    || photoLibrary.authorizationStatus == .limited
                {
                    if photoLibrary.assets.isEmpty {
                        ContentUnavailableView(
                            "No Photos",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Your photo library is empty")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photoLibrary.assets, id: \.localIdentifier) { asset in
                                    PhotoThumbnailView(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedAsset = asset
                                            showingEditor = true
                                        }
                                }
                            }
                        }
                    }
                } else if photoLibrary.authorizationStatus == .denied
                    || photoLibrary.authorizationStatus == .restricted
                {
                    ContentUnavailableView(
                        "Photo Access Required",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text(
                            "Please grant access to your photos in Settings to use this app")
                    )
                    .overlay(alignment: .bottom) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                } else {
                    ProgressView("Loading Photos...")
                }
            }
            .navigationTitle("Photos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationDestination(isPresented: $showingEditor) {
                if let asset = selectedAsset {
                    PhotoEditView(asset: asset)
                }
            }
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                photoLibrary.requestAuthorization()
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .onAppear {
                loadImage(
                    targetSize: CGSize(
                        width: geometry.size.width * 2, height: geometry.size.height * 2))
            }
        }
    }

    private func loadImage(targetSize: CGSize) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            if let result = result {
                DispatchQueue.main.async {
                    self.image = result
                }
            }
        }
    }
}

#Preview {
    PhotoGridView()
}
