//
//  AppWidgetTestLiveActivity.swift
//  AppWidgetTest
//
//  Created by Marie on 19.06.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AppWidgetTestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AppWidgetTestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AppWidgetTestAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AppWidgetTestAttributes {
    fileprivate static var preview: AppWidgetTestAttributes {
        AppWidgetTestAttributes(name: "World")
    }
}

extension AppWidgetTestAttributes.ContentState {
    fileprivate static var smiley: AppWidgetTestAttributes.ContentState {
        AppWidgetTestAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AppWidgetTestAttributes.ContentState {
         AppWidgetTestAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AppWidgetTestAttributes.preview) {
   AppWidgetTestLiveActivity()
} contentStates: {
    AppWidgetTestAttributes.ContentState.smiley
    AppWidgetTestAttributes.ContentState.starEyes
}
