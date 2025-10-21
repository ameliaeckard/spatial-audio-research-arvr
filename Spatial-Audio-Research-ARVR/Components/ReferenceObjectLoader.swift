//
//  ReferenceObjectLoader.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//

import ARKit
import RealityKit

@MainActor
@Observable
class ReferenceObjectLoader {
    private(set) var referenceObjects = [ReferenceObject]()
    private(set) var usdzsPerReferenceObjectID = [UUID: Entity]()
    
    func loadReferenceObjects() async {
        var referenceObjectFiles: [String] = []
        
        if let resourcesPath: String = Bundle.main.resourcePath {
            do {
                try referenceObjectFiles = FileManager.default.contentsOfDirectory(atPath: resourcesPath).filter { $0.hasSuffix(".referenceobject") }
            } catch {
                print("Failed to load reference object files with error: \(error)")
                return
            }
        }
        
        guard !referenceObjectFiles.isEmpty else {
            print("Warning: No .referenceobject files found in bundle")
            return
        }
        
        await withTaskGroup(of: Void.self) { [weak self] group in
            guard let self else { return }
            
            for file in referenceObjectFiles {
                let objectURL: URL = Bundle.main.bundleURL.appending(path: file)
                
                group.addTask {
                    await self.loadReferenceObject(objectURL)
                }
            }
        }
        
        print("Loaded \(referenceObjects.count) reference objects")
    }
    
    private func loadReferenceObject(_ url: URL) async {
        var referenceObject: ReferenceObject
        
        do {
            try await referenceObject = ReferenceObject(from: url)
        } catch {
            print("Failed to load reference object at \(url) with error: \(error)")
            return
        }
        
        referenceObjects.append(referenceObject)
        
        guard let usdzPath: URL = referenceObject.usdzFile else {
            print("Unable to find referenceObject.usdzFile for \(url.lastPathComponent)")
            return
        }
            
        var entity: Entity?
        
        do {
            try await entity = Entity(contentsOf: usdzPath)
        } catch {
            print("Failed to load referenceObject.usdzFile: \(error)")
            return
        }
        
        entity?.name = url.deletingPathExtension().lastPathComponent
        usdzsPerReferenceObjectID[referenceObject.id] = entity
        
        print("Loaded object: \(entity?.name ?? "unknown")")
    }
}