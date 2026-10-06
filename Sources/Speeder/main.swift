import AppKit

let application = NSApplication.shared
#if DEBUG
if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
    do {
        try MainActor.assumeIsolated { try PreviewExport.run(directory: CommandLine.arguments[index + 1]) }
        exit(0)
    } catch {
        fputs("Preview export failed: \(error)\n", stderr)
        exit(1)
    }
}
#endif
let delegate = AppDelegate()
application.delegate = delegate
application.run()
