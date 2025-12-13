import Photos
import SwiftUI

struct SettingsView: View {
    @StateObject private var blurredPhotosStore = BlurredPhotosStore.shared
    @StateObject private var privacySettings = PrivacySettings.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteAllAlert = false
    @State private var deletionInProgress = false
    @State private var deletionResult: DeletionResult?
    @State private var showingDeletionResult = false

    var body: some View {
        List {
            Section {
                ForEach(PrivacyMode.allCases) { mode in
                    Button(action: {
                        privacySettings.privacyMode = mode
                    }) {
                        HStack {
                            Image(systemName: mode.iconName)
                                .foregroundColor(mode.isBoxMode ? .purple : .blue)
                                .frame(width: 30)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.localizedName)
                                    .foregroundColor(.primary)
                                Text(mode.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if privacySettings.privacyMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel(
                        privacySettings.privacyMode == mode
                            ? Text(
                                String(
                                    format: NSLocalizedString(
                                        "accessibility.selectedPrivacyMode", comment: ""),
                                    mode.localizedName))
                            : Text(
                                String(
                                    format: NSLocalizedString(
                                        "accessibility.privacyModeOption", comment: ""),
                                    mode.localizedName))
                    )
                    .accessibilityAddTraits(
                        privacySettings.privacyMode == mode ? .isSelected : [])
                }
            } header: {
                Text("settings.privacyMode.header")
            } footer: {
                Text("settings.privacyMode.footer")
            }

            if privacySettings.privacyMode == .customBox {
                Section {
                    ColorPicker(
                        "settings.customColor.picker",
                        selection: $privacySettings.customBoxColor,
                        supportsOpacity: true
                    )
                    .accessibilityLabel(Text("accessibility.colorPicker"))
                } header: {
                    Text("settings.customColor.header")
                } footer: {
                    Text("settings.customColor.footer")
                }
            }

            Section {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    Text("settings.statistics.blurredCount")
                    Spacer()
                    Text("\(blurredPhotosStore.blurredPhotoIdentifiers.count)")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("settings.statistics.header")
            }

            Section {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        Text("settings.managePhotos.deleteAll")
                            .foregroundColor(.red)
                        Spacer()
                        if deletionInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(
                    blurredPhotosStore.blurredPhotoIdentifiers.isEmpty || deletionInProgress)

                Button(action: {
                    showingDeleteAllAlert = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        Text("settings.managePhotos.clearHistory")
                            .foregroundColor(.orange)
                    }
                }
                .disabled(blurredPhotosStore.blurredPhotoIdentifiers.isEmpty)
            } header: {
                Text("settings.managePhotos.header")
            } footer: {
                Text("settings.managePhotos.footer")
            }

            Section {
                NavigationLink(destination: BlurredPhotosListView()) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        Text("settings.history.viewPhotos")
                    }
                }
                .disabled(blurredPhotosStore.blurredPhotoIdentifiers.isEmpty)
            } header: {
                Text("settings.history.header")
            }

            Section {
                Button(action: {
                    TooltipManager.shared.resetAllTooltips()
                }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        Text("settings.tips.resetTooltips")
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("settings.tips.header")
            } footer: {
                Text("settings.tips.footer")
            }

            Section {
                NavigationLink(destination: PrivacyPolicyView()) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.about.privacyTitle")
                                .font(.headline)
                            Text("settings.about.privacyDescription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel(Text("About This App's Privacy"))
            } header: {
                Text("settings.about.header")
            }
        }
        .navigationTitle(Text("settings.title"))
        .alert(
            String(localized: "alert.deleteAll.title"), isPresented: $showingDeleteConfirmation
        ) {
            Button("navigation.cancel", role: .cancel) {}
            Button("alert.deleteAll.confirm", role: .destructive) {
                deleteAllBlurredPhotos()
            }
        } message: {
            Text(
                String(
                    format: NSLocalizedString("alert.deleteAll.message", comment: ""),
                    blurredPhotosStore.blurredPhotoIdentifiers.count)
            )
        }
        .alert(
            String(localized: "alert.clearHistory.title"), isPresented: $showingDeleteAllAlert
        ) {
            Button("navigation.cancel", role: .cancel) {}
            Button("alert.clearHistory.confirm", role: .destructive) {
                blurredPhotosStore.clearAll()
            }
        } message: {
            Text("alert.clearHistory.message")
        }
        .alert(
            String(localized: "alert.deletionComplete.title"), isPresented: $showingDeletionResult
        ) {
            Button("alert.ok", role: .cancel) {}
        } message: {
            if let result = deletionResult {
                Text(
                    String(
                        format: NSLocalizedString("alert.deletionComplete.message", comment: ""),
                        result.successCount, result.failedCount)
                )
            }
        }
    }

    private func deleteAllBlurredPhotos() {
        deletionInProgress = true

        Task {
            let result = await PhotoManager.shared.deletePhotos(
                identifiers: Array(blurredPhotosStore.blurredPhotoIdentifiers))

            await MainActor.run {
                deletionInProgress = false
                deletionResult = result
                showingDeletionResult = true

                // Clear successfully deleted photos from tracking
                for identifier in result.deletedIdentifiers {
                    blurredPhotosStore.removePhoto(identifier: identifier)
                }
            }
        }
    }
}

struct BlurredPhotosListView: View {
    @StateObject private var blurredPhotosStore = BlurredPhotosStore.shared
    @State private var thumbnails: [String: UIImage] = [:]

    var body: some View {
        List {
            ForEach(Array(blurredPhotosStore.blurredPhotoIdentifiers), id: \.self) { identifier in
                HStack {
                    if let thumbnail = thumbnails[identifier] {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                ProgressView()
                            }
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading) {
                        Text("blurredPhotosList.itemTitle")
                            .font(.headline)
                        Text(identifier.prefix(8) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityLabel(Text("accessibility.blurredPhotoThumbnail"))
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle(Text("blurredPhotosList.title"))
        .onAppear {
            loadThumbnails()
        }
    }

    private func loadThumbnails() {
        let identifiers = Array(blurredPhotosStore.blurredPhotoIdentifiers)

        Task {
            for identifier in identifiers {
                if let thumbnail = await PhotoManager.shared.loadThumbnail(
                    for: identifier, size: CGSize(width: 120, height: 120))
                {
                    await MainActor.run {
                        thumbnails[identifier] = thumbnail
                    }
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let identifiers = Array(blurredPhotosStore.blurredPhotoIdentifiers)
        let toDelete = offsets.map { identifiers[$0] }

        Task {
            let _ = await PhotoManager.shared.deletePhotos(identifiers: toDelete)

            await MainActor.run {
                for identifier in toDelete {
                    blurredPhotosStore.removePhoto(identifier: identifier)
                    thumbnails.removeValue(forKey: identifier)
                }
            }
        }
    }
}

struct DeletionResult {
    let successCount: Int
    let failedCount: Int
    let deletedIdentifiers: [String]
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Last updated: December 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }

                Divider()

                Group {
                    SectionHeader("Overview")
                    Text(
                        "This app is designed with privacy as a core principle. It does not collect, transmit, store, or share any personal data."
                    )
                }

                Group {
                    SectionHeader("Data Collection")
                    Text("The app does **not** collect any user data.")
                    Text("Specifically:")
                    BulletPoint("No personal information is collected")
                    BulletPoint("No analytics are used")
                    BulletPoint("No crash reporting is enabled")
                    BulletPoint("No identifiers are created or tracked")
                }

                Group {
                    SectionHeader("Data Storage")
                    Text("All functionality is performed **entirely on-device**.")
                    Text("Any data created or used by the app:")
                    BulletPoint("Remains local to your device")
                    BulletPoint("Is never transmitted to external servers")
                    BulletPoint("Is never shared with third parties")
                    Text("The app does not operate any servers or backend services.")
                }

                Group {
                    SectionHeader("Network Usage")
                    Text(
                        "The app does not communicate with any remote servers and does not send or receive data over the network."
                    )
                }

                Group {
                    SectionHeader("Third-Party Services")
                    Text(
                        "The app does not use any third-party SDKs, services, or libraries that collect data."
                    )
                }

                Group {
                    SectionHeader("Children's Privacy")
                    Text(
                        "The app does not collect personal information from anyone, including children under the age of 13."
                    )
                }

                Group {
                    SectionHeader("Changes to This Policy")
                    Text(
                        "If this privacy policy changes, the updated version will be published at this URL."
                    )
                }

                Group {
                    SectionHeader("Contact")
                    Text(
                        "If you have questions about this privacy policy, you may contact the developer via the GitHub repository associated with this app."
                    )
                }
            }
            .padding()
        }
        .navigationTitle("About This App's Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.top, 8)
    }
}

private struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .padding(.leading, 16)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
