import Photos
import SwiftUI

struct PhotoGridView: View {
    @StateObject private var photoLibrary = PhotoLibraryManager()
    @State private var selectedAsset: PHAsset?
    @State private var showingEditor = false
    @State private var showingPermissionAlert = false
    @State private var showingSettings = false
    @State private var hasShownPrePermission = false

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
                            String(localized: "photoGrid.noPhotos.title"),
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("photoGrid.noPhotos.description")
                        )
                    } else {
                        ScrollView {
                            TooltipBanner(
                                icon: "hand.tap",
                                message: "photoGrid.tooltip",
                                tooltipKey: .photoGridSelect
                            )

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photoLibrary.assets, id: \.localIdentifier) { asset in
                                    PhotoThumbnailView(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .accessibilityLabel(Text("accessibility.photoThumbnail"))
                                        .accessibilityAddTraits(.isButton)
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
                        String(localized: "photoGrid.accessRequired.title"),
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("photoGrid.accessRequired.description")
                    )
                    .overlay(alignment: .bottom) {
                        Button("photoGrid.openSettings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                        .accessibilityLabel(Text("accessibility.openSettingsButton"))
                    }
                } else if photoLibrary.authorizationStatus == .notDetermined
                    && !hasShownPrePermission
                {
                    // Pre-permission explanation view
                    PrePermissionView {
                        hasShownPrePermission = true
                        photoLibrary.requestAuthorization()
                    }
                } else {
                    ProgressView(String(localized: "photoGrid.loading"))
                }
            }
            .navigationTitle(Text("photoGrid.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel(Text("accessibility.settingsButton"))
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
                // Only auto-request if already determined (not first launch)
                if photoLibrary.authorizationStatus != .notDetermined {
                    photoLibrary.requestAuthorization()
                }
            }
        }
    }
}

// MARK: - Pre-Permission View

struct PrePermissionView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            // Title
            Text("prePermission.title")
                .font(.title)
                .fontWeight(.bold)

            // Explanation
            VStack(alignment: .leading, spacing: 16) {
                PermissionReasonRow(
                    icon: "photo.stack",
                    title: String(localized: "prePermission.browse.title"),
                    description: String(localized: "prePermission.browse.description")
                )

                PermissionReasonRow(
                    icon: "square.and.arrow.down",
                    title: String(localized: "prePermission.save.title"),
                    description: String(localized: "prePermission.save.description")
                )

                PermissionReasonRow(
                    icon: "lock.shield",
                    title: String(localized: "prePermission.privacy.title"),
                    description: String(localized: "prePermission.privacy.description")
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("prePermission.continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityLabel(Text("accessibility.continueButton"))

            // Footer note
            Text("prePermission.changeInSettings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }
}

struct PermissionReasonRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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

#Preview("Pre-Permission") {
    PrePermissionView {
        print("Continue tapped")
    }
}
