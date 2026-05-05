import Foundation

/// Connects to a configured Nostr relay and gates incoming kind:1 messages
/// through the access-control layer, queuing unknown senders for user approval.
@MainActor
final class NostrRelayService {
    private let store: AppStateStore
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var connectedRelayURL: String?

    init(store: AppStateStore) {
        self.store = store
    }

    // MARK: - Lifecycle

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

    func stop() {
        receiveLoop?.cancel()
        receiveLoop = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectedRelayURL = nil
    }

    // MARK: - Connection

    private func connect(urlString: String, agentPubkey: String) {
        guard let url = URL(string: urlString) else { return }
        connectedRelayURL = urlString
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        sendSubscription(agentPubkey: agentPubkey)
        startReceiveLoop(agentPubkey: agentPubkey)
    }

    private func sendSubscription(agentPubkey: String) {
        let subID = "agent-inbox"
        let filter: [String: Any] = ["kinds": [1], "#p": [agentPubkey]]
        guard let data = try? JSONSerialization.data(withJSONObject: ["REQ", subID, filter] as [Any]),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
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
                    try? await Task.sleep(for: .seconds(5))
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
              array.count >= 3,
              let msgType = array[0] as? String, msgType == "EVENT",
              let event = array[2] as? [String: Any],
              let kind = event["kind"] as? Int, kind == 1,
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
