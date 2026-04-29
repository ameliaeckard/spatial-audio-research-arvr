# Spatial Audio Research: AR/VR Object Detection for Visual Accessibility

**Amelia Eckard** | University of North Carolina at Charlotte  
College of Computing and Informatics | Undergraduate Research

An Apple Vision Pro application that uses object tracking and spatial audio to enhance environmental awareness for visually impaired users. Objects are detected in real-time and represented through spatialized audio beeps that change in pitch and frequency based on distance—mimicking the Doppler effect for intuitive navigation.

---

## Demo Video

[![Spatial Audio Object Detection Demo](https://img.youtube.com/vi/tMCRBuLIVYo/maxresdefault.jpg)](https://www.youtube.com/watch?v=tMCRBuLIVYo)

*Click to watch the full demonstration*

---

## Overview

This research prototype explores how spatial audio can augment traditional assistive technologies for people with visual impairments. Using Apple Vision Pro's ARKit capabilities, the app:

- **Detects objects** in 3D space using custom reference objects
- **Tracks objects** continuously with real-time position updates
- **Generates spatial audio cues** where pitch increases as objects get closer (Doppler-style feedback)
- **Displays visual overlays** with wireframe bounding boxes and live metrics for sighted researchers

### Key Features

- **Object Tracking**: Uses ARKit's `ObjectTrackingProvider` with `.referenceobject` files
- **Spatial Audio**: AVFoundation-based HRTF spatialization with distance-based pitch modulation
- **Live Detection**: Live detection mode for active use

---

## Technology Stack

- **visionOS 2.0+** (Apple Vision Pro)
- **Swift 6.0**
- **ARKit**: ObjectTrackingProvider, WorldTrackingProvider
- **RealityKit**: Entity management, 3D visualization
- **AVFoundation**: Spatial audio engine (HRTFHQ rendering)
- **SwiftUI**: Declarative UI with state-driven transitions

---

## How It Works

### 1. Object Detection
The app loads a custom `.referenceobject` file (currently `Box.referenceobject`) created using Apple's object scanning tools. ARKit continuously tracks this object in 3D space.

### 2. Spatial Audio Feedback
When an object is detected:
- A **spatialized audio beep** plays from the object's world position
- **Pitch (frequency)** maps to distance:
  - **Close (0.3m)**: 1200 Hz (high pitch)
  - **Far (10m)**: 300 Hz (low pitch)
- **Beep interval**: Fixed 0.25s rate with 0.5s gaps
- Audio is rendered using **HRTF HQ** (Head-Related Transfer Function) for accurate spatial perception

### 3. Visual Overlay (For Research)
A green wireframe box appears around detected objects, with live metrics:
- Object label
- Distance in meters
- Current audio frequency

The wireframe automatically hides when tracking confidence drops, preventing visual clutter during momentary losses.

### 4. Adaptive Tracking
The app monitors ARKit's tracking state and responds dynamically:
- **Anchor added**: Creates visualization and starts audio
- **Anchor updated**: Updates position and recalculates audio parameters
- **Anchor not tracked**: Hides wireframe and silences audio
- **Anchor removed**: Cleans up all resources

---

## Setup & Installation

### Prerequisites

- **Apple Vision Pro** (physical device required—simulator has limited ARKit support)
- **Xcode 16.0+** with visionOS SDK
- **macOS 15.0+** (Sequoia or later)

### Building the Project

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/Spatial-Audio-Research-ARVR.git
   cd Spatial-Audio-Research-ARVR
   ```

2. **Open in Xcode**:
   ```bash
   open Spatial-Audio-Research-ARVR.xcodeproj
   ```

3. **Configure signing**:
   - Select the project in Xcode's navigator
   - Go to **Signing & Capabilities**
   - Choose your development team
   - Ensure **Automatically manage signing** is enabled

4. **Add reference objects**:
   - The project includes `Box.referenceobject` by default
   - To add custom objects, scan them using Apple's Reality Composer Pro or the ARKit sample app
   - Drag `.referenceobject` files into the project root
   - Update `ReferenceObjectLoader.swift` to load your custom objects

5. **Build and run**:
   - Select your **Vision Pro device** as the destination
   - Press **Cmd+R** or click the Run button
   - Grant camera and world sensing permissions when prompted

### Running on Device

1. **Connect your Vision Pro** via USB-C or wirelessly (after initial pairing)
2. **Enable Developer Mode** on Vision Pro:
   - Go to Settings > Privacy & Security > Developer Mode
   - Toggle on and restart
3. **Deploy from Xcode** as usual—the app will install and launch

---

## Usage

### Live Detection Mode

1. Launch the app on Vision Pro
2. Select **Live Detection** from the main menu
3. The app will:
   - Request world sensing permissions (first run only)
   - Load reference objects
   - Start the ARKit session
4. Point the Vision Pro at a scanned object (e.g., the box)
5. Listen for spatial audio beeps:
   - **High pitch**: Object is close
   - **Low pitch**: Object is far away
   - **Direction**: Audio comes from the object's actual position in space
6. Optional: View the wireframe overlay to see tracking metrics
7. Press **Exit Live Detection** to return to the menu

### Controls

- **Object Selection**: Tap object icons to filter what you're tracking (currently only Box is supported)
- **Detection Status**: Green checkmarks appear when selected objects are detected
- **Live Metrics**: Distance and frequency update in real-time above the wireframe

---

## Research Context

This project is part of undergraduate research at UNC Charlotte's College of Computing and Informatics, supervised by Dr. Todd Dobbs. The goal is to investigate whether spatial audio cues can provide effective environmental feedback for navigation assistance.

---

## Contributing

This is an active research project. If you have ideas or want to collaborate:
- Open an issue for bugs or feature requests
- Submit pull requests for improvements
- Reach out for research collaboration opportunities

---

## License

This project is developed for academic research purposes. Contact the author for usage permissions.

---

## Contact

**Amelia Eckard**  
Undergraduate Researcher, Computer Science
University of North Carolina at Charlotte  
[ameliaeckard.com](https://ameliaeckard.com) | [GitHub](https://github.com/aeckard)

**Supervisor**: Dr. Todd Dobbs, College of Computing and Informatics

---

*Last Updated: April 29, 2026*
