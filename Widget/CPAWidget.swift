import AppIntents
import SwiftUI
import WidgetKit

struct CPAConfigurableAccountQuotaWidget: Widget {
    let kind = "CPAConfigurableAccountQuotaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: AccountQuotaWidgetIntent.self,
            provider: CPAAccountWidgetTimelineProvider()
        ) { entry in
            CPAQuotaCollectionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CPA Quota / CPA 配额")
        .description("Show up to eight independently configurable quotas / 最多显示八条独立配置的配额")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct CPAQuotaTimelineWidget: Widget {
    let kind = "CPAQuotaTimelineWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuotaTimelineWidgetIntent.self,
            provider: CPATimelineWidgetTimelineProvider()
        ) { entry in
            CPAQuotaCollectionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CPA Quota Timeline / CPA 配额时间线")
        .description("Show up to eight independently configurable quotas / 最多显示八条独立配置的配额")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct CPAConfigurableQuotaTimelineWidget: Widget {
    let kind = "CPAConfigurableQuotaTimelineWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuotaTimelineWidgetIntent.self,
            provider: CPATimelineWidgetTimelineProvider()
        ) { entry in
            CPAQuotaCollectionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CPA Timeline (Configurable) / CPA 时间线（可配置）")
        .description("Show up to eight independently configurable quotas / 最多显示八条独立配置的配额")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
