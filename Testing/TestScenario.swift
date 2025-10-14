import Foundation
import simd

struct TestScenario: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let objects: [DetectedObject]
    let task: TestTask
    let expectedDuration: TimeInterval
    
    init(id: UUID = UUID(), name: String, description: String, objects: [DetectedObject], task: TestTask, expectedDuration: TimeInterval) {
        self.id = id
        self.name = name
        self.description = description
        self.objects = objects
        self.task = task
        self.expectedDuration = expectedDuration
    }
}

enum TestTask: Codable {
    case identifyObject(targetName: String)
    case locateNearest(objectType: String)
    case countObjects(objectType: String, expectedCount: Int)
    case navigateToObject(targetName: String)
    case identifyAllObjects
    
    var instruction: String {
        switch self {
        case .identifyObject(let target):
            return "Find and identify the \(target)"
        case .locateNearest(let type):
            return "Locate the nearest \(type)"
        case .countObjects(let type, let count):
            return "Count how many \(type)s are present (answer: \(count))"
        case .navigateToObject(let target):
            return "Navigate to the \(target)"
        case .identifyAllObjects:
            return "Identify all objects in the scene"
        }
    }
}

struct TestResult: Identifiable, Codable {
    let id: UUID
    let scenarioId: UUID
    let participantId: String
    let startTime: Date
    let endTime: Date
    let responseTime: TimeInterval
    let accuracy: Float
    let correctIdentifications: Int
    let totalObjects: Int
    let userResponse: String
    let notes: String
    
    init(id: UUID = UUID(), scenarioId: UUID, participantId: String, startTime: Date, endTime: Date, correctIdentifications: Int, totalObjects: Int, userResponse: String, notes: String = "") {
        self.id = id
        self.scenarioId = scenarioId
        self.participantId = participantId
        self.startTime = startTime
        self.endTime = endTime
        self.responseTime = endTime.timeIntervalSince(startTime)
        self.accuracy = totalObjects > 0 ? Float(correctIdentifications) / Float(totalObjects) : 0
        self.correctIdentifications = correctIdentifications
        self.totalObjects = totalObjects
        self.userResponse = userResponse
        self.notes = notes
    }
    
    var accuracyPercentage: Int {
        Int(accuracy * 100)
    }
}

// MARK: - Predefined Test Scenarios
extension TestScenario {
    static let basicScenarios: [TestScenario] = [
        TestScenario(
            name: "Simple Table Scene",
            description: "Identify objects on a table",
            objects: [
                DetectedObject(name: "cup", position: SIMD3<Float>(0.3, 0.8, -1.0), confidence: 0.95),
                DetectedObject(name: "laptop", position: SIMD3<Float>(-0.2, 0.8, -1.0), confidence: 0.92),
                DetectedObject(name: "bottle", position: SIMD3<Float>(0.0, 0.8, -0.8), confidence: 0.88)
            ],
            task: .identifyAllObjects,
            expectedDuration: 30
        ),
        
        TestScenario(
            name: "Find the Door",
            description: "Locate the door in the room",
            objects: [
                DetectedObject(name: "door", position: SIMD3<Float>(2.0, 1.0, -3.0), confidence: 0.90),
                DetectedObject(name: "chair", position: SIMD3<Float>(-1.0, 0.5, -2.0), confidence: 0.85),
                DetectedObject(name: "table", position: SIMD3<Float>(0.5, 0.7, -2.5), confidence: 0.93)
            ],
            task: .identifyObject(targetName: "door"),
            expectedDuration: 20
        ),
        
        TestScenario(
            name: "Count the Chairs",
            description: "Count all chairs in the scene",
            objects: [
                DetectedObject(name: "chair", position: SIMD3<Float>(-1.5, 0.5, -2.0), confidence: 0.89),
                DetectedObject(name: "chair", position: SIMD3<Float>(-0.5, 0.5, -2.0), confidence: 0.91),
                DetectedObject(name: "chair", position: SIMD3<Float>(0.5, 0.5, -2.0), confidence: 0.87),
                DetectedObject(name: "table", position: SIMD3<Float>(0.0, 0.7, -2.5), confidence: 0.94)
            ],
            task: .countObjects(objectType: "chair", expectedCount: 3),
            expectedDuration: 25
        ),
        
        TestScenario(
            name: "Nearest Object",
            description: "Find the nearest cup",
            objects: [
                DetectedObject(name: "cup", position: SIMD3<Float>(0.4, 0.8, -0.8), confidence: 0.93),
                DetectedObject(name: "cup", position: SIMD3<Float>(-1.0, 0.8, -2.0), confidence: 0.90),
                DetectedObject(name: "bottle", position: SIMD3<Float>(0.2, 0.8, -1.2), confidence: 0.88)
            ],
            task: .locateNearest(objectType: "cup"),
            expectedDuration: 15
        )
    ]
}