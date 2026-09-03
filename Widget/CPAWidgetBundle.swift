import SwiftUI
import WidgetKit

@main
struct CPAWidgetBundle: WidgetBundle {
    var body: some Widget {
        CPAConfigurableAccountQuotaWidget()
        CPAQuotaTimelineWidget()
        CPAConfigurableQuotaTimelineWidget()
    }
}
