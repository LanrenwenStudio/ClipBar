import WidgetKit
import SwiftUI

@main
struct ClipBarWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // 现有版本（连续实心进度条风格）
        SingleProviderWidget()
        TripleProviderWidget()

        // 新版（分段胶囊进度条风格）
        SegmentedSingleProviderWidget()
        SegmentedMultiProviderWidget()

        // 锁屏微型小组件 (Accessory Widgets)
        LockScreenQuotaWidget()
        LockScreenMultiProviderWidget()
    }
}
