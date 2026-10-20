import WidgetKit
import SwiftUI

@main
struct AccessDeckWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // 桌面小组件（支持长按编辑切换：分段微胶囊 / 连续平滑，以及是否显示重置卡）
        SingleProviderWidget()
        TripleProviderWidget()
        // 锁屏微型小组件 (Accessory Widgets)
        LockScreenQuotaWidget()
        LockScreenMultiProviderWidget()
    }
}
