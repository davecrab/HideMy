import Photos
import SwiftUI

struct PhotoEditView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: PhotoEditViewModel

    @State private var showingSaveOptions = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showingSaveSuccess = false

    // Zoom and pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(asset: PHAsset) {
        self.asset = asset
        _viewModel = StateObject(wrappedValue: PhotoEditViewModel(asset: asset))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = viewModel.displayImage {
                    imageEditorView(image: image, geometry: geometry)
                } else {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    showingSaveOptions = true
                }
                .disabled(viewModel.blurredRegionIds.isEmpty || isSaving)
            }
        }
        .safeAreaInset(edge: .bottom) {
            toolbarView
        }
        .confirmationDialog("Save Photo", isPresented: $showingSaveOptions) {
            Button("Save Copy to Photos") {
                saveToPhotos()
            }
            Button("Save to Files") {
                saveToFiles()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Photo saved successfully")
        }
        .overlay {
            if isSaving {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
        .onAppear {
            viewModel.loadImage()
        }
    }

    // MARK: - Image Editor View

    @ViewBuilder
    private func imageEditorView(image: UIImage, geometry: GeometryProxy) -> some View {
        let imageSize = image.size
        let viewSize = CGSize(
            width: geometry.size.width,
            height: geometry.size.height - 180
        )

        let baseScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * baseScale * scale
        let scaledHeight = imageSize.height * baseScale * scale
        let scaledSize = CGSize(width: scaledWidth, height: scaledHeight)

        ZStack {
            // Image layer
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(offset)

            // Regions overlay - handles taps on existing regions
            regionsOverlay(
                imageSize: imageSize,
                scaledSize: scaledSize
            )
            .frame(width: scaledWidth, height: scaledHeight)
            .offset(offset)
        }
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(panGesture)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

        // Zoom indicator
        if scale != 1.0 {
            VStack {
                HStack {
                    Spacer()
                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(8)
                }
                Spacer()
            }
        }
    }

    // MARK: - Regions Overlay

    @ViewBuilder
    private func regionsOverlay(imageSize: CGSize, scaledSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            // Invisible base that doesn't capture touches
            Color.clear
                .frame(width: scaledSize.width, height: scaledSize.height)
                .allowsHitTesting(false)

            ForEach(viewModel.regions) { region in
                let rect = convertRegionRect(
                    region.bounds,
                    scaledSize: scaledSize
                )

                RegionOverlayView(
                    region: region,
                    scale: scale,
                    isSelected: viewModel.selectedRegionIds.contains(region.id),
                    isBlurred: viewModel.blurredRegionIds.contains(region.id),
                    onTap: {
                        viewModel.toggleRegionSelection(region.id)
                    },
                    onMove: { delta in
                        let adjustedDelta = CGSize(
                            width: delta.width / scale,
                            height: delta.height / scale
                        )
                        viewModel.moveRegion(region.id, by: adjustedDelta, in: scaledSize)
                    },
                    onResize: { delta, handle in
                        let adjustedDelta = CGSize(
                            width: delta.width / scale,
                            height: delta.height / scale
                        )
                        viewModel.resizeRegion(
                            region.id, by: adjustedDelta, from: handle, in: scaledSize)
                    },
                    onRotate: { angle in
                        viewModel.rotateRegion(region.id, by: angle)
                    },
                    onDelete: {
                        viewModel.deleteRegion(region.id)
                    },
                    canTransform: region.type == .custom
                        && !viewModel.blurredRegionIds.contains(region.id)
                )
                .frame(width: max(rect.width, 30), height: max(rect.height, 30))
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: scaledSize.width, height: scaledSize.height, alignment: .topLeading)
    }

    private func convertRegionRect(_ normalizedRect: CGRect, scaledSize: CGSize) -> CGRect {
        // Vision coordinates have origin at bottom-left, convert to top-left
        let x = normalizedRect.origin.x * scaledSize.width
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * scaledSize.height
        let width = normalizedRect.width * scaledSize.width
        let height = normalizedRect.height * scaledSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 0.5), 5.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        VStack(spacing: 10) {
            // Status
            HStack(spacing: 16) {
                Label("\(viewModel.regions.count) regions", systemImage: "square.on.square")
                Label(
                    "\(viewModel.selectedRegionIds.count) selected", systemImage: "checkmark.circle"
                )
                Label("\(viewModel.blurredRegionIds.count) blurred", systemImage: "eye.slash")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Intensity slider
            HStack {
                Text("Blur:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 35, alignment: .leading)

                Slider(value: $viewModel.blurIntensity, in: 0.25...1.0, step: 0.05)

                Text("\(Int(viewModel.blurIntensity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.undo()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                        Text("Undo")
                            .font(.caption2)
                    }
                }
                .disabled(!viewModel.canUndo)

                Spacer()

                Button {
                    viewModel.selectAll()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("All")
                            .font(.caption2)
                    }
                }
                .disabled(viewModel.regions.isEmpty || viewModel.allRegionsSelected)

                Spacer()

                Button {
                    viewModel.clearSelection()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                        Text("Clear")
                            .font(.caption2)
                    }
                }
                .disabled(viewModel.selectedRegionIds.isEmpty)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                        Text("Reset")
                            .font(.caption2)
                    }
                }
                .disabled(scale == 1.0 && offset == .zero)

                Spacer()

                Button {
                    viewModel.addCustomRegion(at: CGPoint(x: 0.5, y: 0.5))
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.title3)
                        Text("Add")
                            .font(.caption2)
                    }
                }

                Spacer()

                Button {
                    viewModel.blurSelectedRegions()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "eye.slash.fill")
                            .font(.title3)
                        Text("Blur")
                            .font(.caption2)
                    }
                }
                .disabled(viewModel.selectedRegionIds.isEmpty)
                .foregroundColor(viewModel.selectedRegionIds.isEmpty ? .gray : .red)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Save Actions

    private func saveToPhotos() {
        guard let image = viewModel.displayImage else { return }
        isSaving = true

        PhotoManager.shared.saveImageToPhotos(image, originalAssetId: asset.localIdentifier) {
            result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    showingSaveSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func saveToFiles() {
        guard let image = viewModel.displayImage else { return }
        isSaving = true

        PhotoManager.shared.saveImageToFiles(image) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    BlurredPhotosStore.shared.addBlurredPhoto(asset.localIdentifier)
                    showingSaveSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Region Overlay View

struct RegionOverlayView: View {
    let region: BlurRegion
    let scale: CGFloat
    let isSelected: Bool
    let isBlurred: Bool
    let onTap: () -> Void
    let onMove: (CGSize) -> Void
    let onResize: (CGSize, ResizeHandle) -> Void
    let onRotate: (CGFloat) -> Void
    let onDelete: () -> Void
    let canTransform: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var currentResizeDelta: CGSize = .zero
    @State private var activeHandle: ResizeHandle? = nil

    private let handleSize: CGFloat = 28
    private let hitAreaSize: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Main tappable region
                RoundedRectangle(cornerRadius: 4)
                    .stroke(strokeColor, lineWidth: isSelected ? 3 : 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                    )
                    .rotationEffect(.radians(Double(region.rotation)))
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .offset(dragOffset)
            .onTapGesture {
                onTap()
            }
            .gesture(
                canTransform ? moveGesture : nil
            )
            .overlay {
                // Resize handles (only for selected custom regions that can transform)
                if isSelected && canTransform {
                    // Top-left handle
                    handleView(at: .topLeading, size: size)
                    // Top-right handle
                    handleView(at: .topTrailing, size: size)
                    // Bottom-left handle
                    handleView(at: .bottomLeading, size: size)
                    // Bottom-right handle
                    handleView(at: .bottomTrailing, size: size)
                }

                // Type indicator and delete button for custom regions
                if region.type == .custom && !isBlurred {
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.draw")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.orange.opacity(0.9))
                                    .clipShape(Circle())

                                if isSelected {
                                    Button {
                                        onDelete()
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red.opacity(0.9))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(4)
                            Spacer()
                        }
                        Spacer()
                    }
                    .offset(dragOffset)
                }
            }
        }
    }

    @ViewBuilder
    private func handleView(at alignment: Alignment, size: CGSize) -> some View {
        let handle: ResizeHandle = {
            switch alignment {
            case .topLeading: return .topLeft
            case .topTrailing: return .topRight
            case .bottomLeading: return .bottomLeft
            case .bottomTrailing: return .bottomRight
            default: return .bottomRight
            }
        }()

        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .offset(dragOffset)
            .offset(
                x: alignment == .topLeading || alignment == .bottomLeading
                    ? -handleSize / 2 : handleSize / 2,
                y: alignment == .topLeading || alignment == .topTrailing
                    ? -handleSize / 2 : handleSize / 2
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        activeHandle = handle
                        currentResizeDelta = value.translation
                    }
                    .onEnded { value in
                        onResize(value.translation, handle)
                        activeHandle = nil
                        currentResizeDelta = .zero
                    }
            )
    }

    private var strokeColor: Color {
        if isBlurred {
            return .green
        } else if isSelected {
            return .blue
        } else if region.type == .custom {
            return .orange
        } else {
            return .yellow
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                onMove(value.translation)
                dragOffset = .zero
            }
    }
}

// MARK: - ViewModel

@MainActor
class PhotoEditViewModel: ObservableObject {
    let asset: PHAsset

    @Published var originalImage: UIImage?
    @Published var displayImage: UIImage?
    @Published var regions: [BlurRegion] = []
    @Published var selectedRegionIds: Set<UUID> = []
    @Published var blurredRegionIds: Set<UUID> = []
    @Published var isDetectingFaces = false
    @Published var blurIntensity: CGFloat = 0.75

    private var undoStack: [(image: UIImage, regions: [BlurRegion], blurredIds: Set<UUID>)] = []

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var allRegionsSelected: Bool {
        let unblurredRegions = regions.filter { !blurredRegionIds.contains($0.id) }
        return !unblurredRegions.isEmpty && selectedRegionIds.count == unblurredRegions.count
    }

    init(asset: PHAsset) {
        self.asset = asset
    }

    func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            Task { @MainActor in
                guard let self = self, let image = image else { return }
                self.originalImage = image
                self.displayImage = image
                self.detectFaces(in: image)
            }
        }
    }

    func detectFaces(in image: UIImage) {
        isDetectingFaces = true

        Task {
            let detectedFaces = await FaceDetector.detectFaces(in: image)
            await MainActor.run {
                self.regions = detectedFaces.map { BlurRegion.fromFace(bounds: $0.bounds) }
                self.isDetectingFaces = false
            }
        }
    }

    // MARK: - Selection

    func toggleRegionSelection(_ regionId: UUID) {
        if selectedRegionIds.contains(regionId) {
            selectedRegionIds.remove(regionId)
        } else {
            if !blurredRegionIds.contains(regionId) {
                selectedRegionIds.insert(regionId)
            }
        }
    }

    func selectAll() {
        for region in regions where !blurredRegionIds.contains(region.id) {
            selectedRegionIds.insert(region.id)
        }
    }

    func clearSelection() {
        selectedRegionIds.removeAll()
    }

    // MARK: - Custom Regions

    func addCustomRegion(at normalizedPoint: CGPoint) {
        let newRegion = BlurRegion.customRegion(at: normalizedPoint)
        regions.append(newRegion)
        selectedRegionIds.insert(newRegion.id)
    }

    func deleteRegion(_ regionId: UUID) {
        regions.removeAll { $0.id == regionId }
        selectedRegionIds.remove(regionId)
        blurredRegionIds.remove(regionId)
    }

    // MARK: - Transform

    func moveRegion(_ regionId: UUID, by delta: CGSize, in viewSize: CGSize) {
        guard let index = regions.firstIndex(where: { $0.id == regionId }) else { return }

        let normalizedDeltaX = delta.width / viewSize.width
        let normalizedDeltaY = -delta.height / viewSize.height  // Flip Y

        var newBounds = regions[index].bounds
        newBounds.origin.x += normalizedDeltaX
        newBounds.origin.y += normalizedDeltaY

        // Clamp to valid range
        newBounds.origin.x = max(0, min(newBounds.origin.x, 1 - newBounds.width))
        newBounds.origin.y = max(0, min(newBounds.origin.y, 1 - newBounds.height))

        regions[index] = regions[index].withBounds(newBounds)
    }

    func resizeRegion(
        _ regionId: UUID, by delta: CGSize, from handle: ResizeHandle, in viewSize: CGSize
    ) {
        guard let index = regions.firstIndex(where: { $0.id == regionId }) else { return }

        let normalizedDeltaX = delta.width / viewSize.width
        // In screen coordinates, Y increases downward, but in Vision coordinates Y increases upward
        // So dragging down (positive screen Y) should decrease Vision Y
        let normalizedDeltaY = delta.height / viewSize.height

        var newBounds = regions[index].bounds

        // The visual preview uses screen coordinates where:
        // - topLeft handle: dragging right increases x, dragging down increases y (screen)
        // - In Vision coords: origin.y is at bottom, so screen "top" = high Vision Y

        switch handle {
        case .topLeft:
            // Screen: origin moves, size shrinks from top-left
            // Vision: top-left in screen = origin.x, origin.y + height
            newBounds.origin.x += normalizedDeltaX
            newBounds.size.width -= normalizedDeltaX
            // Dragging down in screen = positive deltaY = shrinking from top = reducing height, increasing origin.y
            newBounds.size.height -= normalizedDeltaY
        case .topRight:
            // Width changes, height shrinks from top
            newBounds.size.width += normalizedDeltaX
            newBounds.size.height -= normalizedDeltaY
        case .bottomLeft:
            // Origin.x moves, width shrinks, height grows from bottom
            // In Vision: bottom = origin.y, so growing down = origin.y decreases
            newBounds.origin.x += normalizedDeltaX
            newBounds.origin.y -= normalizedDeltaY
            newBounds.size.width -= normalizedDeltaX
            newBounds.size.height += normalizedDeltaY
        case .bottomRight:
            // Just size changes from bottom-right
            newBounds.origin.y -= normalizedDeltaY
            newBounds.size.width += normalizedDeltaX
            newBounds.size.height += normalizedDeltaY
        case .top:
            // Height shrinks from top
            newBounds.size.height -= normalizedDeltaY
        case .bottom:
            // Height grows from bottom, origin.y moves down in Vision
            newBounds.origin.y -= normalizedDeltaY
            newBounds.size.height += normalizedDeltaY
        case .left:
            newBounds.origin.x += normalizedDeltaX
            newBounds.size.width -= normalizedDeltaX
        case .right:
            newBounds.size.width += normalizedDeltaX
        }

        // Ensure minimum size
        let minSize: CGFloat = 0.03
        newBounds.size.width = max(newBounds.size.width, minSize)
        newBounds.size.height = max(newBounds.size.height, minSize)

        // Clamp origin
        newBounds.origin.x = max(0, min(newBounds.origin.x, 1 - newBounds.width))
        newBounds.origin.y = max(0, min(newBounds.origin.y, 1 - newBounds.height))

        regions[index] = regions[index].withBounds(newBounds)
    }

    func rotateRegion(_ regionId: UUID, by angle: CGFloat) {
        guard let index = regions.firstIndex(where: { $0.id == regionId }) else { return }
        let newRotation = regions[index].rotation + angle
        regions[index] = regions[index].withRotation(newRotation)
    }

    // MARK: - Blur

    func blurSelectedRegions() {
        guard let currentImage = displayImage, !selectedRegionIds.isEmpty else { return }

        // Save state for undo
        undoStack.append((image: currentImage, regions: regions, blurredIds: blurredRegionIds))

        // Get the regions to blur
        let regionsToBlur = regions.filter { selectedRegionIds.contains($0.id) }
        let blurData = regionsToBlur.map {
            BlurRegionData(bounds: $0.bounds, rotation: $0.rotation)
        }

        // Apply blur
        if let blurredImage = ImageBlurrer.applySecureBlur(
            to: currentImage,
            regions: blurData,
            intensity: blurIntensity
        ) {
            displayImage = blurredImage
            blurredRegionIds.formUnion(selectedRegionIds)
            selectedRegionIds.removeAll()
        }
    }

    func undo() {
        guard let lastState = undoStack.popLast() else { return }
        displayImage = lastState.image
        regions = lastState.regions
        blurredRegionIds = lastState.blurredIds
        selectedRegionIds.removeAll()
    }
}
