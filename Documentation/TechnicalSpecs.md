# Technical Specifications

## System Architecture

### Overview
The application uses a modular architecture separating concerns across managers, views, and models following MVVM patterns adapted for SwiftUI and visionOS. The system is divided into two primary modes: Live Detection for real-world use and Research Testing for controlled data collection.

### Architecture Diagram
```
┌─────────────────────────────────────────┐
│         SpatialAudioApp.swift           │
│         (App Entry Point)               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│        MainMenuView.swift                │
│     (Mode Selection Interface)           │
└──────┬───────────────────────┬───────────┘
       │                       │
       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐
│ LiveDetectionView│   │   TestingView    │
│   (Real-time)    │   │   (Research)     │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         └──────────┬───────────┘
                    │
         ┌──────────┴──────────┐
         │    Core Systems     │
         │  ┌───────────────┐  │
         │  │ObjectDetector │  │
         │  │ SpatialAudio  │  │
         │  │ DataManager   │  │
         │  └───────────────┘  │
         └─────────────────────┘
```

## Core Components

### 1. Object Detection System

**ObjectDetector.swift**

**Responsibilities:**
- Real-time object detection using Vision Pro's ARKit and scene understanding
- Object classification and confidence scoring
- 3D position estimation in world space
- Distance and direction calculations
- Frame processing and throttling

**Technologies:**
- ARKit WorldTrackingProvider (visionOS)
- Vision framework for ML-based object detection
- Core ML for custom trained models
- RealityKit for spatial anchoring

**Key Methods:**
```swift
// Initialize and setup detection system
init()
private func setupObjectDetection()

// Process AR frames from Vision Pro
func processARFrame(_ frame: ARFrame, with worldTracking: simd_float4x4)

// Vision framework integration
private func detectObjects(in pixelBuffer: CVPixelBuffer, cameraTransform: simd_float4x4)
private func processDetections(request: VNRequest, error: Error?)

// 3D position estimation from 2D bounding box
private func estimate3DPosition(from boundingBox: CGRect) -> SIMD3<Float>

// Testing utilities
func setMockObjects(_ objects: [DetectedObject])
func findNearest(objectType: String) -> DetectedObject?
func countObjects(ofType type: String) -> Int
```

**Properties:**
```swift
@Published var detectedObjects: [DetectedObject]
@Published var isProcessing: Bool
private var objectDetectionRequest: VNCoreMLRequest?
private let processInterval: TimeInterval = 0.5
private let supportedObjects: [String]
```
