# Update Log

## Amelia Eckard (October 13, 2025)

### Major Changes

The application has been completely rebuilt from the ground up. The original iOS/ARKit implementation was replaced with a native visionOS architecture using proper MVVM patterns. The app now includes two distinct operational modes: Live Mode for real-world use and Research Testing Mode for controlled studies.

### New Features

**App Structure**

The app now has a main menu for selecting between modes, a participant ID tracking system, and navigation-based flow for improved user experience.

**Core Systems**

Five key systems power the application:
- `ObjectDetector.swift` handles Vision Pro object detection with ARKit integration
- `SpatialAudio.swift` manages 3D spatial audio using AVAudioEnvironmentNode
- `DetectedObject.swift` provides enhanced models with spatial calculations including azimuth, elevation, and direction descriptions
- `TestScenario.swift` contains the complete testing framework with predefined scenarios
- `DataManager.swift` manages research data collection and export

**Live Mode**

Live Mode provides real-time object detection with visual cards showing distance and direction. It includes spatial audio feedback with distance-based attenuation and object-specific audio frequencies. Users can toggle audio on/off, adjust volume, and receive voice announcements.

**Research Testing Mode**

This mode includes participant ID management and four predefined test scenarios:
1. Simple Table Scene - identify all objects
2. Find the Door - locate a specific object
3. Count the Chairs - object counting task
4. Nearest Object - find the closest object of a given type

### Bug Fixes

- Fixed spatial audio positioning bug where environmentNode.position was being overwritten for each object
- Removed continuous looping tones that created audio cacophony
- Implemented proper audio cleanup and resource management
- Fixed memory leaks in audio player creation

### Removed

- iOS/UIKit implementation
- ARViewContainer (replaced with RealityView)
- Mock plane detection system
- Incorrect spatial audio architecture

### Known Limitations

- Object detection currently uses simulation mode and requires a trained Core ML model
- File export prints to console and needs proper file system integration
- Requires Vision Pro hardware for full functionality
- Audio cues need real-world testing and refinement
