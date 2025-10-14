import SwiftUI

struct TestingView: View {
    @StateObject private var dataManager = DataManager()
    @StateObject private var objectDetector = ObjectDetector()
    @StateObject private var spatialAudio = SpatialAudio()
    
    @State private var selectedScenario: TestScenario?
    @State private var isTestActive = false
    @State private var testStartTime: Date?
    @State private var userResponse = ""
    @State private var showingResults = false
    @State private var participantId = ""
    @State private var showingParticipantPrompt = true
    
    var body: some View {
        ZStack {
            if showingParticipantPrompt {
                participantSetupView
            } else if let scenario = selectedScenario, isTestActive {
                activeTestView(scenario: scenario)
            } else if showingResults {
                resultsView
            } else {
                scenarioSelectionView
            }
        }
        .onAppear {
            if !dataManager.currentParticipantId.isEmpty {
                participantId = dataManager.currentParticipantId
                showingParticipantPrompt = false
            }
        }
    }
    
    private var participantSetupView: some View {
        VStack(spacing: 30) {
            Text("Research Testing")
                .font(.extraLargeTitle)
                .fontWeight(.bold)
            
            Text("Enter Participant ID")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            TextField("Participant ID", text: $participantId)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
                .padding()
            
            Button("Continue") {
                dataManager.setParticipantId(participantId)
                showingParticipantPrompt = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(participantId.isEmpty)
            .font(.title3)
        }
        .padding()
    }
    
    private var scenarioSelectionView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Test Scenarios")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Participant: \(participantId)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("View Results") {
                    showingResults = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(TestScenario.basicScenarios) { scenario in
                        ScenarioCard(
                            scenario: scenario,
                            previousResults: dataManager.getResults(for: scenario.id)
                        ) {
                            startTest(scenario: scenario)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    
    private func activeTestView(scenario: TestScenario) -> some View {
        VStack(spacing: 30) {
            if let startTime = testStartTime {
                Text(timeElapsed(since: startTime))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Task")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(scenario.task.instruction)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: 600)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Objects")
                    .font(.headline)
                
                ForEach(objectDetector.detectedObjects) { object in
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                        
                        Text(object.name)
                            .font(.title3)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", object.distance()))m")
                            .foregroundStyle(.secondary)
                        
                        Text(object.directionDescription())
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: 600)
            .padding()
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Your Response")
                    .font(.headline)
                
                TextField("Enter your answer", text: $userResponse)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }
            .frame(maxWidth: 600)
            .padding()
            
            HStack(spacing: 20) {
                Button("Announce Objects") {
                    spatialAudio.announceAllObjects(objectDetector.detectedObjects)
                }
                .buttonStyle(.bordered)
                .font(.title3)
                
                Button("Complete Test") {
                    completeTest(scenario: scenario)
                }
                .buttonStyle(.borderedProminent)
                .font(.title3)
                .disabled(userResponse.isEmpty)
            }
            .padding()
        }
        .padding()
    }
    
    private var resultsView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Test Results")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Back") {
                    showingResults = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            HStack(spacing: 40) {
                StatCard(
                    title: "Total Tests",
                    value: "\(dataManager.totalTests())"
                )
                
                StatCard(
                    title: "Avg Accuracy",
                    value: "\(Int(dataManager.averageAccuracy() * 100))%"
                )
                
                StatCard(
                    title: "Avg Response Time",
                    value: String(format: "%.1fs", dataManager.averageResponseTime())
                )
                
                StatCard(
                    title: "Participants",
                    value: "\(dataManager.uniqueParticipants())"
                )
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(dataManager.testResults) { result in
                        ResultCard(result: result)
                    }
                }
                .padding()
            }
            
            HStack(spacing: 20) {
                Button("Export CSV") {
                    exportCSV()
                }
                .buttonStyle(.bordered)
                
                Button("Export JSON") {
                    exportJSON()
                }
                .buttonStyle(.bordered)
                
                Button("Clear All Data") {
                    dataManager.clearAllResults()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
    }
    
    
    private func startTest(scenario: TestScenario) {
        selectedScenario = scenario
        isTestActive = true
        testStartTime = Date()
        userResponse = ""
        
        objectDetector.setMockObjects(scenario.objects)
        
        spatialAudio.updateAudioCues(for: scenario.objects)
        
        spatialAudio.speak(scenario.task.instruction)
    }
    
    private func completeTest(scenario: TestScenario) {
        guard let startTime = testStartTime else { return }
        
        let endTime = Date()
        
        let (correct, total) = evaluateResponse(
            response: userResponse,
            task: scenario.task,
            detectedObjects: objectDetector.detectedObjects
        )
        
        let result = TestResult(
            scenarioId: scenario.id,
            participantId: participantId,
            startTime: startTime,
            endTime: endTime,
            correctIdentifications: correct,
            totalObjects: total,
            userResponse: userResponse
        )
        
        dataManager.saveTestResult(result)
        
        spatialAudio.stopAllAudioCues()
        objectDetector.clearDetections()
        
        isTestActive = false
        selectedScenario = nil
        testStartTime = nil
        userResponse = ""
    }
    
    private func evaluateResponse(response: String, task: TestTask, detectedObjects: [DetectedObject]) -> (correct: Int, total: Int) {
        let normalizedResponse = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch task {
        case .identifyObject(let targetName):
            let correct = normalizedResponse.contains(targetName.lowercased()) ? 1 : 0
            return (correct, 1)
            
        case .locateNearest(let objectType):
            let correct = normalizedResponse.contains(objectType.lowercased()) ? 1 : 0
            return (correct, 1)
            
        case .countObjects(_, let expectedCount):
            if let responseCount = Int(normalizedResponse.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                let correct = responseCount == expectedCount ? 1 : 0
                return (correct, 1)
            }
            return (0, 1)
            
        case .navigateToObject(let targetName):
            let correct = normalizedResponse.contains(targetName.lowercased()) ? 1 : 0
            return (correct, 1)
            
        case .identifyAllObjects:
            let mentionedObjects = detectedObjects.filter { obj in
                normalizedResponse.contains(obj.name.lowercased())
            }
            return (mentionedObjects.count, detectedObjects.count)
        }
    }
    
    private func timeElapsed(since startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func exportCSV() {
        let csv = dataManager.exportToCSV()
        print("CSV Export:\n\(csv)")
    }
    
    private func exportJSON() {
        if let json = dataManager.exportToJSON(),
           let jsonString = String(data: json, encoding: .utf8) {
            print("JSON Export:\n\(jsonString)")
        }
    }
}

struct ScenarioCard: View {
    let scenario: TestScenario
    let previousResults: [TestResult]
    let onStart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(scenario.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Start") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
            }
            
            HStack(spacing: 20) {
                Label("\(scenario.objects.count) objects", systemImage: "cube.fill")
                Label("~\(Int(scenario.expectedDuration))s", systemImage: "clock.fill")
                
                if !previousResults.isEmpty {
                    Label("\(previousResults.count) tests", systemImage: "chart.bar.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ResultCard: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Participant: \(result.participantId)")
                    .font(.headline)
                
                Text(result.startTime, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(result.accuracyPercentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(result.accuracy > 0.85 ? .green : .orange)
                
                Text(String(format: "%.1fs", result.responseTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TestingView()
}