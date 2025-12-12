import Photos
import SwiftUI

struct SettingsView: View {
    @StateObject private var blurredPhotosStore = BlurredPhotosStore.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteAllAlert = false
    @State private var deletionInProgress = false
    @State private var deletionResult: DeletionResult?
    @State private var showingDeletionResult = false

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Blurred Photos Count")
                    Spacer()
                    Text("\(blurredPhotosStore.blurredPhotoIdentifiers.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Statistics")
            }

            Section {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        Text("Delete All Blurred Photos from Photos")
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
                        Text("Clear Tracking History")
                            .foregroundColor(.orange)
                    }
                }
                .disabled(blurredPhotosStore.blurredPhotoIdentifiers.isEmpty)
            } header: {
                Text("Manage Blurred Photos")
            } footer: {
                Text(
                    "'Delete All Blurred Photos' will permanently delete the blurred copies you created from your Photos library. 'Clear Tracking History' only removes the tracking data without deleting any photos."
                )
            }

            Section {
                NavigationLink(destination: BlurredPhotosListView()) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("View Blurred Photos")
                    }
                }
                .disabled(blurredPhotosStore.blurredPhotoIdentifiers.isEmpty)
            } header: {
                Text("History")
            }

            Section {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Protection")
                            .font(.headline)
                        Text(
                            "Faces are blurred using strong pixelation that cannot be reversed or reconstructed."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Blurred Photos?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                deleteAllBlurredPhotos()
            }
        } message: {
            Text(
                "This will permanently delete \(blurredPhotosStore.blurredPhotoIdentifiers.count) blurred photo(s) from your Photos library. This action cannot be undone."
            )
        }
        .alert("Clear Tracking History?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                blurredPhotosStore.clearAll()
            }
        } message: {
            Text(
                "This will only clear the tracking history. The blurred photos will remain in your Photos library."
            )
        }
        .alert("Deletion Complete", isPresented: $showingDeletionResult) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = deletionResult {
                Text(
                    "Successfully deleted \(result.successCount) photo(s). \(result.failedCount) failed."
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
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                ProgressView()
                            }
                    }

                    VStack(alignment: .leading) {
                        Text("Blurred Photo")
                            .font(.headline)
                        Text(identifier.prefix(8) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Blurred Photos")
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

#Preview {
    SettingsView()
}
