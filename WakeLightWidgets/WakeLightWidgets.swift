import WidgetKit
import SwiftUI

@main
struct WakeLightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LightToggleWidget()
        NextAlarmWidget()
        SensorWidget()
    }
}
