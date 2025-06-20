//
//  AppWidgetTestBundle.swift
//  AppWidgetTest
//
//  Created by Marie on 19.06.25.
//

import WidgetKit
import SwiftUI

@main
struct AppWidgetTestBundle: WidgetBundle {
    var body: some Widget {
        AppWidgetTest()
        AppWidgetTestControl()
        AppWidgetTestLiveActivity()
    }
}
