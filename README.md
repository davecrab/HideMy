# HideMy

A privacy-focused iOS app that helps you blur faces in photos before sharing them online. Perfect for protecting children's privacy or anonymizing photos for social media.

## Features

### Core Features
- **Photo Library Access**: Browse and select photos from your Apple Photos library
- **Automatic Face Detection**: Uses Apple's Vision framework to detect faces in photos
- **Selective Blurring**: Tap to select which faces you want to blur
- **Secure Blur**: Uses heavy pixelation combined with blur that cannot be reversed or reconstructed

### New Features

#### 🔍 Zoom & Pan
- **Pinch to zoom**: Zoom in up to 5x for precise editing
- **Drag to pan**: Move around the image when zoomed in
- **Reset button**: Quickly return to the default view
- **Zoom indicator**: Shows current zoom percentage

#### 📦 Custom Blur Regions
- **Two editing modes**: Switch between "Faces" and "Custom" modes
- **Long press to add**: In Custom mode, long press anywhere to add a blur region
- **Resize handles**: Drag corner handles to resize custom regions
- **Rotation support**: Use the rotation handle to rotate regions at any angle
- **Move regions**: Drag custom regions to reposition them
- **Delete regions**: Long press on a region to delete it
- **Perfect for**: License plates, name tags, street signs, documents, etc.

#### 🎚️ Adjustable Blur Intensity
- **Slider control**: Adjust blur intensity from 25% to 100%
- **Real-time preview**: See the intensity setting before applying
- **Light to Maximum**: Choose the right level for your needs
  - **Light (25%)**: Subtle blur, smaller pixel blocks
  - **Medium (50%)**: Balanced blur
  - **Strong (75%)**: Heavy pixelation (default)
  - **Maximum (100%)**: Largest pixel blocks, maximum privacy

### Toolbar Controls
- **Undo**: Revert the last blur operation
- **Select All**: Select all detected faces/regions
- **Clear**: Clear current selection
- **Reset**: Reset zoom and pan to default view
- **Blur**: Apply blur to selected regions

### Save Options
- Save as a copy to Apple Photos
- Save to Files app (via share sheet)

### Photo Management
- **Photo Tracking**: Keep track of all blurred photos you've created
- **Bulk Cleanup**: Delete all blurred photos from Apple Photos at once from Settings
- **View History**: See thumbnails of all your blurred photos

## Requirements

- iOS 17.0+
- Xcode 15.0+
- iPhone or iPad

## Installation

1. Open `HideMy.xcodeproj` in Xcode
2. Select your development team in the Signing & Capabilities section
3. Build and run on your device or simulator

## Usage

### Blurring Faces (Automatic Detection)

1. Launch the app and grant photo library access when prompted
2. Browse your photos in the Photos tab
3. Tap a photo to open the editor
4. The app will automatically detect faces and highlight them with yellow rectangles
5. Tap on faces you want to blur (they'll be highlighted in blue when selected)
6. Adjust the blur intensity slider if needed
7. Tap the **Blur** button to apply
8. Use **Undo** if you make a mistake
9. Tap **Save** and choose where to save

### Adding Custom Blur Regions

1. In the editor, tap the **Custom** mode in the top segmented control
2. **Long press** anywhere on the image to add a new blur region
3. The region will appear with an orange border and resize handles
4. **Resize**: Drag the corner handles to adjust size
5. **Move**: Drag the region to reposition it
6. **Rotate**: Use the green rotation handle at the top
7. **Delete**: Long press on the region and select "Delete"
8. Select the region and tap **Blur** to apply

### Zoom & Pan for Precise Editing

1. **Pinch with two fingers** to zoom in/out (0.5x to 5x)
2. **Drag with one finger** to pan when zoomed in (only works when zoomed)
3. Use the **Reset** button in the toolbar to return to default view
4. The zoom percentage is shown in the top-right corner

### Managing Blurred Photos

1. Go to the **Settings** tab
2. View the count of tracked blurred photos
3. Tap **View Blurred Photos** to see thumbnails of all blurred photos
4. Use **Delete All Blurred Photos from Photos** to permanently remove all blurred copies from your library
5. Use **Clear Tracking History** to reset the tracking without deleting photos

## Privacy & Security

This app takes privacy seriously:

- **Irreversible Blur**: The blur algorithm uses multiple passes of pixelation and Gaussian blur to completely destroy facial features. The original face data cannot be recovered or reconstructed.
- **Local Processing**: All face detection and blurring happens on-device. No photos are uploaded to any server.
- **No Data Collection**: The app only stores local identifiers of blurred photos for cleanup purposes.

### How the Secure Blur Works

1. **First Pixelation Pass**: Heavy pixelation destroys fine facial details
2. **Gaussian Blur**: Smooths edges and removes any remaining patterns
3. **Second Pixelation Pass**: Removes gradient information left by the blur
4. **Result**: Uniform colored blocks with no recoverable facial data

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **Vision Framework**: Face detection using `VNDetectFaceRectanglesRequest`
- **Core Image**: Image processing with `CIPixellate` and `CIGaussianBlur` filters
- **Photos Framework**: Photo library access and management
- **UserDefaults**: Persistence for blurred photo tracking

### Project Structure

```
HideMy/
├── HideMyApp.swift               # App entry point
├── Views/
│   ├── ContentView.swift         # Tab navigation
│   ├── PhotoGridView.swift       # Photo library grid
│   ├── PhotoEditView.swift       # Face selection, custom regions, zoom/pan
│   └── SettingsView.swift        # Settings and cleanup
├── Services/
│   ├── PhotoManager.swift        # Photo library operations
│   ├── PhotoLibraryManager.swift # Photo fetching
│   ├── FaceDetector.swift        # Vision-based face detection
│   ├── ImageBlurrer.swift        # Secure blur with intensity control
│   └── BlurredPhotosStore.swift  # Tracking persistence
├── Models/
│   └── BlurRegion.swift          # Blur region with transform support
└── Assets.xcassets/              # App icons and colors
```

### Key Classes

- **BlurRegion**: Represents a blur region with bounds, rotation, and type (face/custom)
- **ImageBlurrer**: Applies secure, irreversible blur with configurable intensity
- **PhotoEditViewModel**: Manages editor state, selection, and blur operations
- **RegionOverlayView**: Interactive overlay for selecting and transforming regions

## Gestures Reference

| Gesture | Action |
|---------|--------|
| Tap on region | Select/deselect region |
| Long press (Custom mode) | Add new blur region |
| Long press on region | Show delete option |
| Drag region | Move region (custom only) |
| Drag corner handle | Resize region (custom only) |
| Drag rotation handle | Rotate region (custom only) |
| Pinch | Zoom in/out |
| Drag (when zoomed) | Pan image |

## License

This project is provided as-is for educational and personal use.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.