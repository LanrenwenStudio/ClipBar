import WidgetKit
import SwiftUI

@main
struct ClipBarWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SingleProviderWidget()
        TripleProviderWidget()
    }
}
