import SwiftUI

struct FileTag: Identifiable, Hashable {
  let id: String
  let name: String
  let symbol: String
  let color: Color
  let extensions: Set<String>

  func hash(into hasher: inout Hasher) { hasher.combine(id) }
  static func == (lhs: FileTag, rhs: FileTag) -> Bool { lhs.id == rhs.id }
}

let allTags: [FileTag] = [
  FileTag(
    id: "common", name: "Common", symbol: "star.fill", color: .orange,
    extensions: [
      "pdf", "jpg", "jpeg", "png", "gif", "mp4", "mov", "mp3", "aac", "m4a",
      "zip", "txt", "md", "csv", "json", "doc", "docx", "xls", "xlsx", "pptx",
      "heic", "webp", "svg", "html", "xml", "dmg", "pkg",
    ]),
  FileTag(
    id: "images", name: "Images", symbol: "photo", color: .blue,
    extensions: [
      "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "svg", "webp",
      "heic", "heif", "raw", "psd", "ai", "eps", "ico", "avif", "jxl",
    ]),
  FileTag(
    id: "video", name: "Video", symbol: "film", color: .purple,
    extensions: [
      "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm",
      "ts", "mts", "m2ts", "vob", "ogv",
    ]),
  FileTag(
    id: "audio", name: "Audio", symbol: "waveform", color: .pink,
    extensions: [
      "mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff",
      "aif", "opus", "alac", "mid", "midi", "caf",
    ]),
  FileTag(
    id: "documents", name: "Documents", symbol: "doc.text", color: .indigo,
    extensions: [
      "pdf", "txt", "rtf", "doc", "docx", "odt", "pages",
      "md", "markdown", "tex", "epub", "mobi",
      "pptx", "ppt", "odp", "key", "numbers", "xls", "xlsx", "ods",
    ]),
  FileTag(
    id: "data", name: "Data", symbol: "cylinder", color: .teal,
    extensions: [
      "json", "xml", "plist", "yaml", "yml", "toml", "sql",
      "db", "sqlite", "sqlite3", "csv", "tsv", "parquet", "arrow",
    ]),
  FileTag(
    id: "archives", name: "Archives", symbol: "archivebox", color: .brown,
    extensions: [
      "zip", "tar", "gz", "bz2", "rar", "7z", "dmg", "pkg",
      "xz", "tgz", "tbz2", "cab", "iso", "jar", "deb", "rpm",
    ]),
  FileTag(
    id: "code", name: "Code", symbol: "chevron.left.forwardslash.chevron.right", color: .green,
    extensions: [
      "swift", "py", "js", "ts", "jsx", "tsx", "html", "htm",
      "css", "scss", "sass", "rb", "go", "rs", "c", "cpp", "h", "hpp",
      "java", "sh", "bash", "zsh", "fish", "php", "kt", "m", "mm",
      "vue", "r", "lua", "dart", "ex", "exs", "cs", "fs", "zig",
    ]),
  FileTag(
    id: "fonts", name: "Fonts", symbol: "textformat", color: .gray,
    extensions: [
      "ttf", "otf", "woff", "woff2", "eot", "pfb", "pfm",
    ]),
  FileTag(
    id: "3d", name: "3D", symbol: "cube", color: .cyan,
    extensions: [
      "obj", "fbx", "stl", "blend", "usdz", "usd", "glb", "gltf", "dae", "3ds", "ply",
    ]),
]

func tags(for ext: String) -> [FileTag] {
  allTags.filter { $0.extensions.contains(ext) }
}
