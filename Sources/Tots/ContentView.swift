import AppKit
import SwiftUI

enum ViewMode { case extensions, apps }

struct ContentView: View {
  @StateObject private var scanner = ExtensionScanner()
  @State private var selectedExt: String?
  @State private var selectedAppID: String?
  @State private var mode: ViewMode = .extensions

  var body: some View {
    NavigationSplitView {
      Group {
        switch mode {
        case .extensions: sidebarView
        case .apps: AppsSidebarView(scanner: scanner, selectedAppID: $selectedAppID)
        }
      }
      .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    } detail: {
      switch mode {
      case .extensions: detailView
      case .apps: appsDetailView
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Picker("", selection: $mode) {
          Label("Extensions", systemImage: "doc").tag(ViewMode.extensions)
          Label("Apps", systemImage: "square.grid.2x2").tag(ViewMode.apps)
        }
        .pickerStyle(.segmented)
        .frame(width: 190)
        .labelsHidden()
      }
    }
    .onAppear { scanner.load() }
  }

  private var appsDetailView: some View {
    Group {
      if let id = selectedAppID,
        let app = scanner.appEntries.first(where: { $0.id == id })
      {
        AppDetailView(app: app, scanner: scanner)
      } else {
        ContentUnavailableView(
          "Select an App",
          systemImage: "app.badge",
          description: Text("Choose an app to see which file types it handles.")
        )
      }
    }
  }

  // MARK: - Sidebar

  private var sidebarView: some View {
    VStack(spacing: 0) {
      searchBar
      tagStrip
      if scanner.isLoading {
        loadingView
      } else {
        extensionList
      }
    }
    .navigationTitle("Extensions")
  }

  private var searchBar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search extensions…", text: $scanner.searchText)
          .textFieldStyle(.plain)
        if !scanner.searchText.isEmpty {
          Button {
            scanner.searchText = ""
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

  private var tagStrip: some View {
    VStack(spacing: 0) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(allTags) { tag in
            TagChip(
              tag: tag,
              isSelected: scanner.selectedTags.contains(tag)
            ) {
              withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                if scanner.selectedTags.contains(tag) {
                  scanner.selectedTags.remove(tag)
                } else {
                  scanner.selectedTags.insert(tag)
                }
              }
            }
          }

          if !scanner.selectedTags.isEmpty {
            Button {
              withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                scanner.selectedTags.removeAll()
              }
            } label: {
              Text("Clear")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
      }
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

  private var extensionList: some View {
    List(scanner.filtered, selection: $selectedExt) { entry in
      ExtensionRow(entry: entry)
        .tag(entry.ext)
    }
    .listStyle(.sidebar)
    .animation(.spring(response: 0.28, dampingFraction: 0.85), value: scanner.filtered.map(\.id))
    .overlay(alignment: .bottom) {
      countFooter
    }
  }

  private var countFooter: some View {
    Text("\(scanner.filtered.count) extension\(scanner.filtered.count == 1 ? "" : "s")")
      .font(.caption2)
      .monospacedDigit()
      .foregroundStyle(.tertiary)
      .padding(.bottom, 6)
      .animation(.default, value: scanner.filtered.count)
  }

  // MARK: - Detail

  private var detailView: some View {
    Group {
      if let ext = selectedExt,
        let entry = scanner.entries.first(where: { $0.ext == ext })
      {
        HandlerDetailView(entry: entry) { handler in
          scanner.setDefault(handler, forExtension: ext)
        }
      } else {
        ContentUnavailableView(
          "Select an Extension",
          systemImage: "doc.badge.ellipsis",
          description: Text("Choose a file extension from the list to see which apps handle it.")
        )
      }
    }
  }
}

// MARK: - Tag Chip

struct TagChip: View {
  let tag: FileTag
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: tag.symbol)
          .font(.system(size: 10, weight: .semibold))
        Text(tag.name)
          .font(.caption)
          .fontWeight(.medium)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(isSelected ? Color.accentColor : Color(nsColor: .controlColor))
      .foregroundStyle(isSelected ? Color.white : Color.secondary)
      .clipShape(Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Extension Row

struct ExtensionRow: View {
  let entry: ExtensionEntry

  private var isCommon: Bool {
    allTags.first(where: { $0.id == "common" })?.extensions.contains(entry.ext) ?? false
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(".\(entry.ext)")
        .font(.system(.body, design: .monospaced))
        .fontWeight(.medium)

      if isCommon {
        Image(systemName: "star.fill")
          .font(.system(size: 8))
          .foregroundStyle(.orange.opacity(0.8))
      }

      Spacer()

      Text("\(entry.handlers.count)")
        .font(.caption2)
        .fontWeight(.medium)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary)
        .clipShape(Capsule())
    }
    .padding(.vertical, 1)
  }
}

// MARK: - Handler Detail

struct HandlerDetailView: View {
  let entry: ExtensionEntry
  let setDefault: (HandlerApp) -> Void

  private var entryTags: [FileTag] { tags(for: entry.ext) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      List(entry.handlers) { handler in
        HandlerRow(handler: handler) {
          setDefault(handler)
        }
      }
      .listStyle(.plain)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text(".\(entry.ext)")
          .font(.system(.title2, design: .monospaced))
          .fontWeight(.bold)
        Text("\(entry.handlers.count) handler\(entry.handlers.count == 1 ? "" : "s") registered")
          .foregroundStyle(.secondary)
          .font(.subheadline)
      }

      Spacer()

      if !entryTags.isEmpty {
        HStack(spacing: 4) {
          ForEach(entryTags) { tag in
            HStack(spacing: 3) {
              Image(systemName: tag.symbol)
                .font(.system(size: 9, weight: .semibold))
              Text(tag.name)
                .font(.caption2)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tag.color.opacity(0.12))
            .foregroundStyle(tag.color)
            .clipShape(Capsule())
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

// MARK: - Handler Row

struct HandlerRow: View {
  let handler: HandlerApp
  let setDefault: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 12) {
      Image(nsImage: handler.icon)
        .resizable()
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(handler.name)
            .font(.body)
            .fontWeight(handler.isDefault ? .semibold : .regular)
          if handler.isDefault {
            Text("Default")
              .font(.caption2)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.accentColor)
              .clipShape(Capsule())
          }
        }
        Text(handler.bundleURL.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      if isHovered && !handler.isDefault {
        Button("Set as Default") {
          setDefault()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
      } else if isHovered {
        Button("Show in Finder") {
          NSWorkspace.shared.activateFileViewerSelecting([handler.bundleURL])
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .onHover { over in
      withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
        isHovered = over
      }
    }
    .contextMenu {
      if !handler.isDefault {
        Button("Set as Default") { setDefault() }
        Divider()
      }
      Button("Show in Finder") {
        NSWorkspace.shared.activateFileViewerSelecting([handler.bundleURL])
      }
      Button("Open App") {
        NSWorkspace.shared.openApplication(at: handler.bundleURL, configuration: .init())
      }
    }
  }
}
