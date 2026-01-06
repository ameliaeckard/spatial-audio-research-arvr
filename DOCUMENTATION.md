# Spatial Audio Research AR/VR - Technical Documentation

## Overview

This visionOS application provides spatial audio feedback for visually impaired users by detecting reference objects in the environment and playing distance-based audio beeps from their location. The system uses ARKit for object tracking and RealityKit's native spatial audio capabilities to create an immersive 3D audio experience.

## System Architecture

### Core Components

#### 1. AppModel (`Models/AppModel.swift`)
The central state management class that coordinates all application functionality.

**Key Responsibilities:**
- Manages ARKit session lifecycle
- Coordinates object tracking and visualization
- Maintains application state (immersive space, tracking status)
- Handles world sensing authorization

**Important Properties:**
- `immersiveSpaceState`: Tracks whether app is in menu or immersive mode
- `trackedObjects`: Array of currently detected objects with position/distance data
- `currentVisualization`: The active 3D visualization entity
- `objectTrackingProvider`: ARKit provider for reference object detection
- `worldTrackingProvider`: ARKit provider for device position tracking

**Key Methods:**
- `startObjectTracking()`: Initializes ARKit session and starts tracking
- `processObjectUpdates()`: Monitors ARKit anchor events (added/updated/removed)
- `updateTrackedObjectsList()`: Updates object data with current positions and distances
- `stopObjectTracking()`: Cleans up tracking session and resources

#### 2. ObjectAnchorVisualization (`Models/AppModel.swift`)
Creates and manages the 3D visual and audio representation of detected objects.

**Key Responsibilities:**
- Creates cyan 3D box visualization at object location
- Manages spatial audio playback attached to the entity
- Generates and caches beep audio resources
- Handles cleanup when object is removed

**Important Properties:**
- `entity`: RealityKit Entity representing the 3D object
- `detectedObjectId`: Stable UUID that persists across ARKit re-detections
- `audioPlaybackController`: Controls audio playback on the entity
- `cachedBeepResource`: Static cached audio resource (shared across all instances)

**Audio System:**
- Uses RealityKit's `SpatialAudioComponent` for native 3D audio
- Audio automatically follows entity as it moves
- Beeps play every 0.5 seconds using a Timer
- Audio resource generated once (800Hz tone, 0.15s duration) and cached globally

#### 3. DetectedObject (`Components/DetectedObject.swift`)
Data model representing a detected object with spatial information.

**Properties:**
- `id`: UUID for tracking (must be stable across updates)
- `label`: Object name from reference object
- `worldPosition`: 3D position in world space
- `distance`: Distance from user's head to object
- `confidence`: Detection confidence (always 1.0 for object tracking)
- `boundingBox`: Screen-space bounding box
- `direction`: Normalized direction vector from user to object

#### 4. ReferenceObjectLoader (`Components/ReferenceObjectLoader.swift`)
Loads .referenceobject files from the app bundle for ARKit object detection.

**Functionality:**
- Scans for .referenceobject files in app resources
- Loads them into ARKit-compatible ReferenceObject format
- Provides array of loaded objects to ObjectTrackingProvider

#### 5. SpatialAudioManager (`Components/SpatialAudioManager.swift`)
**Status: Deprecated** - Originally used for manual audio management with AVAudioEngine. Replaced by entity-based audio system but retained in codebase for reference.

## Application Flow

### 1. App Launch
1. `SpatialAudioApp` initializes with main menu window
2. `AppModel` requests world sensing authorization
3. User sees main menu with "Live Detection" option

### 2. Starting Live Detection
1. User clicks "Live Detection" button
2. Main menu hides (content set to `Color.clear`)
3. Immersive space opens with live detection scene
4. Control panel window opens for object selection
5. `startObjectTracking()` called:
   - Reference objects loaded from bundle
   - ARKit session started with ObjectTrackingProvider and WorldTrackingProvider
   - Two async tasks launched:
     - `processObjectUpdates()`: Monitors object anchor events
     - `updateListenerPositionLoop()`: Updates head position every 50ms

### 3. Object Detection
When ARKit detects a reference object:

**`.added` event:**
1. Check if visualization already exists
2. If exists: Update existing visualization (preserves UUID)
3. If new: Create `ObjectAnchorVisualization` with new UUID
4. Add entity to scene
5. Start spatial audio on entity
6. Update tracked objects list

**`.updated` event:**
1. Update entity transform to match anchor
2. Recalculate distance from head position
3. Update tracked objects list

**`.removed` event:**
1. Remove entity from scene
2. Clear visualization reference
3. Audio stops automatically (deinit cleanup)
4. Clear tracked objects list

### 4. Spatial Audio System

**Audio Generation:**
```
generateBeepFile() -> Creates 800Hz sine wave tone
                   -> 0.15 second duration
                   -> Mono channel for best spatial audio
                   -> Saved to temp directory as spatial_beep.caf
                   -> Cached globally (generated only once)
```

**Audio Playback:**
```
Entity created -> SpatialAudioComponent added
              -> AudioFileResource loaded from cache
              -> Timer starts (0.5s intervals)
              -> entity.playAudio(resource) called every beep
              -> RealityKit handles 3D positioning automatically
```

**Why This Works:**
- Audio attached directly to RealityKit Entity
- RealityKit's SpatialAudioComponent uses system HRTF
- Audio position updates automatically as entity moves
- No manual position calculations needed

### 5. Distance Tracking
Every 50ms (in `updateListenerPositionLoop`):
1. Query device (head) position from WorldTrackingProvider
2. Calculate distance: `simd_distance(objectPosition, headPosition)`
3. Update `trackedObjects` array with current distance
4. Debug logging every 2 seconds (40 iterations)

### 6. Exiting Live Detection
1. User clicks "Exit Live Detection" button
2. Control panel closes
3. Immersive space dismisses
4. `stopObjectTracking()` called:
   - Visualization removed from scene
   - Audio cleanup via deinit
   - ARKit session stopped
5. Main menu reopens

## Key Technical Decisions

### UUID Stability
**Problem:** Originally, `DetectedObject` auto-generated UUID on each instantiation. Since `updateTrackedObjectsList()` creates new DetectedObject every frame, this caused new UUIDs every frame, leading to audio player recreation.

**Solution:**
- `ObjectAnchorVisualization` generates UUID once in init
- `DetectedObject.id` changed to parameter instead of auto-generated
- Same UUID passed to every DetectedObject update for same tracked object

### Visualization Update vs Recreation
**Problem:** ARKit fires `.added` event when re-detecting same object (e.g., after momentary tracking loss), causing visualization/audio recreation.

**Solution:**
- Check if visualization already exists before creating new one
- If exists, just update transform instead of recreating
- Preserves UUID and audio continuity

### Entity-Based Audio vs Manual AVAudioEngine
**Problem:** Manual AVAudioEngine approach was complex and audio didn't emanate from correct location.

**Solution:**
- Attach `SpatialAudioComponent` directly to RealityKit Entity
- RealityKit handles all spatial calculations
- Audio automatically follows entity movement
- Uses system's personalized HRTF for better quality

### Audio Resource Caching
**Problem:** Generating beep file on every visualization creation caused lag and file I/O overhead.

**Solution:**
- Static cached audio resource shared across all instances
- Generated once on first use
- Fixed filename for reuse across sessions
- Significant performance improvement

## File Structure

```
Spatial-Audio-Research-ARVR/
├── Models/
│   └── AppModel.swift              # Core state and logic
├── Views/
│   ├── MainMenuView.swift          # Entry menu
│   ├── LiveDetectionControlPanel.swift  # Control panel UI
│   ├── LiveDetectionImmersiveView.swift # AR scene
│   ├── BoundingBox.swift           # Bounding box visualization
│   ├── ErrorView.swift             # Error state UI
│   ├── ContentView.swift           # Legacy view
│   └── ResearchTestingView.swift  # Research mode UI
├── Components/
│   ├── DetectedObject.swift        # Object data model
│   ├── ReferenceObjectLoader.swift # Loads reference objects
│   ├── SpatialAudioManager.swift   # (Deprecated) Manual audio
│   ├── MenuCard.swift              # Menu button component
│   └── Extensions.swift            # Utility extensions
├── Reference Objects/
│   └── Box.referenceobject         # ARKit reference object file
└── Spatial_Audio_Research_ARVRApp.swift  # App entry point
```

## Dependencies

### System Frameworks
- **ARKit**: Object tracking, world tracking, anchor management
- **RealityKit**: 3D entity rendering, spatial audio
- **SwiftUI**: UI framework
- **AVFoundation**: Audio file generation and formats
- **QuartzCore**: High-precision timing (CACurrentMediaTime)
- **CoreGraphics**: Geometric calculations (CGRect)

### visionOS Features Required
- World Sensing authorization (camera access)
- ObjectTrackingProvider support
- WorldTrackingProvider support
- SpatialAudioComponent support

## Performance Considerations

### Optimizations Implemented
1. **Audio Resource Caching**: Single beep file generated and reused
2. **Reduced Logging**: Minimal console output to avoid overhead
3. **Stable UUIDs**: Prevents recreation of audio resources
4. **Entity Transform Updates**: Direct transform updates instead of recreation
5. **50ms Update Loop**: Balance between responsiveness and CPU usage

### Performance Characteristics
- Audio beeps: Every 0.5 seconds
- Position updates: Every 50ms
- Debug logging: Every 2 seconds (40 iterations)
- Audio latency: Minimal (RealityKit handles playback)
- Object detection: Real-time (ARKit-dependent)

## Debugging

### Key Debug Messages
- "Starting to monitor for object anchor updates..." - Anchor monitoring started
- "Object detected: [name]" - ARKit detected reference object
- "Updating existing visualization instead of recreating" - Prevented recreation
- "Generating beep audio (one-time)..." - First-time audio generation
- "Beep loop started" - Audio playback initiated
- "Listener (head) position: (x, y, z)" - Position tracking active

### Common Issues

**Audio not playing:**
- Check "Audio cached" message appears
- Verify SpatialAudioComponent was added
- Check for "ERROR: Audio setup failed" messages

**Object not detecting:**
- Ensure reference object file is in bundle
- Check lighting conditions (ARKit needs good lighting)
- Verify physical object matches scanned reference object
- Check world sensing authorization granted

**Audio from wrong location:**
- Should be from entity, not menu
- Verify entity-based audio system is active
- Check that SpatialAudioManager is disabled

## Future Enhancements

### Potential Improvements
1. **Distance-based pitch variation**: Adjust audio frequency based on proximity
2. **Multiple object support**: Track and provide audio for multiple objects simultaneously
3. **Directional audio beams**: Focus audio in specific directions
4. **Haptic feedback integration**: Vibration patterns for distance feedback
5. **Voice guidance**: Spoken directions to objects
6. **Custom audio profiles**: User-selectable beep sounds

### Scalability Considerations
- Current system optimized for single object tracking
- Multiple objects would require audio mixing strategy
- Consider audio priority system for multiple sources
- May need spatial audio pooling for many objects

## Credits

**Developer:** Amelia Eckard
**Institution:** University of North Carolina at Charlotte
**Project:** Vision Pro Research Study
**Platform:** visionOS (Apple Vision Pro)
**Updated:** January 2026

## License

Research project for educational purposes.
