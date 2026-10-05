import Foundation

/// Runs external commands. Commands are resolved on PATH via /usr/bin/env.
enum Shell {
    /// Locate an executable on PATH (equivalent of `command -v`).
    static func which(_ name: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in path.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func process(_ args: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        return process
    }

    /// Run with stdout/stderr passed through to the terminal.
    @discardableResult
    static func run(_ args: [String], discardStderr: Bool = false) -> Int32 {
        let p = process(args)
        if discardStderr {
            p.standardError = FileHandle.nullDevice
        }
        do {
            try p.run()
        } catch {
            return 127
        }
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// Run and capture stdout (plus stderr when `mergeStderr`; otherwise stderr is discarded).
    /// `stdinPath` feeds a file to stdin; otherwise stdin is empty.
    @discardableResult
    static func capture(_ args: [String], stdinPath: String? = nil, mergeStderr: Bool = false) -> (status: Int32, output: String) {
        let p = process(args)
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = mergeStderr ? pipe : FileHandle.nullDevice
        if let stdinPath, let input = FileHandle(forReadingAtPath: stdinPath) {
            p.standardInput = input
        } else {
            p.standardInput = FileHandle.nullDevice
        }
        do {
            try p.run()
        } catch {
            return (127, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Start a process in the background with output discarded; don't wait for it.
    static func spawnDetached(_ args: [String]) {
        let p = process(args)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    /// Equivalent of `<args> 2>&1 | tee <logPath> | <filter>`.
    /// Returns the exit status of `args` (not the filter).
    static func runTee(_ args: [String], logPath: String, filter: [String]) throws -> Int32 {
        guard FileManager.default.createFile(atPath: logPath, contents: nil),
              let log = FileHandle(forWritingAtPath: logPath) else {
            echoError("\(red)Error: could not create build log at \(logPath)\(reset)")
            throw ExitCode(1)
        }

        let source = process(args)
        let sourcePipe = Pipe()
        source.standardOutput = sourcePipe
        source.standardError = sourcePipe

        let sink = process(filter)
        let sinkPipe = Pipe()
        sink.standardInput = sinkPipe

        try sink.run()
        try source.run()
        // Drop our copies of the child-side ends so EOF arrives when the children exit
        try? sourcePipe.fileHandleForWriting.close()
        try? sinkPipe.fileHandleForReading.close()

        let reader = sourcePipe.fileHandleForReading
        let writer = sinkPipe.fileHandleForWriting
        var sinkOpen = true
        while true {
            let chunk = reader.availableData
            if chunk.isEmpty { break }
            try? log.write(contentsOf: chunk)
            if sinkOpen {
                do {
                    try writer.write(contentsOf: chunk)
                } catch {
                    sinkOpen = false
                }
            }
        }
        try? writer.close()
        try? log.close()
        source.waitUntilExit()
        sink.waitUntilExit()
        return source.terminationStatus
    }
}
