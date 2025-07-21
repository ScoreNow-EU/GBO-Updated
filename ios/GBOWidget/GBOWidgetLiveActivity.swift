import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    
    public struct ContentState: Codable, Hashable {
        var matchName: String
        var team1Name: String
        var team2Name: String
        var court: String
        var gameTime: String
        var gameStartDate: Double
        var gameEndDate: Double
        
        // Default initializer to ensure all values are set
        init(matchName: String = "Match", 
             team1Name: String = "Team 1", 
             team2Name: String = "Team 2", 
             court: String = "Court", 
             gameTime: String = "Time", 
             gameStartDate: Double = 0, 
             gameEndDate: Double = 0) {
            self.matchName = matchName
            self.team1Name = team1Name
            self.team2Name = team2Name
            self.court = court
            self.gameTime = gameTime
            self.gameStartDate = gameStartDate
            self.gameEndDate = gameEndDate
        }
        
        // Computed properties to get Date objects
        var gameStartDateAsDate: Date {
            return Date(timeIntervalSince1970: gameStartDate / 1000.0)
        }
        
        var gameEndDateAsDate: Date {
            return Date(timeIntervalSince1970: gameEndDate / 1000.0)
        }
    }
    
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

struct GBOWidgetLiveActivity: Widget {
    let sharedDefault = UserDefaults(suiteName: "group.germanbeachopen.gbo")!
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // ULTRA SIMPLE UI - Just text to avoid crashes
            VStack(spacing: 4) {
                Text("🏐 Beach Volleyball")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Team A vs Team B")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Court 1 • 12:00")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Live Activity Test")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .bold()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        } dynamicIsland: { context in
            // Dynamic Island UI - ULTRA SIMPLE
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("A")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("B")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text("vs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text("🏐 Beach Volleyball")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                }
            } compactLeading: {
                Text("🏐")
            } compactTrailing: {
                Text("12:00")
                    .font(.caption2)
                    .fontWeight(.medium)
            } minimal: {
                Text("🏐")
            }
        }
    }

}
