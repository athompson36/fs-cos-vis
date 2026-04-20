import Foundation

/// Pure helpers for inbound DMX coalescing and merge into software-built buffers (used by `AppModel` and unit tests).
enum DMXInboundMergeLogic {
    /// Seconds; inbound frames older than this are ignored when merging into output, and priority arbitration uses this window.
    static let defaultStaleWindow: TimeInterval = 3

    /// When multiple packets target the same universe, keep the higher E1.31 **priority** if the previous frame is still "fresh".
    /// If the previous frame is stale, always accept. Equal or higher new priority replaces the stored frame.
    static func shouldStoreNewInboundFrame(
        existingReceivedAt: CFAbsoluteTime,
        existingPriority: UInt8,
        newPriority: UInt8,
        now: CFAbsoluteTime,
        staleWindow: TimeInterval = defaultStaleWindow
    ) -> Bool {
        let fresh = now - existingReceivedAt <= staleWindow
        if fresh, newPriority < existingPriority { return false }
        return true
    }

    static func isFrameFresh(receivedAt: CFAbsoluteTime, now: CFAbsoluteTime, staleWindow: TimeInterval = defaultStaleWindow) -> Bool {
        now - receivedAt <= staleWindow
    }

    /// HTP: per-channel max of software vs inbound.
    static func applyHTPMerge(software: inout [UInt8], inbound: [UInt8]) {
        precondition(software.count == 512 && inbound.count == 512)
        for i in 0 ..< 512 {
            software[i] = max(software[i], inbound[i])
        }
    }

    /// LTP / "latest frame wins" for the whole universe (matches Settings label for inbound merge).
    static func applyLTPMergeReplaceUniverse(software: inout [UInt8], inbound: [UInt8]) {
        precondition(inbound.count == 512)
        software = inbound
    }
}
