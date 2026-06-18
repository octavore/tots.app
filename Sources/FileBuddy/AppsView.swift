import AppKit
import SwiftUI

// MARK: - Apps Sidebar

struct AppsSidebarView: View {
  @ObservedObject var scanner: ExtensionScanner
  @Binding var selectedAppID: String?

  var body: some View {
    VStack(spacing: 0) {
      searchBar
      if scanner.isLoading {
        loadingView
      } else {
        appList
      }
    }
    .navigationTitle("Apps")
  }

  private var searchBar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search apps…", text: $scanner.appSearchText)
          .textFieldStyle(.plain)
        if !scanner.appSearchText.isEmpty {
          Button {
            scanner.appSearchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      Divider()
    }
  }

  private var loadingView: some View {
    VStack(spacing: 10) {
      ProgressView()
      Text("Scanning installed apps…")
        .foregroundStyle(.secondary)
        .font(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var appList: some View {
    List(scanner.filteredApps, selection: $selectedAppID) { app in
      AppRow(app: app)
        .tag(app.id)
    }
    .listStyle(.sidebar)
    .animation(
      .spring(response: 0.28, dampingFraction: 0.85), value: scanner.filteredApps.map(\.id)
    )
    .overlay(alignment: .bottom) {
      Text("\(scanner.filteredApps.count) app\(scanner.filteredApps.count == 1 ? "" : "s")")
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .padding(.bottom, 6)
    }
  }
}

// MARK: - App Row

struct AppRow: View {
  let app: AppEntry

  var body: some View {
    HStack(spacing: 9) {
      Image(nsImage: app.icon)
        .resizable()
        .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 1) {
        Text(app.name)
          .font(.body)
          .lineLimit(1)

        HStack(spacing: 4) {
          if !app.defaultExtensions.isEmpty {
            Text("Default for \(app.defaultExtensions.count)")
              .foregroundStyle(.secondary)
          }
          if !app.defaultExtensions.isEmpty && !app.otherExtensions.isEmpty {
            Text("·").foregroundStyle(.tertiary)
          }
          if !app.otherExtensions.isEmpty {
            Text("\(app.handledExtensions.count) total")
              .foregroundStyle(.tertiary)
          }
        }
        .font(.caption)
        .monospacedDigit()
      }
    }
    .padding(.vertical, 2)
  }
}

// MARK: - App Detail

struct AppDetailView: View {
  let app: AppEntry
  @ObservedObject var scanner: ExtensionScanner

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      extensionList
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(nsImage: app.icon)
        .resizable()
        .frame(width: 52, height: 52)

      VStack(alignment: .leading, spacing: 3) {
        Text(app.name)
          .font(.title2)
          .fontWeight(.bold)
        if let bid = app.bundleID {
          Text(bid)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Text(app.bundleURL.path)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      Button("Show in Finder") {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private var extensionList: some View {
    List {
      if !app.defaultExtensions.isEmpty {
        Section(
          "Default for \(app.defaultExtensions.count) type\(app.defaultExtensions.count == 1 ? "" : "s")"
        ) {
          ForEach(app.defaultExtensions) { ext in
            HandledExtRow(ext: ext, currentDefault: nil, setAsDefault: nil)
          }
        }
      }

      if !app.otherExtensions.isEmpty {
        Section(
          "Also handles \(app.otherExtensions.count) type\(app.otherExtensions.count == 1 ? "" : "s")"
        ) {
          ForEach(app.otherExtensions) { ext in
            let entry = scanner.entries.first(where: { $0.ext == ext.ext })
            let currentDefault = entry?.handlers.first(where: { $0.isDefault })
            let thisHandler = entry?.handlers.first(where: { $0.bundleURL == app.bundleURL })
            HandledExtRow(
              ext: ext,
              currentDefault: currentDefault,
              setAsDefault: thisHandler.map { handler in
                { scanner.setDefault(handler, forExtension: ext.ext) }
              }
            )
          }
        }
      }
    }
    .listStyle(.inset)
    .id(app.id)
  }
}

// MARK: - Handled Extension Row

struct HandledExtRow: View {
  let ext: HandledExtension
  let currentDefault: HandlerApp?
  let setAsDefault: (() -> Void)?

  @State private var isHovered = false

  private var extTags: [FileTag] { tags(for: ext.ext) }

  var body: some View {
    HStack(spacing: 10) {
      Text(".\(ext.ext)")
        .font(.system(.body, design: .monospaced))
        .fontWeight(.medium)
        .frame(minWidth: 60, alignment: .leading)

      if ext.isDefault {
        Text("Default")
          .font(.caption2)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.accentColor)
          .clipShape(Capsule())
      }

      if let def = currentDefault {
        HStack(spacing: 4) {
          Image(nsImage: def.icon)
            .resizable()
            .frame(width: 14, height: 14)
          Text(def.name)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      ZStack(alignment: .trailing) {
        HStack(spacing: 4) {
          ForEach(extTags) { tag in
            HStack(spacing: 3) {
              Image(systemName: tag.symbol)
                .font(.system(size: 9, weight: .semibold))
              Text(tag.name)
                .font(.caption2)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlColor))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
          }
        }
        .opacity(isHovered && setAsDefault != nil ? 0 : 1)

        if let action = setAsDefault {
          Button("Set as Default", action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
      }
    }
    .padding(.vertical, 3)
    .contentShape(Rectangle())
    .onHover { over in
      withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
        isHovered = over
      }
    }
  }
}
