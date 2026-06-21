import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

struct HandlerApp: Identifiable {
  let id = UUID()
  let name: String
  let bundleURL: URL
  let bundleID: String?
  let icon: NSImage
  var isDefault: Bool
}

struct ExtensionEntry: Identifiable {
  var id: String { ext }
  let ext: String
  var handlers: [HandlerApp]
}

struct HandledExtension: Identifiable {
  var id: String { ext }
  let ext: String
  let isDefault: Bool
}

struct AppEntry: Identifiable {
  var id: String { bundleURL.path }
  let name: String
  let bundleURL: URL
  let bundleID: String?
  let icon: NSImage
  let handledExtensions: [HandledExtension]

  var defaultExtensions: [HandledExtension] { handledExtensions.filter(\.isDefault) }
  var otherExtensions: [HandledExtension] { handledExtensions.filter { !$0.isDefault } }
}

@MainActor
final class ExtensionScanner: ObservableObject {
  @Published var entries: [ExtensionEntry] = []
  @Published var isLoading = false
  @Published var searchText = ""
  @Published var selectedTags: Set<FileTag> = []
  @Published var appSearchText = ""

  var filtered: [ExtensionEntry] {
    var result = entries
    if !searchText.isEmpty {
      result = result.filter { $0.ext.localizedCaseInsensitiveContains(searchText) }
    }
    if !selectedTags.isEmpty {
      result = result.filter { entry in
        selectedTags.contains { $0.extensions.contains(entry.ext) }
      }
    }
    return result
  }

  var appEntries: [AppEntry] {
    var nameMap: [URL: String] = [:]
    var bundleIDMap: [URL: String?] = [:]
    var iconMap: [URL: NSImage] = [:]
    var extMap: [URL: [(String, Bool)]] = [:]

    for entry in entries {
      for handler in entry.handlers {
        let url = handler.bundleURL
        if nameMap[url] == nil {
          nameMap[url] = handler.name
          bundleIDMap[url] = handler.bundleID
          iconMap[url] = handler.icon
        }
        extMap[url, default: []].append((entry.ext, handler.isDefault))
      }
    }

    return nameMap.keys.compactMap { url -> AppEntry? in
      guard let name = nameMap[url], let icon = iconMap[url] else { return nil }
      let exts = (extMap[url] ?? [])
        .map { HandledExtension(ext: $0.0, isDefault: $0.1) }
        .sorted {
          if $0.isDefault != $1.isDefault { return $0.isDefault }
          return $0.ext < $1.ext
        }
      return AppEntry(
        name: name, bundleURL: url, bundleID: bundleIDMap[url] ?? nil, icon: icon,
        handledExtensions: exts)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  var filteredApps: [AppEntry] {
    guard !appSearchText.isEmpty else { return appEntries }
    return appEntries.filter { $0.name.localizedCaseInsensitiveContains(appSearchText) }
  }

  func load() {
    guard !isLoading && entries.isEmpty else { return }
    isLoading = true
    Task {
      let rawMap: [String: Set<URL>] = await Task.detached(priority: .userInitiated) {
        scanAppBundles()
      }.value

      var result: [ExtensionEntry] = []
      for (ext, appURLs) in rawMap.sorted(by: { $0.key < $1.key }) {
        let defaultURL = resolveDefaultURL(forExtension: ext)

        let handlers: [HandlerApp] = appURLs.map { url in
          HandlerApp(
            name: url.deletingPathExtension().lastPathComponent,
            bundleURL: url,
            bundleID: Bundle(url: url)?.bundleIdentifier,
            icon: NSWorkspace.shared.icon(forFile: url.path),
            isDefault: url.standardizedFileURL == defaultURL?.standardizedFileURL
          )
        }.sorted(by: handlerOrder)

        result.append(ExtensionEntry(ext: ext, handlers: handlers))
      }

      self.entries = result
      self.isLoading = false
    }
  }

  func setDefault(_ handler: HandlerApp, forExtension ext: String) {
    guard let bundleID = handler.bundleID,
      let utiID = UTType(filenameExtension: ext)?.identifier
    else { return }
    LSSetDefaultRoleHandlerForContentType(utiID as CFString, .all, bundleID as CFString)
    refreshDefault(forExtension: ext)
  }

  private func refreshDefault(forExtension ext: String) {
    guard let idx = entries.firstIndex(where: { $0.ext == ext }) else { return }
    let defaultURL = resolveDefaultURL(forExtension: ext)
    entries[idx].handlers = entries[idx].handlers
      .map { h in
        var updated = h
        updated.isDefault = h.bundleURL.standardizedFileURL == defaultURL?.standardizedFileURL
        return updated
      }
      .sorted(by: handlerOrder)
  }

  private func resolveDefaultURL(forExtension ext: String) -> URL? {
    guard let utiID = UTType(filenameExtension: ext)?.identifier else { return nil }
    return LSCopyDefaultApplicationURLForContentType(utiID as CFString, .all, nil)
      .map { $0.takeRetainedValue() as URL }
  }

  private func handlerOrder(_ a: HandlerApp, _ b: HandlerApp) -> Bool {
    if a.isDefault != b.isDefault { return a.isDefault }
    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
  }
}

private func scanAppBundles() -> [String: Set<URL>] {
  let searchDirs: [String] = [
    "/Applications",
    "/System/Applications",
    NSHomeDirectory() + "/Applications",
  ]

  var map: [String: Set<URL>] = [:]

  for dir in searchDirs {
    let dirURL = URL(fileURLWithPath: dir)
    guard
      let items = try? FileManager.default.contentsOfDirectory(
        at: dirURL, includingPropertiesForKeys: [.isDirectoryKey]
      )
    else { continue }

    for item in items {
      if item.pathExtension == "app" {
        extractExtensions(from: item, into: &map)
      } else {
        let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        guard isDir else { continue }
        guard
          let sub = try? FileManager.default.contentsOfDirectory(
            at: item, includingPropertiesForKeys: nil
          )
        else { continue }
        for subItem in sub where subItem.pathExtension == "app" {
          extractExtensions(from: subItem, into: &map)
        }
      }
    }
  }

  return map
}

private func extractExtensions(from appURL: URL, into map: inout [String: Set<URL>]) {
  let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
  guard let plist = NSDictionary(contentsOf: plistURL),
    let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]]
  else { return }

  for docType in docTypes {
    let rank = docType["LSHandlerRank"] as? String ?? "Default"
    guard rank != "None" else { continue }

    // Explicit extension list
    let explicit = (docType["CFBundleTypeExtensions"] as? [String]) ?? []

    // UTI-based types — resolve each UTI to its preferred file extensions
    let fromUTIs = ((docType["LSItemContentTypes"] as? [String]) ?? [])
      .flatMap { utiID -> [String] in
        UTType(utiID)?.tags[.filenameExtension] ?? []
      }

    for ext in explicit + fromUTIs {
      let normalized = ext.lowercased().trimmingCharacters(in: .whitespaces)
      guard !normalized.isEmpty, normalized.count < 24 else { continue }
      map[normalized, default: []].insert(appURL)
    }
  }
}
