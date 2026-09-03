import AppIntents
import Foundation

enum QuotaWidgetMode: String, AppEnum, Sendable {
    case singleProvider
    case providerOverview
    case accountOverview

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "显示方式 / Display")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .singleProvider: "单类额度详情 / One provider",
        .providerOverview: "多类额度总览 / Provider overview",
        .accountOverview: "账号额度 / Accounts"
    ]
}
/// A Widget channel intentionally mirrors the menu-bar channel scopes while
/// remaining AppIntent-friendly. `automatic` is retained for migration.
enum WidgetQuotaScope: String, AppEnum, Sendable {
    case automatic
    case allAccounts
    case provider
    case accounts

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "范围 / Scope")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "自动 / Automatic",
        .allAccounts: "全部账号 / All accounts",
        .provider: "一类账号 / Provider",
        .accounts: "指定账号 / Accounts"
    ]
}

enum WidgetQuotaPresentation: String, AppEnum, Sendable {
    case cards
    case rings
    case timeline
    case mixed

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "显示方式 / Presentation")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .cards: "配额卡片 / Quota cards",
        .rings: "环形进度 / Rings",
        .timeline: "配额时间线 / Timeline",
        .mixed: "圆环 + 进度条 / Rings + bars"
    ]
}

/// Retained so configurations written by the unpublished two-slot build can
/// migrate without losing which of its two channels was visible.
enum WidgetQuotaVisibility: String, AppEnum, Sendable {
    case primaryOnly
    case secondaryOnly
    case both

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "旧配额显示 / Legacy visibility")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .primaryOnly: "配额 1 / Quota 1",
        .secondaryOnly: "配额 2 / Quota 2",
        .both: "配额 1 + 2 / Quotas 1 + 2"
    ]
}

enum WidgetQuotaCount: String, AppEnum, Sendable {
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "配额数量 / Quota count")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .one: "1 条 / 1 quota",
        .two: "2 条 / 2 quotas",
        .three: "3 条 / 3 quotas",
        .four: "4 条 / 4 quotas",
        .five: "5 条 / 5 quotas",
        .six: "6 条 / 6 quotas",
        .seven: "7 条 / 7 quotas",
        .eight: "8 条 / 8 quotas"
    ]

    var value: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .three: 3
        case .four: 4
        case .five: 5
        case .six: 6
        case .seven: 7
        case .eight: 8
        }
    }
}

enum WidgetProviderChoice: String, AppEnum, Sendable {
    case automatic
    case claude
    case codex
    case gemini
    case kimi

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "服务类型 / Provider")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "自动选择 / Automatic",
        .claude: "Claude",
        .codex: "Codex",
        .gemini: "Gemini / Antigravity",
        .kimi: "Kimi"
    ]

    var provider: ProviderType? { ProviderType(rawValue: rawValue) }
}

enum WidgetWindowChoice: String, AppEnum, Sendable {
    case automatic
    case short
    case weekly

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "配额周期 / Quota window")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "自动 / Automatic",
        .short: "短周期（5 小时）/ Short",
        .weekly: "周配额 / Weekly"
    ]
}

struct WidgetAccountOptionsProvider: DynamicOptionsProvider {
    typealias Result = IntentItemCollection<String>
    typealias DefaultValue = String

    func results() async throws -> IntentItemCollection<String> {
        let items = CacheStore().loadAccountQuota()
            .sorted(by: AccountQuotaInfo.displayOrder)
            .enumerated()
            .map { index, account in
                IntentItem(
                    account.id,
                    title: "\(Self.maskedAccountTitle(account.displayName, fallbackIndex: index + 1))",
                    subtitle: "\(account.provider.displayName)"
                )
            }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }

    private static func maskedAccountTitle(_ value: String, fallbackIndex: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "账号 \(fallbackIndex) / Account \(fallbackIndex)" }
        guard let at = trimmed.firstIndex(of: "@") else { return trimmed }
        let local = trimmed[..<at]
        let domain = trimmed[at...]
        return "\(local.prefix(2))•••\(domain)"
    }
}

/// Exact choices come from the cached, sanitised account model, so every
/// provider window returned by CLIProxyAPI can be selected independently.
struct WidgetWindowOptionsProvider: DynamicOptionsProvider {
    typealias Result = IntentItemCollection<String>
    typealias DefaultValue = String

    func results() async throws -> IntentItemCollection<String> {
        let items = CacheStore().loadAccountQuota()
            .aggregateQuotaWindows()
            .map { window in
                IntentItem(
                    window.id,
                    title: "\(window.provider.displayName) · \(window.label)",
                    subtitle: "Quota window / 配额窗口"
                )
            }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }
}

struct WidgetQuotaChannel: Sendable, Equatable {
    let scope: WidgetQuotaScope
    let provider: ProviderType
    let accountIDs: [String]
    let windowID: String?

    func selectedAccounts(from accounts: [AccountQuotaInfo]) -> [AccountQuotaInfo] {
        let selected: [AccountQuotaInfo]
        switch scope {
        case .automatic, .provider:
            selected = accounts.filter { $0.provider == provider }
        case .allAccounts:
            selected = accounts
        case .accounts:
            let requestedIDs = Set(accountIDs)
            selected = accounts.filter {
                $0.provider == provider && requestedIDs.contains($0.id)
            }
        }
        return selected.sorted(by: AccountQuotaInfo.displayOrder)
    }
}

struct WidgetQuotaConfiguration: Sendable {
    let presentation: WidgetQuotaPresentation
    let channels: [WidgetQuotaChannel]

    static let `default` = WidgetQuotaConfiguration(
        presentation: .rings,
        channels: [
            WidgetQuotaChannel(
                scope: .provider,
                provider: .codex,
                accountIDs: [],
                windowID: "weekly"
            )
        ]
    )
}

private func migratedChannels(
    quotaCount: WidgetQuotaCount?,
    legacyVisibility: WidgetQuotaVisibility,
    allChannels: [WidgetQuotaChannel]
) -> [WidgetQuotaChannel] {
    if let quotaCount {
        return Array(allChannels.prefix(quotaCount.value))
    }
    switch legacyVisibility {
    case .primaryOnly:
        return Array(allChannels.prefix(1))
    case .secondaryOnly:
        return allChannels.count > 1 ? [allChannels[1]] : Array(allChannels.prefix(1))
    case .both:
        return Array(allChannels.prefix(2))
    }
}

struct AccountQuotaWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "CPA 额度显示 / CPA Quota"
    static let description = IntentDescription("选择 1–8 条独立配额；小组件会按尺寸和样式显示可容纳的数量。/ Select 1–8 independent quotas; the Widget shows as many as its family and presentation can hold.")

    static var parameterSummary: some ParameterSummary {
        Switch(\.$quotaCount) {
            Case(.one) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                }
            }
            Case(.two) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                }
            }
            Case(.three) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                }
            }
            Case(.four) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                }
            }
            Case(.five) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                }
            }
            Case(.six) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                }
            }
            Case(.seven) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                    \.$slot7Scope
                    \.$slot7Provider
                    \.$slot7Accounts
                    \.$slot7WindowID
                }
            }
            Case(.eight) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                    \.$slot7Scope
                    \.$slot7Provider
                    \.$slot7Accounts
                    \.$slot7WindowID
                    \.$slot8Scope
                    \.$slot8Provider
                    \.$slot8Accounts
                    \.$slot8WindowID
                }
            }
            DefaultCase {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                }
            }
        }
    }

    @Parameter(title: "显示方式 / Presentation", default: .rings)
    var presentation: WidgetQuotaPresentation

    @Parameter(title: "配额数量 / Quota count")
    var quotaCount: WidgetQuotaCount?

    @Parameter(title: "旧配额显示 / Legacy visibility", default: .primaryOnly)
    var visibility: WidgetQuotaVisibility

    @Parameter(title: "总览显示方式 / Overview display", default: .singleProvider)
    var mode: QuotaWidgetMode

    @Parameter(title: "总览服务 / Overview provider", default: .codex)
    var provider: WidgetProviderChoice

    @Parameter(title: "总览账号 / Overview accounts", optionsProvider: WidgetAccountOptionsProvider())
    var accounts: [String]?

    @Parameter(title: "配额 1 范围 / Quota 1 scope", default: .automatic)
    var primaryScope: WidgetQuotaScope

    @Parameter(title: "配额 1 服务 / Quota 1 provider", default: .automatic)
    var primaryProvider: WidgetProviderChoice

    @Parameter(title: "配额 1 账号 / Quota 1 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var primaryAccounts: [String]?

    @Parameter(title: "配额 1 窗口 / Quota 1 window", optionsProvider: WidgetWindowOptionsProvider())
    var primaryWindowID: String?

    @Parameter(title: "配额 2 范围 / Quota 2 scope", default: .provider)
    var secondaryScope: WidgetQuotaScope

    @Parameter(title: "配额 2 服务 / Quota 2 provider", default: .codex)
    var secondaryProvider: WidgetProviderChoice

    @Parameter(title: "配额 2 账号 / Quota 2 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var secondaryAccounts: [String]?

    @Parameter(title: "配额 2 窗口 / Quota 2 window", optionsProvider: WidgetWindowOptionsProvider())
    var secondaryWindowID: String?

    @Parameter(title: "配额 3 范围 / Quota 3 scope", default: .provider)
    var slot3Scope: WidgetQuotaScope

    @Parameter(title: "配额 3 服务 / Quota 3 provider", default: .automatic)
    var slot3Provider: WidgetProviderChoice

    @Parameter(title: "配额 3 账号 / Quota 3 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot3Accounts: [String]?

    @Parameter(title: "配额 3 窗口 / Quota 3 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot3WindowID: String?

    @Parameter(title: "配额 4 范围 / Quota 4 scope", default: .provider)
    var slot4Scope: WidgetQuotaScope

    @Parameter(title: "配额 4 服务 / Quota 4 provider", default: .automatic)
    var slot4Provider: WidgetProviderChoice

    @Parameter(title: "配额 4 账号 / Quota 4 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot4Accounts: [String]?

    @Parameter(title: "配额 4 窗口 / Quota 4 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot4WindowID: String?

    @Parameter(title: "配额 5 范围 / Quota 5 scope", default: .provider)
    var slot5Scope: WidgetQuotaScope

    @Parameter(title: "配额 5 服务 / Quota 5 provider", default: .automatic)
    var slot5Provider: WidgetProviderChoice

    @Parameter(title: "配额 5 账号 / Quota 5 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot5Accounts: [String]?

    @Parameter(title: "配额 5 窗口 / Quota 5 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot5WindowID: String?

    @Parameter(title: "配额 6 范围 / Quota 6 scope", default: .provider)
    var slot6Scope: WidgetQuotaScope

    @Parameter(title: "配额 6 服务 / Quota 6 provider", default: .automatic)
    var slot6Provider: WidgetProviderChoice

    @Parameter(title: "配额 6 账号 / Quota 6 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot6Accounts: [String]?

    @Parameter(title: "配额 6 窗口 / Quota 6 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot6WindowID: String?

    @Parameter(title: "配额 7 范围 / Quota 7 scope", default: .provider)
    var slot7Scope: WidgetQuotaScope

    @Parameter(title: "配额 7 服务 / Quota 7 provider", default: .automatic)
    var slot7Provider: WidgetProviderChoice

    @Parameter(title: "配额 7 账号 / Quota 7 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot7Accounts: [String]?

    @Parameter(title: "配额 7 窗口 / Quota 7 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot7WindowID: String?

    @Parameter(title: "配额 8 范围 / Quota 8 scope", default: .provider)
    var slot8Scope: WidgetQuotaScope

    @Parameter(title: "配额 8 服务 / Quota 8 provider", default: .automatic)
    var slot8Provider: WidgetProviderChoice

    @Parameter(title: "配额 8 账号 / Quota 8 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot8Accounts: [String]?

    @Parameter(title: "配额 8 窗口 / Quota 8 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot8WindowID: String?

    init() {
        presentation = .rings
        quotaCount = nil
        visibility = .primaryOnly
        mode = .singleProvider
        provider = .codex
        accounts = nil
        primaryScope = .automatic
        primaryProvider = .automatic
        primaryAccounts = nil
        primaryWindowID = nil
        secondaryScope = .provider
        secondaryProvider = .codex
        secondaryAccounts = nil
        secondaryWindowID = "spark"
        slot3Scope = .provider
        slot3Provider = .automatic
        slot3Accounts = nil
        slot3WindowID = nil
        slot4Scope = .provider
        slot4Provider = .automatic
        slot4Accounts = nil
        slot4WindowID = nil
        slot5Scope = .provider
        slot5Provider = .automatic
        slot5Accounts = nil
        slot5WindowID = nil
        slot6Scope = .provider
        slot6Provider = .automatic
        slot6Accounts = nil
        slot6WindowID = nil
        slot7Scope = .provider
        slot7Provider = .automatic
        slot7Accounts = nil
        slot7WindowID = nil
        slot8Scope = .provider
        slot8Provider = .automatic
        slot8Accounts = nil
        slot8WindowID = nil
    }

    var widgetQuotaConfiguration: WidgetQuotaConfiguration {
        let legacyProvider = provider.provider ?? .codex
        let resolvedPrimaryProvider = primaryProvider.provider ?? legacyProvider
        let resolvedPrimaryScope: WidgetQuotaScope = primaryScope == .automatic
            ? (accounts?.isEmpty == false ? .accounts : .provider)
            : primaryScope
        let allChannels: [WidgetQuotaChannel] = [
            WidgetQuotaChannel(
                scope: resolvedPrimaryScope,
                provider: resolvedPrimaryProvider,
                accountIDs: primaryAccounts ?? accounts ?? [],
                windowID: primaryWindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: secondaryScope,
                provider: secondaryProvider.provider ?? .codex,
                accountIDs: secondaryAccounts ?? [],
                windowID: secondaryWindowID ?? "spark"
            ),
            WidgetQuotaChannel(
                scope: slot3Scope,
                provider: slot3Provider.provider ?? .codex,
                accountIDs: slot3Accounts ?? [],
                windowID: slot3WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot4Scope,
                provider: slot4Provider.provider ?? .codex,
                accountIDs: slot4Accounts ?? [],
                windowID: slot4WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot5Scope,
                provider: slot5Provider.provider ?? .codex,
                accountIDs: slot5Accounts ?? [],
                windowID: slot5WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot6Scope,
                provider: slot6Provider.provider ?? .codex,
                accountIDs: slot6Accounts ?? [],
                windowID: slot6WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot7Scope,
                provider: slot7Provider.provider ?? .codex,
                accountIDs: slot7Accounts ?? [],
                windowID: slot7WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot8Scope,
                provider: slot8Provider.provider ?? .codex,
                accountIDs: slot8Accounts ?? [],
                windowID: slot8WindowID ?? "weekly"
            )
        ]
        return WidgetQuotaConfiguration(
            presentation: presentation,
            channels: migratedChannels(
                quotaCount: quotaCount,
                legacyVisibility: visibility,
                allChannels: allChannels
            )
        )
    }
}

struct QuotaTimelineWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "CPA 配额时间线 / CPA Timeline"
    static let description = IntentDescription("选择 1–8 条独立配额；小组件会按尺寸和样式显示可容纳的数量。/ Select 1–8 independent quotas; the Widget shows as many as its family and presentation can hold.")

    static var parameterSummary: some ParameterSummary {
        Switch(\.$quotaCount) {
            Case(.one) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                }
            }
            Case(.two) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                }
            }
            Case(.three) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                }
            }
            Case(.four) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                }
            }
            Case(.five) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                }
            }
            Case(.six) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                }
            }
            Case(.seven) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                    \.$slot7Scope
                    \.$slot7Provider
                    \.$slot7Accounts
                    \.$slot7WindowID
                }
            }
            Case(.eight) {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                    \.$secondaryScope
                    \.$secondaryProvider
                    \.$secondaryAccounts
                    \.$secondaryWindowID
                    \.$slot3Scope
                    \.$slot3Provider
                    \.$slot3Accounts
                    \.$slot3WindowID
                    \.$slot4Scope
                    \.$slot4Provider
                    \.$slot4Accounts
                    \.$slot4WindowID
                    \.$slot5Scope
                    \.$slot5Provider
                    \.$slot5Accounts
                    \.$slot5WindowID
                    \.$slot6Scope
                    \.$slot6Provider
                    \.$slot6Accounts
                    \.$slot6WindowID
                    \.$slot7Scope
                    \.$slot7Provider
                    \.$slot7Accounts
                    \.$slot7WindowID
                    \.$slot8Scope
                    \.$slot8Provider
                    \.$slot8Accounts
                    \.$slot8WindowID
                }
            }
            DefaultCase {
                Summary {
                    \.$presentation
                    \.$quotaCount
                    \.$primaryScope
                    \.$primaryProvider
                    \.$primaryAccounts
                    \.$primaryWindowID
                }
            }
        }
    }

    @Parameter(title: "显示方式 / Presentation", default: .timeline)
    var presentation: WidgetQuotaPresentation

    @Parameter(title: "配额数量 / Quota count")
    var quotaCount: WidgetQuotaCount?

    @Parameter(title: "旧配额显示 / Legacy visibility", default: .primaryOnly)
    var visibility: WidgetQuotaVisibility

    @Parameter(title: "时间线服务 / Timeline provider", default: .automatic)
    var provider: WidgetProviderChoice

    @Parameter(title: "时间线账号 / Timeline accounts", optionsProvider: WidgetAccountOptionsProvider())
    var accounts: [String]?

    @Parameter(title: "时间线周期 / Timeline window", default: .automatic)
    var window: WidgetWindowChoice

    @Parameter(title: "配额 1 范围 / Quota 1 scope", default: .automatic)
    var primaryScope: WidgetQuotaScope

    @Parameter(title: "配额 1 服务 / Quota 1 provider", default: .automatic)
    var primaryProvider: WidgetProviderChoice

    @Parameter(title: "配额 1 账号 / Quota 1 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var primaryAccounts: [String]?

    @Parameter(title: "配额 1 窗口 / Quota 1 window", optionsProvider: WidgetWindowOptionsProvider())
    var primaryWindowID: String?

    @Parameter(title: "配额 2 范围 / Quota 2 scope", default: .provider)
    var secondaryScope: WidgetQuotaScope

    @Parameter(title: "配额 2 服务 / Quota 2 provider", default: .codex)
    var secondaryProvider: WidgetProviderChoice

    @Parameter(title: "配额 2 账号 / Quota 2 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var secondaryAccounts: [String]?

    @Parameter(title: "配额 2 窗口 / Quota 2 window", optionsProvider: WidgetWindowOptionsProvider())
    var secondaryWindowID: String?

    @Parameter(title: "配额 3 范围 / Quota 3 scope", default: .provider)
    var slot3Scope: WidgetQuotaScope

    @Parameter(title: "配额 3 服务 / Quota 3 provider", default: .automatic)
    var slot3Provider: WidgetProviderChoice

    @Parameter(title: "配额 3 账号 / Quota 3 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot3Accounts: [String]?

    @Parameter(title: "配额 3 窗口 / Quota 3 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot3WindowID: String?

    @Parameter(title: "配额 4 范围 / Quota 4 scope", default: .provider)
    var slot4Scope: WidgetQuotaScope

    @Parameter(title: "配额 4 服务 / Quota 4 provider", default: .automatic)
    var slot4Provider: WidgetProviderChoice

    @Parameter(title: "配额 4 账号 / Quota 4 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot4Accounts: [String]?

    @Parameter(title: "配额 4 窗口 / Quota 4 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot4WindowID: String?

    @Parameter(title: "配额 5 范围 / Quota 5 scope", default: .provider)
    var slot5Scope: WidgetQuotaScope

    @Parameter(title: "配额 5 服务 / Quota 5 provider", default: .automatic)
    var slot5Provider: WidgetProviderChoice

    @Parameter(title: "配额 5 账号 / Quota 5 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot5Accounts: [String]?

    @Parameter(title: "配额 5 窗口 / Quota 5 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot5WindowID: String?

    @Parameter(title: "配额 6 范围 / Quota 6 scope", default: .provider)
    var slot6Scope: WidgetQuotaScope

    @Parameter(title: "配额 6 服务 / Quota 6 provider", default: .automatic)
    var slot6Provider: WidgetProviderChoice

    @Parameter(title: "配额 6 账号 / Quota 6 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot6Accounts: [String]?

    @Parameter(title: "配额 6 窗口 / Quota 6 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot6WindowID: String?

    @Parameter(title: "配额 7 范围 / Quota 7 scope", default: .provider)
    var slot7Scope: WidgetQuotaScope

    @Parameter(title: "配额 7 服务 / Quota 7 provider", default: .automatic)
    var slot7Provider: WidgetProviderChoice

    @Parameter(title: "配额 7 账号 / Quota 7 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot7Accounts: [String]?

    @Parameter(title: "配额 7 窗口 / Quota 7 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot7WindowID: String?

    @Parameter(title: "配额 8 范围 / Quota 8 scope", default: .provider)
    var slot8Scope: WidgetQuotaScope

    @Parameter(title: "配额 8 服务 / Quota 8 provider", default: .automatic)
    var slot8Provider: WidgetProviderChoice

    @Parameter(title: "配额 8 账号 / Quota 8 accounts", optionsProvider: WidgetAccountOptionsProvider())
    var slot8Accounts: [String]?

    @Parameter(title: "配额 8 窗口 / Quota 8 window", optionsProvider: WidgetWindowOptionsProvider())
    var slot8WindowID: String?

    init() {
        presentation = .timeline
        quotaCount = nil
        visibility = .primaryOnly
        provider = .automatic
        accounts = nil
        window = .automatic
        primaryScope = .automatic
        primaryProvider = .automatic
        primaryAccounts = nil
        primaryWindowID = nil
        secondaryScope = .provider
        secondaryProvider = .codex
        secondaryAccounts = nil
        secondaryWindowID = "spark"
        slot3Scope = .provider
        slot3Provider = .automatic
        slot3Accounts = nil
        slot3WindowID = nil
        slot4Scope = .provider
        slot4Provider = .automatic
        slot4Accounts = nil
        slot4WindowID = nil
        slot5Scope = .provider
        slot5Provider = .automatic
        slot5Accounts = nil
        slot5WindowID = nil
        slot6Scope = .provider
        slot6Provider = .automatic
        slot6Accounts = nil
        slot6WindowID = nil
        slot7Scope = .provider
        slot7Provider = .automatic
        slot7Accounts = nil
        slot7WindowID = nil
        slot8Scope = .provider
        slot8Provider = .automatic
        slot8Accounts = nil
        slot8WindowID = nil
    }

    var widgetQuotaConfiguration: WidgetQuotaConfiguration {
        let legacyProvider = provider.provider ?? .codex
        let resolvedPrimaryProvider = primaryProvider.provider ?? legacyProvider
        let resolvedPrimaryScope: WidgetQuotaScope
        if primaryScope == .automatic {
            resolvedPrimaryScope = accounts?.isEmpty == false
                ? .accounts
                : (provider == .automatic ? .allAccounts : .provider)
        } else {
            resolvedPrimaryScope = primaryScope
        }
        let legacyWindowID: String
        switch window {
        case .automatic: legacyWindowID = "weekly"
        case .short: legacyWindowID = "short"
        case .weekly: legacyWindowID = "weekly"
        }
        let allChannels: [WidgetQuotaChannel] = [
            WidgetQuotaChannel(
                scope: resolvedPrimaryScope,
                provider: resolvedPrimaryProvider,
                accountIDs: primaryAccounts ?? accounts ?? [],
                windowID: primaryWindowID ?? legacyWindowID
            ),
            WidgetQuotaChannel(
                scope: secondaryScope,
                provider: secondaryProvider.provider ?? .codex,
                accountIDs: secondaryAccounts ?? [],
                windowID: secondaryWindowID ?? "spark"
            ),
            WidgetQuotaChannel(
                scope: slot3Scope,
                provider: slot3Provider.provider ?? .codex,
                accountIDs: slot3Accounts ?? [],
                windowID: slot3WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot4Scope,
                provider: slot4Provider.provider ?? .codex,
                accountIDs: slot4Accounts ?? [],
                windowID: slot4WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot5Scope,
                provider: slot5Provider.provider ?? .codex,
                accountIDs: slot5Accounts ?? [],
                windowID: slot5WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot6Scope,
                provider: slot6Provider.provider ?? .codex,
                accountIDs: slot6Accounts ?? [],
                windowID: slot6WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot7Scope,
                provider: slot7Provider.provider ?? .codex,
                accountIDs: slot7Accounts ?? [],
                windowID: slot7WindowID ?? "weekly"
            ),
            WidgetQuotaChannel(
                scope: slot8Scope,
                provider: slot8Provider.provider ?? .codex,
                accountIDs: slot8Accounts ?? [],
                windowID: slot8WindowID ?? "weekly"
            )
        ]
        return WidgetQuotaConfiguration(
            presentation: presentation,
            channels: migratedChannels(
                quotaCount: quotaCount,
                legacyVisibility: visibility,
                allChannels: allChannels
            )
        )
    }
}
