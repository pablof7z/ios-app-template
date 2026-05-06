import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "NostrRelayService")

// MARK: - Protocol constants

private enum NostrProtocol {
    /// NIP-01 client-to-relay subscription command.
    static let requestCommand = "REQ"
    /// NIP-01 relay-to-client event envelope type.
    static let eventMessage = "EVENT"
    /// Nostr kind for plain-text notes (the only kind this service processes).
    static let kindTextNote = 1
    /// Minimum array length for a valid relay EVENT message: ["EVENT", <subID>, <event>].
    static let minEventArrayCount = 3
    /// Index of the event object within an EVENT array.
    static let eventIndex = 2
    /// Subscription ID used when requesting the agent's incoming DMs.
    static let subscriptionID = "agent-inbox"
    /// Seconds to wait before attempting a reconnect after a WebSocket error.
    static let reconnectDelay: Duration = .seconds(5)
}

/// Connects to a configured Nostr relay and gates incoming kind:1 messages
/// through the access-control layer, queuing unknown senders for user approval.
@MainActor
final class NostrRelayService {
    private let store: AppStateStore
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var connectedRelayURL: String?

    /// Creates a new service backed by the given state store.
    init(store: AppStateStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    /// Reads the current Nostr settings and connects to the configured relay,
    /// or stops the service if Nostr is disabled or misconfigured.
    func start() {
        let settings = store.state.settings
        guard settings.nostrEnabled,
              let pubkeyHex = settings.nostrPublicKeyHex, !pubkeyHex.isEmpty,
              !settings.nostrRelayURL.isEmpty else {
            stop()
            return
        }
        guard connectedRelayURL != settings.nostrRelayURL || webSocketTask == nil else { return }
        stop()
        connect(urlString: settings.nostrRelayURL, agentPubkey: pubkeyHex)
    }

    /// Cancels the receive loop and closes the WebSocket connection.
    func stop() {
        receiveLoop?.cancel()
        receiveLoop = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectedRelayURL = nil
    }

    // MARK: - Connection

    private func connect(urlString: String, agentPubkey: String) {
        guard let url = URL(string: urlString) else {
            logger.error("NostrRelayService: invalid relay URL '\(urlString, privacy: .public)'")
            return
        }
        connectedRelayURL = urlString
        logger.info("NostrRelayService: connecting to \(urlString, privacy: .public)")
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        sendSubscription(agentPubkey: agentPubkey)
        startReceiveLoop(agentPubkey: agentPubkey)
    }

    private func sendSubscription(agentPubkey: String) {
        let filter: [String: Any] = [
            "kinds": [NostrProtocol.kindTextNote],
            "#p": [agentPubkey],
        ]
        let message: [Any] = [NostrProtocol.requestCommand, NostrProtocol.subscriptionID, filter]
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let text = String(data: data, encoding: .utf8) else {
                logger.error("sendSubscription: failed to encode REQ as UTF-8 string")
                return
            }
            webSocketTask?.send(.string(text)) { _ in }
        } catch {
            logger.error("sendSubscription: JSON serialization failed — \(error, privacy: .public)")
        }
    }

    private func startReceiveLoop(agentPubkey: String) {
        receiveLoop = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let task = self.webSocketTask else { return }
                do {
                    let msg = try await task.receive()
                    if case .string(let text) = msg { self.handle(text: text) }
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.warning("NostrRelayService: WebSocket error — \(error, privacy: .public); reconnecting in \(NostrProtocol.reconnectDelay)")
                    // Cancellation is checked immediately after; swallowing the sleep-cancel error is intentional.
                    try? await Task.sleep(for: NostrProtocol.reconnectDelay)
                    guard !Task.isCancelled else { return }
                    self.start()
                    return
                }
            }
        }
    }

    // MARK: - Event handling

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              array.count >= NostrProtocol.minEventArrayCount,
              let msgType = array[0] as? String, msgType == NostrProtocol.eventMessage,
              let event = array[NostrProtocol.eventIndex] as? [String: Any],
              let kind = event["kind"] as? Int, kind == NostrProtocol.kindTextNote,
              let senderPubkey = event["pubkey"] as? String else { return }

        guard senderPubkey != store.state.settings.nostrPublicKeyHex else { return }
        guard !store.state.nostrBlockedPubkeys.contains(senderPubkey) else { return }

        if store.state.nostrAllowedPubkeys.contains(senderPubkey) {
            // TODO: route to the agent pipeline.
            return
        }

        let isNew = !store.state.nostrPendingApprovals.contains { $0.pubkeyHex == senderPubkey }
        store.addNostrPendingApproval(NostrPendingApproval(pubkeyHex: senderPubkey))
        if isNew {
            Task { await NotificationService.notifyPendingApproval(pubkeyHex: senderPubkey) }
        }
    }
}
