# Spatial Audio Navigation _(spatial-audio-research-arvr)_

Lab report: [Spatial Audio Navigation](https://lab.ameliaeckard.com/notes/2025-08-01-spatial-audio-accessible-navigation)

An Apple Vision Pro research prototype using object tracking and spatial audio for accessible indoor navigation.

## Background

This UNC Charlotte research project explores whether on-device object tracking and directional audio can improve environmental awareness for blind and low-vision users. It was supervised by Dr. Todd Dobbs.

A sighted-researcher overlay exposes object position, distance, tracking state, and audio frequency while the user receives spatialized audio cues.

## Install

Requirements:

- Apple Vision Pro
- Xcode 16+
- visionOS 2+
- macOS 15+

```bash
git clone https://github.com/ameliaeckard/spatial-audio-research-arvr.git
cd spatial-audio-research-arvr
open Spatial-Audio-Research-ARVR.xcodeproj
```

Configure signing, select a Vision Pro device, and add any additional `.referenceobject` assets before building.

## Usage

Launch the app on Vision Pro and enter Live Detection mode. Tracked objects produce spatial audio at their world position, with pitch mapped to distance.

```text
closer object -> higher pitch
farther object -> lower pitch
direction      -> spatial audio position
```

## Research Context

The prototype uses ARKit `ObjectTrackingProvider` and `WorldTrackingProvider`, RealityKit, SwiftUI, and AVFoundation HRTF rendering. Evaluation work focused on object identification, tracking reliability, navigation performance, and audio-feedback usability.

Demo: [Spatial Audio Object Detection](https://www.youtube.com/watch?v=tMCRBuLIVYo)

## Maintainer

[Amelia Eckard](https://github.com/ameliaeckard)

## Contributing

Issues are welcome for bugs or documentation problems. Please open an issue before a substantial pull request.
