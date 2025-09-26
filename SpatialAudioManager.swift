//
//  SpatialAudioManager.swift
//  SpatialSight - Apple Vision Pro Research App
//

import Foundation
import RealityKit
import AVFoundation
import Combine
import SwiftUI

@MainActor
class SpatialAudioManager: ObservableObject {
    @Published var isAudioEnabled = true
    @Published var masterVolume: Float = 0.75
    @Published var spatialAudioEnabled = true
    @Published var voiceDescriptionsEnabled = true
    @Published var speechRate: Float = 1.2
    @Published var audioRange: Float = 5.0 // meters
    @Published var selectedToneType: AudioToneType = .pureTone
    
    private var audioEntities: [UUID: Entity] = [:]
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()
    private let realityViewContent = RealityViewContent()
    
    enum AudioToneType: String, CaseIterable {
        case pureTone = "Pure Tone"
        case musicalNote = "Musical Note"
        case natureSound = "Nature Sound"
        case beep = "Beep"
    }
    
    private let objectAudioSettings: [ObjectType: AudioSettings] = [
        .chair: AudioSettings(frequency: 440.0, volume: 0.8, rolloffFactor: 1.0),
        .table: AudioSettings(frequency: 330.0, volume: 0.7, rolloffFactor: 1.2),
        .door: AudioSettings(frequency: 220.0, volume: 1.0, rolloffFactor: 0.8),
        .stairs: AudioSettings(frequency: 150.0, volume: 1.0, rolloffFactor: 0.5), // Safety - slower rolloff
        .sofa: AudioSettings(frequency: 460.0, volume: 0.6, rolloffFactor: 1.5),
        .desk: AudioSettings(frequency: 350.0, volume: 0.7, rolloffFactor: 1.0),
        .window: AudioSettings(frequency: 523.0, volume: 0.5, rolloffFactor: 2.0),
        .plant: AudioSettings(frequency: 400.0, volume: 0.4, rolloffFactor: 1.8)
    ]
    
    init() {
        setupAudioSystem()
        observeObjectDetections()
    }
    
    // MARK: - Audio System Setup
    private func setupAudioSystem() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .spokenAudio,
                                       options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        speechSynthesizer.delegate = self
    }
    
    private func observeObjectDetections() {
        NotificationCenter.default.publisher(for: .objectDetected)
            .compactMap { $0.object as? DetectedObject }
            .sink { [weak self] detectedObject in
                Task { @MainActor in
                    await self?.createSpatialAudio(for: detectedObject)
                    if self?.voiceDescriptionsEnabled == true {
                        self?.provideVoiceDescription(for: detectedObject)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Spatial Audio Creation
    func createSpatialAudio(for object: DetectedObject) async {
        guard isAudioEnabled && spatialAudioEnabled else { return }
        
        if let existingEntity = audioEntities[object.id] {
            realityViewContent.remove(existingEntity)
        }
        
        let audioEntity = await createAudioEntity(for: object)
        audioEntities[object.id] = audioEntity
        realityViewContent.add(audioEntity)
        
        updateAudioPosition(for: object)
    }
    
    private func createAudioEntity(for object: DetectedObject) async -> Entity {
        let audioEntity = Entity()
        
        let settings = objectAudioSettings[object.type] ?? 
                      AudioSettings(frequency: 350.0, volume: 0.7, rolloffFactor: 1.0)
        
        var spatialAudioComponent = SpatialAudioComponent()
        spatialAudioComponent.gain = settings.volume * masterVolume
        spatialAudioComponent.distanceAttenuation = .rolloff(factor: settings.rolloffFactor)
        spatialAudioComponent.directivity = .cone(innerAngle: .pi / 4, outerAngle: .pi / 2, outerGain: 0.3)
        
        audioEntity.components[SpatialAudioComponent.self] = spatialAudioComponent
        
        do {
            let audioResource = try await loadAudioResource(for: object, settings: settings)
            audioEntity.playAudio(audioResource)
        } catch {
            print("Failed to load audio resource for \(object.type): \(error)")
        }
        
        return audioEntity
    }
    
    private func loadAudioResource(for object: DetectedObject, settings: AudioSettings) async throws -> AudioFileResource {
        let configuration = AudioFileResource.Configuration(shouldLoop: true)
        
        switch selectedToneType {
        case .pureTone:
            return try await generatePureTone(frequency: settings.frequency, configuration: configuration)
        case .musicalNote:
            return try await loadMusicalNote(frequency: settings.frequency, configuration: configuration)
        case .natureSound:
            let soundName = mapObjectToNatureSound(object.type)
            return try AudioFileResource.load(named: soundName, configuration: configuration)
        case .beep:
            let beepPattern = mapObjectToBeepPattern(object.type)
            return try AudioFileResource.load(named: beepPattern, configuration: configuration)
        }
    }
    
    // MARK: - Audio Generation
    private func generatePureTone(frequency: Float, configuration: AudioFileResource.Configuration) async throws -> AudioFileResource {
        return try AudioFileResource.load(named: "pure_tone_\(Int(frequency))", configuration: configuration)
    }
    
    private func loadMusicalNote(frequency: Float, configuration: AudioFileResource.Configuration) async throws -> AudioFileResource {
        let noteName = frequencyToNoteName(frequency)
        return try AudioFileResource.load(named: "note_\(noteName)", configuration: configuration)
    }
    
    private func mapObjectToNatureSound(_ objectType: ObjectType) -> String {
        switch objectType {
        case .plant: return "leaves_rustle"
        case .window: return "wind_gentle"
        case .door: return "wood_creak"
        case .chair, .sofa: return "fabric_soft"
        case .table, .desk: return "wood_tap"
        case .stairs: return "footsteps"
        default: return "ambient_room"
        }
    }
    
    private func mapObjectToBeepPattern(_ objectType: ObjectType) -> String {
        switch objectType {
        case .stairs: return "beep_urgent" // Safety priority
        case .door: return "beep_double"
        case .chair, .sofa: return "beep_soft"
        case .table, .desk: return "beep_medium"
        default: return "beep_single"
        }
    }
    
    private func frequencyToNoteName(_ frequency: Float) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency: Float = 440.0
        let semitone = pow(2.0, 1.0/12.0)
        
        let semitonesFromA4 = round(log(frequency / a4Frequency) / log(semitone))
        let noteIndex = Int((semitonesFromA4.truncatingRemainder(dividingBy: 12) + 12).truncatingRemainder(dividingBy: 12))
        let octave = Int(4 + floor(semitonesFromA4 / 12))
        
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    // MARK: - Audio Position Updates
    func updateAudioPosition(for object: DetectedObject) {
        guard let audioEntity = audioEntities[object.id] else { return }
        
        let transform = Transform(
            scale: SIMD3<Float>(1, 1, 1),
            rotation: object.orientation,
            translation: object.position
        )
        
        audioEntity.transform = transform
    }
    
    func removeAudioEntity(for objectId: UUID) {
        guard let audioEntity = audioEntities[objectId] else { return }
        
        audioEntity.stopAllAudio()
        
        realityViewContent.remove(audioEntity)
        audioEntities.removeValue(forKey: objectId)
    }
    
    // MARK: - Voice Descriptions
    func provideVoiceDescription(for object: DetectedObject) {
        guard voiceDescriptionsEnabled else { return }
        
        let distance = object.distanceFromUser
        let direction = calculateDirection(for: object.position)
        
        let description = generateVoiceDescription(
            objectType: object.type,
            distance: distance,
            direction: direction,
            confidence: object.confidence
        )
        
        speakText(description)
    }
    
    private func generateVoiceDescription(objectType: ObjectType, distance: Float, direction: Float, confidence: Float) -> String {
        let confidenceText = confidence > 0.9 ? "" : confidence > 0.7 ? " possibly" : " uncertain"
        let distanceText = formatDistance(distance)
        let directionText = formatDirection(direction)
        
        return "\(objectType.displayName)\(confidenceText) detected, \(distanceText), \(directionText)"
    }
    
    private func formatDistance(_ distance: Float) -> String {
        if distance < 0.5 {
            return "very close"
        } else if distance < 1.0 {
            return "close by"
        } else if distance < 2.0 {
            return "about \(Int(distance)) meter away"
        } else {
            return "about \(Int(distance)) meters away"
        }
    }
    
    private func formatDirection(_ direction: Float) -> String {
        let degrees = abs(direction)
        if degrees < 15 {
            return "straight ahead"
        } else if degrees < 45 {
            return direction > 0 ? "slightly to your right" : "slightly to your left"
        } else if degrees < 90 {
            return direction > 0 ? "to your right" : "to your left"
        } else {
            return direction > 0 ? "behind you to the right" : "behind you to the left"
        }
    }
    
    private func calculateDirection(for position: SIMD3<Float>) -> Float {
        return atan2(position.x, -position.z) * 180 / .pi
    }
    
    func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate * 0.5 // Convert to AVSpeech rate range
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Audio Settings
    func updateMasterVolume(_ volume: Float) {
        masterVolume = volume
        
        for (_, audioEntity) in audioEntities {
            if var spatialAudio = audioEntity.components[SpatialAudioComponent.self] {
                spatialAudio.gain = volume
                audioEntity.components[SpatialAudioComponent.self] = spatialAudio
            }
        }
    }
    
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()
        
        if !spatialAudioEnabled {
            for (objectId, _) in audioEntities {
                removeAudioEntity(for: objectId)
            }
        }
    }
    
    func setToneType(_ toneType: AudioToneType) {
        selectedToneType = toneType
        
        Task {
            let currentObjects = Array(audioEntities.keys)
            for objectId in currentObjects {
                removeAudioEntity(for: objectId)
            }
            
        }
    }
}

// MARK: - Audio Settings Structure
struct AudioSettings {
    let frequency: Float
    let volume: Float
    let rolloffFactor: Float
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpatialAudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    }
}
