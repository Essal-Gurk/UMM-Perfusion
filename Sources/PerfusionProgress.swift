import Foundation
import IsiXPluginKit

// The SDK needs rendered strings. Retain the original message for our own UI.
final class PerfusionProgressMessages: @unchecked Sendable {
    private let lock = NSLock()
    private var value: PerfusionText?

    var latest: PerfusionText? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func update(_ message: PerfusionText) {
        lock.lock()
        defer { lock.unlock() }
        value = message
    }
}

struct PerfusionProgress: Sendable {
    let host: IsiXTaskProgress
    let messages: PerfusionProgressMessages

    var isCancelled: Bool { host.isCancelled }

    func report(_ fraction: Double, message: PerfusionText) {
        messages.update(message)
        host.report(fraction, message: message.rendered())
    }
}
