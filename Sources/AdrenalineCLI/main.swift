import AdrenalineCore
import Darwin
import Foundation

let usage = """
usage: adrenaline status
       adrenaline hold [--reason TEXT] -- COMMAND [ARGS...]   keep awake while COMMAND runs
       adrenaline hold [--reason TEXT] --pid PID              keep awake until PID exits
       adrenaline hold [--reason TEXT]                        keep awake until interrupted

Talks to the running Adrenaline app over \(HoldSocket.defaultPath).
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("adrenaline: \(message)\n".utf8))
    exit(code)
}

func connect() -> HoldSocketClient {
    do {
        return try HoldSocketClient()
    } catch {
        fail("cannot reach Adrenaline (is the app running?): \(error.localizedDescription)")
    }
}

func printJSON(_ object: [String: Any]) {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    print(String(decoding: data, as: UTF8.self))
}

func hold(_ arguments: [String]) -> Never {
    var reason: String?
    var pid: Int32?
    var command: [String] = []
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--reason":
            index += 1
            guard index < arguments.count else { fail("--reason needs a value") }
            reason = arguments[index]
        case "--pid":
            index += 1
            guard index < arguments.count, let value = Int32(arguments[index]) else { fail("--pid needs a number") }
            pid = value
        case "--":
            command = Array(arguments[(index + 1)...])
            index = arguments.count
        default:
            fail("unexpected argument \(argument)\n\(usage)", code: 2)
        }
        index += 1
    }
    if pid != nil, !command.isEmpty { fail("use either --pid or a command, not both", code: 2) }

    let client = connect()
    var request: [String: Any] = ["cmd": "hold"]
    request["reason"] = reason ?? command.first.map { "adrenaline hold \($0)" }
    if let pid { request["pid"] = pid }
    do {
        let response = try client.request(request)
        guard response["ok"] as? Bool == true else { fail("hold refused: \(response["error"] ?? "unknown error")") }
    } catch {
        fail("hold failed: \(error.localizedDescription)")
    }

    // The hold lasts as long as this process keeps the socket open.
    if !command.isEmpty {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        signal(SIGINT, SIG_IGN) // the child gets terminal signals itself
        do {
            try process.run()
        } catch {
            fail("cannot run \(command[0]): \(error.localizedDescription)", code: 127)
        }
        process.waitUntilExit()
        exit(process.terminationReason == .uncaughtSignal ? 128 + process.terminationStatus : process.terminationStatus)
    }

    if let pid {
        guard kill(pid, 0) == 0 || errno == EPERM else { fail("no such process \(pid)") }
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { exit(0) }
        source.resume()
    }
    for sig in [SIGINT, SIGTERM] {
        signal(sig, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler { exit(0) }
        source.resume()
        signalSources.append(source)
    }
    dispatchMain()
}

var signalSources: [DispatchSourceSignal] = []
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "status":
    do {
        let response = try connect().request(["cmd": "status"])
        printJSON(response)
        exit(response["ok"] as? Bool == true ? 0 : 1)
    } catch {
        fail("status failed: \(error.localizedDescription)")
    }
case "hold":
    hold(Array(arguments.dropFirst()))
case "-h", "--help", "help":
    print(usage)
default:
    fail(usage, code: 2)
}
