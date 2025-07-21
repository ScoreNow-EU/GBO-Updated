//
//  GBOWidgetBundle.swift
//  GBOWidget
//
//  Created by Marie on 17.07.25.
//

import WidgetKit
import SwiftUI

@main
struct GBOWidgetBundle: WidgetBundle {
    var body: some Widget {
        GBOWidget()
        GBOWidgetControl()
        GBOWidgetLiveActivity()
    }
}
