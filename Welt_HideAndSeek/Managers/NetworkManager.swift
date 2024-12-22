import Foundation
import CoreLocation

class NetworkManager: ObservableObject {
    // 模拟房间存储
    private var mockRooms: [Room] = [
        // ID: 222222 - 可加入的房间
        Room(
            id: "222222",
            host: Player(name: "房主", isHost: true),
            players: [
                Player(name: "房主", isHost: true),
                Player(name: "玩家1", isHost: false)
            ],
            maxPlayers: 8,
            gameDuration: 300,
            gameStatus: .waiting
        ),
        // ID: 111111 - 已开始游戏的房间
        Room(
            id: "111111",
            host: Player(name: "房主A", isHost: true),
            players: [
                Player(name: "房主A", isHost: true),
                Player(name: "玩家A1", isHost: false),
                Player(name: "玩家A2", isHost: false)
            ],
            maxPlayers: 8,
            gameDuration: 300,
            gameStatus: .playing
        ),
        // ID: 666666 - 已满的房间
        Room(
            id: "666666",
            host: Player(name: "房主B", isHost: true),
            players: [
                Player(name: "房主B", isHost: true),
                Player(name: "玩家B1", isHost: false),
                Player(name: "玩家B2", isHost: false),
                Player(name: "玩家B3", isHost: false),
                Player(name: "玩家B4", isHost: false),
                Player(name: "玩家B5", isHost: false),
                Player(name: "玩家B6", isHost: false),
                Player(name: "玩家B7", isHost: false)
            ],
            maxPlayers: 8,
            gameDuration: 300,
            gameStatus: .waiting
        )
    ]
    
    enum NetworkError: Error {
        case roomNotFound
        case unauthorized
        
        var localizedDescription: String {
            switch self {
            case .roomNotFound:
                return "找不到指定房间"
            case .unauthorized:
                return "未授权的操作"
            }
        }
    }
    
    enum RoomStatus {
        case available
        case notFound
        case full
        case inProgress
    }
    
    // 查找房间
    func findRoom(roomId: String) -> Room? {
        return mockRooms.first { room in room.id == roomId }
    }
    
    // 验证房间状态
    func verifyRoom(_ roomId: String, completion: @escaping (RoomStatus) -> Void) {
        if let room = findRoom(roomId:roomId) {
            if room.gameStatus == .playing {
                completion(.inProgress)
            } else if room.players.count >= room.maxPlayers {
                completion(.full)
            } else {
                completion(.available)
            }
        } else {
            completion(.notFound)
        }
    }
    
    // 删除房间
    func removeRoom(roomId: String) {
        if let room = mockRooms.first(where: { $0.id == roomId }) {
            // 停止所有玩家的位置模拟
            for player in room.players {
                stopLocationSimulation(for: player.id)
            }
        }
        mockRooms.removeAll { $0.id == roomId }
    }
    
    // 扩展模拟玩家列表
    private let mockPlayers = [
        Player(name: "测试玩家1", isHost: false),
        Player(name: "测试玩家2", isHost: false),
        Player(name: "测试玩家3", isHost: false),
        Player(name: "测试玩家4", isHost: false),
        Player(name: "测试玩家5", isHost: false),
        Player(name: "测试玩家6", isHost: false),
        Player(name: "测试玩家7", isHost: false),
        Player(name: "测试玩家8", isHost: false),
        Player(name: "测试玩家9", isHost: false),
        Player(name: "测试玩家10", isHost: false)
    ]
    
    // 添加位置更新计时器字典
    private var locationUpdateTimers: [String: Timer] = [:]
    private var playerBaseLocations: [String: CLLocationCoordinate2D] = [:]
    
    // 生成随机位置
    private func generateRandomLocation(near baseLocation: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 生成5-100米的随机距离
        let randomDistance = Double.random(in: 5...100)
        // 生成随机角度（0-360度）
        let randomAngle = Double.random(in: 0...(2 * .pi))
        
        // 计算经纬度偏移量（粗略计算，仅用于演示）
        let latOffset = randomDistance * cos(randomAngle) / 111000 // 1度纬度约等于111公里
        let lonOffset = randomDistance * sin(randomAngle) / (111000 * cos(baseLocation.latitude * .pi / 180))
        
        return CLLocationCoordinate2D(
            latitude: baseLocation.latitude + latOffset,
            longitude: baseLocation.longitude + lonOffset
        )
    }
    
    // 开始模拟位置更新
    private func startLocationSimulation(for player: Player, near baseLocation: CLLocationCoordinate2D) {
        // 保存基准位置
        playerBaseLocations[player.id] = baseLocation
        
        // 停止现有的计时器
        locationUpdateTimers[player.id]?.invalidate()
        
        // 创建新的计时器，每1-3秒更新一次位置
        let timer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 1...3), repeats: true) { [weak self] _ in
            guard let self = self,
                  let baseLocation = self.playerBaseLocations[player.id] else { return }
            
            // 生成新的随机位置
            let newLocation = self.generateRandomLocation(near: baseLocation)
            
            // 通知位置更新
            NotificationCenter.default.post(
                name: .playerLocationUpdated,
                object: nil,
                userInfo: [
                    "playerId": player.id,
                    "location": newLocation
                ]
            )
        }
        
        locationUpdateTimers[player.id] = timer
    }
    
    // 停止位置模拟
    private func stopLocationSimulation(for playerId: String) {
        locationUpdateTimers[playerId]?.invalidate()
        locationUpdateTimers[playerId] = nil
        playerBaseLocations[playerId] = nil
    }
    
    // 修改添加房间的方法
    func addRoom(_ room: Room) {
        mockRooms.append(room)
        
        // 随机决定要加入的玩家数量（1-5个）
        let numberOfPlayersToJoin = Int.random(in: 1...5)
        var availablePlayers = mockPlayers.shuffled() // 随机打乱玩家顺序
        
        // 为每个要加入的玩家设置随机延迟
        for i in 0..<numberOfPlayersToJoin {
            guard i < availablePlayers.count else { break }
            
            // 生成随机延迟时间（1-10秒）
            let randomDelay = Double.random(in: 1...10)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
                self?.trySimulatePlayerJoining(roomId: room.id, player: availablePlayers[i])
            }
        }
    }
    
    // 修改玩家加入的模拟方法
    private func trySimulatePlayerJoining(roomId: String, player: Player) {
        guard let index = mockRooms.firstIndex(where: { $0.id == roomId }) else { return }
        
        let room = mockRooms[index]
        guard room.players.count < room.maxPlayers else { return }
        guard room.gameStatus == .waiting else { return }
        
        // 更新房间玩家列表
        var updatedRoom = room
        updatedRoom.players.append(player)
        mockRooms[index] = updatedRoom
        
        // 获取房主位置作为基准位置
        if let hostLocation = playerBaseLocations[room.host.id] {
            // 开始位置模拟
            startLocationSimulation(for: player, near: hostLocation)
        } else {
            // 如果没有房主位置，使用默认位置
            let defaultLocation = CLLocationCoordinate2D(
                latitude: 35.681236,
                longitude: 139.767125
            )
            startLocationSimulation(for: player, near: defaultLocation)
        }
        
        // 通知房间状态更新
        NotificationCenter.default.post(
            name: .roomUpdated,
            object: nil,
            userInfo: ["roomId": roomId, "room": updatedRoom]
        )
        
        // 有一定概率（30%）在短暂延迟后继续添加新玩家
        if Double.random(in: 0...1) < 0.3 {
            let remainingPlayers = mockPlayers.filter { mockPlayer in
                !updatedRoom.players.contains { $0.id == mockPlayer.id }
            }
            
            if let nextPlayer = remainingPlayers.first {
                // 1-5秒的随机延迟
                let randomDelay = Double.random(in: 1...5)
                DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
                    self?.trySimulatePlayerJoining(roomId: roomId, player: nextPlayer)
                }
            }
        }
    }
    
    // 更新房间信息
    func updateRoom(_ room: Room) {
        if let index = mockRooms.firstIndex(where: { $0.id == room.id }) {
            let oldRoom = mockRooms[index]
            mockRooms[index] = room
            
            // 如果游戏结束，停止所有位置模拟
            if room.gameStatus == .finished {
                for player in room.players {
                    stopLocationSimulation(for: player.id)
                }
            }
        }
    }
}

// 添加通知名称
extension Notification.Name {
    static let roomUpdated = Notification.Name("roomUpdated")
    static let playerLocationUpdated = Notification.Name("playerLocationUpdated")
}
