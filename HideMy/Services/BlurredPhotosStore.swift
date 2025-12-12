import Foundation
import SwiftUI

/// Stores and manages the list of blurred photo identifiers
/// Uses UserDefaults for persistence
class BlurredPhotosStore: ObservableObject {
    static let shared = BlurredPhotosStore()

    private let storageKey = "BlurredPhotoIdentifiers"

    @Published private(set) var blurredPhotoIdentifiers: Set<String> = []

    init() {
        loadFromStorage()
    }

    /// Add a photo identifier to the blurred photos list
    func addBlurredPhoto(_ identifier: String) {
        DispatchQueue.main.async {
            self.blurredPhotoIdentifiers.insert(identifier)
            self.saveToStorage()
        }
    }

    /// Remove a specific photo from tracking
    func removePhoto(identifier: String) {
        DispatchQueue.main.async {
            self.blurredPhotoIdentifiers.remove(identifier)
            self.saveToStorage()
        }
    }

    /// Clear all tracked photos
    func clearAll() {
        DispatchQueue.main.async {
            self.blurredPhotoIdentifiers.removeAll()
            self.saveToStorage()
        }
    }

    /// Check if a photo is in our blurred list
    func isBlurred(_ identifier: String) -> Bool {
        blurredPhotoIdentifiers.contains(identifier)
    }

    /// Get count of blurred photos
    var count: Int {
        blurredPhotoIdentifiers.count
    }

    // MARK: - Private Methods

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
            let identifiers = try? JSONDecoder().decode(Set<String>.self, from: data)
        {
            blurredPhotoIdentifiers = identifiers
        }
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(blurredPhotoIdentifiers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
