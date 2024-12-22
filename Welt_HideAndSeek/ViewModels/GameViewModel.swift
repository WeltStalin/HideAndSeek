import Foundation
import CoreLocation
import SwiftUI

class GameViewModel: ObservableObject {
    @Published var playerLocations: [String: CLLocationCoordinate2D] = [:]
    @Published var gameTimeRemaining: TimeInterval = 0
    @Published var gameStatus: GameStatus = .waiting
    @Published var gameResult: GameResult?
    @Published var caughtPlayers: Set<String> = []
    @Published var showResult: Bool = false
    @Published var currentPlayers: [Player] = []
    @Published var gameDuration: TimeInterval = 0

    private var gameTimer: Timer?
    private var startTime: Date?
    private var isPaused: Bool = false
    
    private let catchDistance: Double = 5.0
    
    enum GameStatus {
        case waiting
        case playing
        case finished
    }
    
    enum GameResult {
        case seekerWin
        case runnerWin
    }
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerLocationUpdate),
            name: .playerLocationUpdated,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePlayerLocationUpdate(_ notification: Notification) {
        guard let playerId = notification.userInfo?["playerId"] as? String,
              let location = notification.userInfo?["location"] as? CLLocationCoordinate2D else {
            return
        }
        
        DispatchQueue.main.async {
            self.updateLocation(playerId: playerId, location: location)
        }
    }
    
    func resetGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        gameStatus = .waiting
        gameResult = nil
        caughtPlayers.removeAll()
        playerLocations.removeAll()
        gameTimeRemaining = 0
        startTime = nil
        gameDuration = 0
        isPaused = false
        
        for i in currentPlayers.indices {
            currentPlayers[i].role = .runner
        }
    }
    
    private func checkGameEnd() {
        if allRunnersCaught() {
            endGame(runnersWin: false)
        }
    }
    
    private func endGame(runnersWin: Bool) {
        gameTimer?.invalidate()
        gameTimer = nil
        gameStatus = .finished
        gameResult = runnersWin ? .runnerWin : .seekerWin
        
        if let start = startTime {
            gameDuration = Date().timeIntervalSince(start)
        }
        
        showResult = true
    }
    
    func updateLocation(playerId: String, location: CLLocationCoordinate2D) {
        playerLocations[playerId] = location
        
        if let player = currentPlayers.first(where: { $0.id == playerId }),
           player.role == .seeker {
            checkCatchStatus(seekerId: playerId)
        }
    }
    
    private func checkCatchStatus(seekerId: String) {
        guard let seekerLocation = playerLocations[seekerId] else { return }
        
        let runners = currentPlayers.filter { $0.role == .runner && !caughtPlayers.contains($0.id) }
        
        for runner in runners {
            if let runnerLocation = playerLocations[runner.id] {
                let distance = calculateDistance(from: seekerLocation, to: runnerLocation)
                if distance <= catchDistance {
                    handleCatch(seekerId: seekerId, runnerId: runner.id)
                }
            }
        }
    }
    
    private func calculateDistance(from location1: CLLocationCoordinate2D, to location2: CLLocationCoordinate2D) -> Double {
        let location1Point = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let location2Point = CLLocation(latitude: location2.latitude, longitude: location2.longitude)
        return location1Point.distance(from: location2Point)
    }
    
    private func handleCatch(seekerId: String, runnerId: String) {
        caughtPlayers.insert(runnerId)
        checkGameEnd()
    }
    
    func startGame(duration: TimeInterval, players: [Player]) {
        resetGame()
        gameTimeRemaining = duration
        gameStatus = .playing
        currentPlayers = players
        startTime = Date()
        isPaused = false
        startTimer()
    }
    
    func pauseGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        isPaused = true
    }
    
    func resumeGame() {
        if gameStatus == .playing && isPaused {
            isPaused = false
            startTimer()
        }
    }
    
    private func startTimer() {
        gameTimer?.invalidate()
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.gameTimeRemaining > 0 {
                self.gameTimeRemaining -= 1
                self.checkGameEnd()
            } else {
                let runnersWin = !self.allRunnersCaught()
                self.endGame(runnersWin: runnersWin)
            }
        }
    }
    
    private func allRunnersCaught() -> Bool {
        let runners = currentPlayers.filter { $0.role == .runner }
        return caughtPlayers.count >= runners.count
    }
} 
