import Foundation

@MainActor
class DataManager: ObservableObject {
    @Published var testResults: [TestResult] = []
    @Published var currentParticipantId: String = ""
    
    private let resultsKey = "test_results"
    private let participantKey = "current_participant"
    
    init() {
        loadResults()
        loadParticipantId()
    }
    
    func saveTestResult(_ result: TestResult) {
        testResults.append(result)
        saveResults()
    }
    
    func clearAllResults() {
        testResults.removeAll()
        saveResults()
    }
    
    func getResults(for scenarioId: UUID) -> [TestResult] {
        testResults.filter { $0.scenarioId == scenarioId }
    }
    
    func getResults(for participantId: String) -> [TestResult] {
        testResults.filter { $0.participantId == participantId }
    }
    
    func averageAccuracy(for scenarioId: UUID? = nil) -> Float {
        let relevant = scenarioId != nil ? getResults(for: scenarioId!) : testResults
        guard !relevant.isEmpty else { return 0 }
        
        let sum = relevant.reduce(0) { $0 + $1.accuracy }
        return sum / Float(relevant.count)
    }
    
    func averageResponseTime(for scenarioId: UUID? = nil) -> TimeInterval {
        let relevant = scenarioId != nil ? getResults(for: scenarioId!) : testResults
        guard !relevant.isEmpty else { return 0 }
        
        let sum = relevant.reduce(0) { $0 + $1.responseTime }
        return sum / Double(relevant.count)
    }
    
    func totalTests() -> Int {
        testResults.count
    }
    
    func uniqueParticipants() -> Int {
        Set(testResults.map { $0.participantId }).count
    }
    
    func setParticipantId(_ id: String) {
        currentParticipantId = id
        UserDefaults.standard.set(id, forKey: participantKey)
    }
    
    func exportToCSV() -> String {
        var csv = "Scenario ID,Participant ID,Start Time,End Time,Response Time (s),Accuracy (%),Correct,Total,User Response,Notes\n"
        
        for result in testResults {
            let dateFormatter = ISO8601DateFormatter()
            csv += "\(result.scenarioId),"
            csv += "\(result.participantId),"
            csv += "\(dateFormatter.string(from: result.startTime)),"
            csv += "\(dateFormatter.string(from: result.endTime)),"
            csv += "\(String(format: "%.2f", result.responseTime)),"
            csv += "\(result.accuracyPercentage),"
            csv += "\(result.correctIdentifications),"
            csv += "\(result.totalObjects),"
            csv += "\"\(result.userResponse.replacingOccurrences(of: "\"", with: "\"\""))\","
            csv += "\"\(result.notes.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
        }
        
        return csv
    }
    
    func exportToJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try? encoder.encode(testResults)
    }
    private func saveResults() {
        if let encoded = try? JSONEncoder().encode(testResults) {
            UserDefaults.standard.set(encoded, forKey: resultsKey)
        }
    }
    
    private func loadResults() {
        if let data = UserDefaults.standard.data(forKey: resultsKey),
           let decoded = try? JSONDecoder().decode([TestResult].self, from: data) {
            testResults = decoded
        }
    }
    
    private func loadParticipantId() {
        if let id = UserDefaults.standard.string(forKey: participantKey) {
            currentParticipantId = id
        }
    }
}