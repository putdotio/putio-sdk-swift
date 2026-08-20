import Foundation

open class PutioAccount: Decodable {
  open var id: Int
  open var username: String
  open var mail: String
  open var avatarURL: String
  open var hash: String
  open var features: [String: Bool]
  open var downloadToken: String
  open var trashSize: Int64
  open var accountActive: Bool
  open var filesWillBeDeletedAt: String
  open var passwordLastChangedAt: String

  public class Disk: Decodable {
    open var available: Int64
    open var size: Int64
    open var used: Int64

    enum CodingKeys: String, CodingKey {
      case available = "avail"
      case size
      case used
    }

    public required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.available = try container.decode(Int64.self, forKey: .available)
      self.size = try container.decode(Int64.self, forKey: .size)
      self.used = try container.decode(Int64.self, forKey: .used)
    }
  }

  open var disk: Disk

  public class Settings: Decodable {
    open var routeName: String
    open var suggestNextVideo: Bool
    open var rememberVideoTime: Bool
    open var historyEnabled: Bool
    open var trashEnabled: Bool
    open var sortBy: String
    open var showOptimisticUsage: Bool
    open var twoFactorEnabled: Bool
    open var hideSubtitles: Bool
    open var dontAutoSelectSubtitles: Bool

    enum CodingKeys: String, CodingKey {
      case routeName = "tunnel_route_name"
      case suggestNextVideo = "next_episode"
      case rememberVideoTime = "start_from"
      case historyEnabled = "history_enabled"
      case trashEnabled = "trash_enabled"
      case sortBy = "sort_by"
      case showOptimisticUsage = "show_optimistic_usage"
      case twoFactorEnabled = "two_factor_enabled"
      case hideSubtitles = "hide_subtitles"
      case dontAutoSelectSubtitles = "dont_autoselect_subtitles"
    }

    public required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let routeName = try container.decodeIfPresent(String.self, forKey: .routeName) ?? ""
      self.routeName = routeName.isEmpty ? "default" : routeName
      self.suggestNextVideo =
        try container.decodeIfPresent(Bool.self, forKey: .suggestNextVideo) ?? false
      self.rememberVideoTime =
        try container.decodeIfPresent(Bool.self, forKey: .rememberVideoTime) ?? false
      self.historyEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? false
      self.trashEnabled = try container.decodeIfPresent(Bool.self, forKey: .trashEnabled) ?? false
      self.sortBy = try container.decodeIfPresent(String.self, forKey: .sortBy) ?? ""
      self.showOptimisticUsage =
        try container.decodeIfPresent(Bool.self, forKey: .showOptimisticUsage) ?? false
      self.twoFactorEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .twoFactorEnabled) ?? false
      self.hideSubtitles = try container.decodeIfPresent(Bool.self, forKey: .hideSubtitles) ?? false
      self.dontAutoSelectSubtitles =
        try container.decodeIfPresent(Bool.self, forKey: .dontAutoSelectSubtitles) ?? false
    }
  }

  open var settings: Settings

  enum CodingKeys: String, CodingKey {
    case id = "user_id"
    case username
    case mail
    case avatarURL = "avatar_url"
    case hash = "user_hash"
    case features
    case downloadToken = "download_token"
    case trashSize = "trash_size"
    case accountActive = "account_active"
    case filesWillBeDeletedAt = "files_will_be_deleted_at"
    case passwordLastChangedAt = "password_last_changed_at"
    case disk
    case settings
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.username = try container.decode(String.self, forKey: .username)
    self.mail = try container.decode(String.self, forKey: .mail)
    self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL) ?? ""
    self.hash = try container.decodeIfPresent(String.self, forKey: .hash) ?? ""
    self.features = try container.decodeIfPresent([String: Bool].self, forKey: .features) ?? [:]
    self.downloadToken = try container.decodeIfPresent(String.self, forKey: .downloadToken) ?? ""
    self.trashSize = try container.decodeIfPresent(Int64.self, forKey: .trashSize) ?? 0
    self.accountActive = try container.decodeIfPresent(Bool.self, forKey: .accountActive) ?? false
    self.filesWillBeDeletedAt =
      try container.decodeIfPresent(String.self, forKey: .filesWillBeDeletedAt) ?? ""
    self.passwordLastChangedAt =
      try container.decodeIfPresent(String.self, forKey: .passwordLastChangedAt) ?? ""
    self.disk = try container.decode(Disk.self, forKey: .disk)
    self.settings = try container.decode(Settings.self, forKey: .settings)
  }
}

// Public API surface; renaming to lowerCamelCase is a breaking change deferred
// to the next major release.
// swift-format-ignore: AlwaysUseLowerCamelCase
public var PutioClearDataOptionKeys = [
  "files",
  "finished_transfers",
  "active_transfers",
  "rss_feeds",
  "rss_logs",
  "history",
  "trash",
  "friends",
]

public struct PutioAccountInfoQuery {
  public let downloadToken: Bool
  public let features: Bool
  public let intercom: Bool
  public let pas: Bool
  public let platform: String?
  public let profitwell: Bool
  public let pushToken: Bool

  public init(
    downloadToken: Bool = false,
    features: Bool = false,
    intercom: Bool = false,
    pas: Bool = false,
    platform: String? = nil,
    profitwell: Bool = false,
    pushToken: Bool = false
  ) {
    self.downloadToken = downloadToken
    self.features = features
    self.intercom = intercom
    self.pas = pas
    self.platform = platform
    self.profitwell = profitwell
    self.pushToken = pushToken
  }

  var parameters: PutioRequestParameters {
    var query: PutioRequestParameters = [:]
    if downloadToken { query["download_token"] = 1 }
    if features { query["features"] = 1 }
    if intercom { query["intercom"] = 1 }
    if pas { query["pas"] = 1 }
    if let platform { query["platform"] = .string(platform) }
    if profitwell { query["profitwell"] = 1 }
    if pushToken { query["push_token"] = 1 }
    return query
  }
}

public struct PutioAccountSettingsPatch {
  public let historyEnabled: Bool?
  public let trashEnabled: Bool?
  public let hideSubtitles: Bool?
  public let dontAutoSelectSubtitles: Bool?
  public let tunnelRouteName: String?
  public let showOptimisticUsage: Bool?
  public let sortBy: String?

  public init(
    historyEnabled: Bool? = nil,
    trashEnabled: Bool? = nil,
    hideSubtitles: Bool? = nil,
    dontAutoSelectSubtitles: Bool? = nil,
    tunnelRouteName: String? = nil,
    showOptimisticUsage: Bool? = nil,
    sortBy: String? = nil
  ) {
    self.historyEnabled = historyEnabled
    self.trashEnabled = trashEnabled
    self.hideSubtitles = hideSubtitles
    self.dontAutoSelectSubtitles = dontAutoSelectSubtitles
    self.tunnelRouteName = tunnelRouteName
    self.showOptimisticUsage = showOptimisticUsage
    self.sortBy = sortBy
  }

  var parameters: PutioRequestParameters {
    var body: PutioRequestParameters = [:]
    if let historyEnabled { body["history_enabled"] = .bool(historyEnabled) }
    if let trashEnabled { body["trash_enabled"] = .bool(trashEnabled) }
    if let hideSubtitles { body["hide_subtitles"] = .bool(hideSubtitles) }
    if let dontAutoSelectSubtitles {
      body["dont_autoselect_subtitles"] = .bool(dontAutoSelectSubtitles)
    }
    if let tunnelRouteName { body["tunnel_route_name"] = .string(tunnelRouteName) }
    if let showOptimisticUsage { body["show_optimistic_usage"] = .bool(showOptimisticUsage) }
    if let sortBy { body["sort_by"] = .string(sortBy) }
    return body
  }
}

public struct PutioTwoFactorSettings {
  public let code: String
  public let enable: Bool

  public init(code: String, enable: Bool) {
    self.code = code
    self.enable = enable
  }

  var parameters: PutioRequestParameters {
    [
      "code": .string(code),
      "enable": .bool(enable),
    ]
  }
}

public enum PutioAccountSettingsUpdate {
  case patch(PutioAccountSettingsPatch)
  case username(String)
  case mail(currentPassword: String, mail: String)
  case password(currentPassword: String, password: String)
  case twoFactor(PutioTwoFactorSettings)

  var parameters: PutioRequestParameters {
    switch self {
    case .patch(let patch):
      return patch.parameters
    case .username(let username):
      return ["username": .string(username)]
    case .mail(let currentPassword, let mail):
      return [
        "current_password": .string(currentPassword),
        "mail": .string(mail),
      ]
    case .password(let currentPassword, let password):
      return [
        "current_password": .string(currentPassword),
        "password": .string(password),
      ]
    case .twoFactor(let settings):
      return ["two_factor_enabled": .object(settings.parameters)]
    }
  }
}

public struct PutioAccountClearOptions {
  public let files: Bool
  public let finishedTransfers: Bool
  public let activeTransfers: Bool
  public let rssFeeds: Bool
  public let rssLogs: Bool
  public let history: Bool
  public let trash: Bool
  public let friends: Bool

  public init(
    files: Bool = false,
    finishedTransfers: Bool = false,
    activeTransfers: Bool = false,
    rssFeeds: Bool = false,
    rssLogs: Bool = false,
    history: Bool = false,
    trash: Bool = false,
    friends: Bool = false
  ) {
    self.files = files
    self.finishedTransfers = finishedTransfers
    self.activeTransfers = activeTransfers
    self.rssFeeds = rssFeeds
    self.rssLogs = rssLogs
    self.history = history
    self.trash = trash
    self.friends = friends
  }

  var parameters: PutioRequestParameters {
    [
      "files": .bool(files),
      "finished_transfers": .bool(finishedTransfers),
      "active_transfers": .bool(activeTransfers),
      "rss_feeds": .bool(rssFeeds),
      "rss_logs": .bool(rssLogs),
      "history": .bool(history),
      "trash": .bool(trash),
      "friends": .bool(friends),
    ]
  }
}
