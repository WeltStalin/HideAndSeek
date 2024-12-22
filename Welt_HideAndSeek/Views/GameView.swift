import SwiftUI
import MapKit
import CoreLocation

struct GameView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    @EnvironmentObject var roomViewModel: RoomViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 修改地图视图，移除系统默认的用户位置标记
                Map(coordinateRegion: $region,
                    showsUserLocation: false,
                    userTrackingMode: .constant(.follow),
                    annotationItems: getPlayerAnnotations()) { annotation in
                        MapAnnotation(coordinate: annotation.location) {
                            PlayerLocationMarker(
                                playerName: annotation.name,
                                color: annotation.color,
                                isCurrentPlayer: annotation.isCurrentPlayer
                            )
                        }
                }
                .edgesIgnoringSafeArea(.all)
                
                // 游戏信息覆盖层
                VStack {
                    // 顶部信息栏
                    HStack(spacing: 15) {
                        // 计时器卡片
                        HStack(spacing: 8) {
                            Button(action: {
                                roomViewModel.currentRoom?.gameStatus = .waiting
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.blue)
                                    .imageScale(.large)
                            }
                            
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("\(formatTime(Int(gameViewModel.gameTimeRemaining)))")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.9))
                                .shadow(radius: 5)
                        )
                        
                        // 玩家状态卡片
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("\(gameViewModel.caughtPlayers.count)/\(getRunnersCount())")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.9))
                                .shadow(radius: 5)
                        )
                    }
                    .padding()
                    
                    Spacer()
                    
                    // 修改玩家角色信息部分
                    if let currentPlayer = roomViewModel.currentPlayer,
                       let gamePlayer = gameViewModel.currentPlayers.first(where: { $0.id == currentPlayer.id }) {
                        PlayerRoleTag(player: gamePlayer)
                            .padding(.bottom)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // 视图出现时恢复游戏
            gameViewModel.resumeGame()
            
            DispatchQueue.main.async {
                locationManager.requestAuthorization()
                locationManager.startUpdatingLocation()
            }
        }
        .onDisappear {
            // 视图消失时暂停游戏
            gameViewModel.pauseGame()
            locationManager.stopUpdatingLocation()
        }
        .onReceive(locationManager.$location) { location in
            if let newLocation = location {
                withAnimation {
                    region.center = newLocation
                }
                
                if let playerId = roomViewModel.currentPlayer?.id {
                    gameViewModel.updateLocation(
                        playerId: playerId,
                        location: newLocation
                    )
                }
            }
        }
        .alert(item: $locationManager.locationError) { error in
            Alert(
                title: Text("位置错误"),
                message: Text(error.errorDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 获取玩家���注
    private func getPlayerAnnotations() -> [PlayerAnnotation] {
        roomViewModel.players.compactMap { player in
            guard let location = gameViewModel.playerLocations[player.id] else { return nil }
            
            let color: Color
            if player.role == .seeker {
                color = .red  // 追捕者显示红色
            } else if gameViewModel.caughtPlayers.contains(player.id) {
                color = .gray // 已被抓显示灰色
            } else {
                color = .green // 逃跑者显示绿色
            }
            
            return PlayerAnnotation(
                id: player.id,
                name: player.name,
                location: location,
                color: color,
                isCurrentPlayer: player.id == roomViewModel.currentPlayer?.id
            )
        }
    }
    
    // 格式化时间
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // 玩家角色标签
    private func PlayerRoleTag(player: Player) -> some View {
        let roleInfo = getRoleInfo(player)
        return HStack {
            Image(systemName: roleInfo.icon)
                .foregroundColor(roleInfo.color)
            Text(roleInfo.text)
                .bold()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.9))
                .shadow(radius: 5)
        )
    }
    
    // 修改 getRoleInfo 方法
    private func getRoleInfo(_ player: Player) -> (icon: String, color: Color, text: String) {
        // 直接使用传入的 player 参数来判断角色，而不是重新获取 currentPlayer
        if gameViewModel.caughtPlayers.contains(player.id) {
            return ("xmark.circle.fill", .gray, "已被抓获")
        } else {
            switch player.role {
            case .seeker:
                return ("eye.fill", .red, "追捕者")
            case .runner:
                return ("figure.run", .green, "逃跑者")
            }
        }
    }
    
    // 新增：获取逃跑者总数的方法
    private func getRunnersCount() -> Int {
        return gameViewModel.currentPlayers.filter { $0.role == .runner }.count
    }
}

// 玩家标注模型
struct PlayerAnnotation: Identifiable {
    let id: String
    let name: String
    let location: CLLocationCoordinate2D
    let color: Color
    let isCurrentPlayer: Bool
}

// 修改玩家位置标记视图
struct PlayerLocationMarker: View {
    let playerName: String
    let color: Color
    let isCurrentPlayer: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if !isCurrentPlayer {
                Text(playerName)
                    .font(.caption)
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(4)
                    .shadow(radius: 2)
                
                Image(systemName: "triangle.fill")
                    .rotationEffect(.degrees(180))
                    .foregroundColor(.white)
                    .offset(y: -3)
            }
            
            Circle()
                .fill(color)
                .frame(width: isCurrentPlayer ? 15 : 10, height: isCurrentPlayer ? 15 : 10)
                .shadow(radius: 2)
        }
    }
}

#Preview {
    GameView()
        .environmentObject(GameViewModel())
        .environmentObject(RoomViewModel(gameViewModel: GameViewModel()))
} 
