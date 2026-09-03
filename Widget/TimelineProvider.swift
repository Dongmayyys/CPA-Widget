import Foundation
import WidgetKit

struct CPAAccountWidgetTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = AccountQuotaWidgetIntent
    typealias Entry = CPAWidgetEntry

    private let cacheStore = CacheStore()
    private let settingsStore = AppSettingsStore()

    func placeholder(in context: Context) -> CPAWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: AccountQuotaWidgetIntent, in context: Context) async -> CPAWidgetEntry {
        context.isPreview ? .placeholder : makeEntry(configuration)
    }

    func timeline(for configuration: AccountQuotaWidgetIntent, in context: Context) async -> Timeline<CPAWidgetEntry> {
        let entry = makeEntry(configuration)
        let delay = entry.accounts.isEmpty ? 60 : settingsStore.refreshInterval
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(delay)))
    }

    private func makeEntry(_ configuration: AccountQuotaWidgetIntent) -> CPAWidgetEntry {
        let allAccounts = liveAccounts()
        let requestedIDs = configuration.accounts ?? []
        let requestedProvider = configuration.provider.provider
        let availableProvider = requestedProvider.flatMap { provider in
            allAccounts.contains(where: { $0.provider == provider }) ? provider : nil
        }

        return CPAWidgetEntry(
            date: Date(),
            // Both Widget channels resolve from the same complete cached
            // account set. Legacy fields are folded into channel 1 by the
            // intent, rather than restricting channel 2's independent choice.
            accounts: allAccounts,
            status: cacheStore.loadStatus(),
            language: settingsStore.language,
            mode: configuration.mode,
            selectedProvider: availableProvider
                ?? (allAccounts.contains(where: { $0.provider == .codex }) ? .codex : allAccounts.first?.provider),
            selectedAccountIDs: requestedIDs,
            windowChoice: .automatic,
            quotaConfiguration: configuration.widgetQuotaConfiguration,
            warnsAboutInsecureHTTP: settingsStore.warnsAboutInsecureHTTP
        )
    }

    private func liveAccounts() -> [AccountQuotaInfo] {
        let enabledProviders = settingsStore.enabledProviders
        return cacheStore.loadAccountQuota()
            .filter { enabledProviders.contains($0.provider) }
            .sorted(by: AccountQuotaInfo.displayOrder)
    }
}

struct CPATimelineWidgetTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = QuotaTimelineWidgetIntent
    typealias Entry = CPAWidgetEntry

    private let cacheStore = CacheStore()
    private let settingsStore = AppSettingsStore()

    func placeholder(in context: Context) -> CPAWidgetEntry {
        let entry = CPAWidgetEntry.placeholder
        return CPAWidgetEntry(
            date: entry.date,
            accounts: entry.accounts,
            status: entry.status,
            language: entry.language,
            mode: .accountOverview,
            selectedProvider: nil,
            selectedAccountIDs: [],
            windowChoice: .automatic,
            quotaConfiguration: .default,
            warnsAboutInsecureHTTP: false
        )
    }

    func snapshot(for configuration: QuotaTimelineWidgetIntent, in context: Context) async -> CPAWidgetEntry {
        context.isPreview ? placeholder(in: context) : makeEntry(configuration)
    }

    func timeline(for configuration: QuotaTimelineWidgetIntent, in context: Context) async -> Timeline<CPAWidgetEntry> {
        let entry = makeEntry(configuration)
        let delay = entry.accounts.isEmpty ? 60 : settingsStore.refreshInterval
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(delay)))
    }

    private func makeEntry(_ configuration: QuotaTimelineWidgetIntent) -> CPAWidgetEntry {
        let enabledProviders = settingsStore.enabledProviders
        let accounts = cacheStore.loadAccountQuota()
            .filter { enabledProviders.contains($0.provider) }
            .sorted(by: AccountQuotaInfo.displayOrder)

        return CPAWidgetEntry(
            date: Date(),
            accounts: accounts,
            status: cacheStore.loadStatus(),
            language: settingsStore.language,
            mode: .accountOverview,
            selectedProvider: configuration.provider.provider,
            selectedAccountIDs: configuration.accounts ?? [],
            windowChoice: configuration.window,
            quotaConfiguration: configuration.widgetQuotaConfiguration,
            warnsAboutInsecureHTTP: settingsStore.warnsAboutInsecureHTTP
        )
    }
}
