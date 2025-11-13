//
//  ReferenceObjectLoader.swift
//  Spatial-Audio-Research-ARVR
//  Created by Amelia Eckard on 11/6/25.
//
//  Loads .arobject files from the app bundle
//

import ARKit
import Foundation

class ReferenceObjectLoader {
    var referenceObjects: [ReferenceObject] = []
    
    init() {
        // Initialize empty, load asynchronously
    }
    
    func loadReferenceObjects() async {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Could not find bundle resource path")
            return
        }
        
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
            
            for filename in files where filename.hasSuffix(".arobject") {
                let fullPath = (resourcePath as NSString).appendingPathComponent(filename)
                let url = URL(fileURLWithPath: fullPath)
                
                // ReferenceObject(from:) is async
                if let referenceObject = try? await ReferenceObject(from: url) {
                    referenceObjects.append(referenceObject)
                    print("Loaded reference object: \(filename)")
                }
            }
            
            if referenceObjects.isEmpty {
                print("No .arobject files found")
            } else {
                print("Loaded \(referenceObjects.count) reference object(s)")
            }
            
        } catch {
            print("Error loading reference objects: \(error)")
        }
    }
}
