//
//  ReferenceObjectLoader.swift
//  Spatial-Audio-Research-ARVR
//  Created by Amelia Eckard on 11/13/25.
//
//  Loads .referenceobject files from the app bundle
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
        
        // Load specific reference object: Box.referenceobject
        let filename = "Box.referenceobject"
        let fullPath = (resourcePath as NSString).appendingPathComponent(filename)
        let url = URL(fileURLWithPath: fullPath)
        
        do {
            // ReferenceObject(from:) is async
            let referenceObject = try await ReferenceObject(from: url)
            referenceObjects.append(referenceObject)
            print("Loaded reference object: \(filename)")
            
        } catch {
            print("Error loading Box.referenceobject: \(error)")
            print("Make sure Box.referenceobject is added to your Xcode project")
        }
    }
}
