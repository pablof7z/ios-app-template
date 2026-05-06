import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "AgentChatSession")

// MARK: - Network constants

private enum AgentNetworkConstants {
    /// OpenRouter chat-completions endpoint.
    static let openRouterURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    /// Network timeout for each agent turn.
    static let requestTimeout: TimeInterval = 60
}

struct ChatMessage: Identifiable, Equatable, Codable {
    enum Role: Equatable {
        case user
        case assistant
        case toolBatch(batchID: UUID, count: Int)
        case error
    }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roleType
        case batchID
        case batchCount
        case text
        case timestamp
    }

    private enum RoleType: String, Codable {
        case user
        case assistant
        case toolBatch
        case error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.text = try c.decode(String.self, forKey: .text)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        let type = try c.decode(RoleType.self, forKey: .roleType)
        switch type {
        case .user:
            self.role = .user
        case .assistant:
            self.role = .assistant
        case .error:
            self.role = .error
        case .toolBatch:
            let batchID = try c.decode(UUID.self, forKey: .batchID)
            let count = try c.decode(Int.self, forKey: .batchCount)
            self.role = .toolBatch(batchID: batchID, count: count)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(timestamp, forKey: .timestamp)
        switch role {
        case .user:
            try c.encode(RoleType.user, forKey: .roleType)
        case .assistant:
            try c.encode(RoleType.assistant, forKey: .roleType)
        case .error:
            try c.encode(RoleType.error, forKey: .roleType)
        case .toolBatch(let batchID, let count):
            try c.encode(RoleType.toolBatch, forKey: .roleType)
            try c.encode(batchID, forKey: .batchID)
            try c.encode(count, forKey: .batchCount)
        }
    }
}

@MainActor
@Observable
final class AgentChatSession {
    enum Phase: Equatable {
        case idle
        case sending
        case failed(String)
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var phase: Phase = .idle
    private(set) var loadedFromHistory: Bool = false

    private let store: AppStateStore
    private let history: ChatHistoryStore
    private var rawMessages: [[String: Any]] = []

    private let maxTurns: Int = 20

    init(store: AppStateStore, history: ChatHistoryStore = .shared) {
        self.store = store
        self.history = history
        let loaded = history.load()
        self.messages = loaded
        self.loadedFromHistory = !loaded.isEmpty
    }

    var canSend: Bool {
        if case .sending = phase { return false }
        return true
    }

    func clearHistory() {
        history.clear()
        messages = []
        rawMessages = []
        loadedFromHistory = false
        phase = .idle
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canSend else { return }

        let key: String
        do {
            guard let storedKey = try OpenRouterCredentialStore.apiKey() else {
                phase = .failed("OpenRouter is not connected. Add a key in Settings.")
                return
            }
            key = storedKey
        } catch {
            phase = .failed("OpenRouter credential could not be read. Reconnect in Settings.")
            return
        }

        if rawMessages.isEmpty {
            rawMessages.append([
                "role": "system",
                "content": AgentPrompt.build(for: store.state),
            ])
            seedRawMessagesFromHistory()
        }

        rawMessages.append(["role": "user", "content": trimmed])
        messages.append(ChatMessage(role: .user, text: trimmed))
        phase = .sending
        history.save(messages)

        let batchID = UUID()
        var batchActionCount = 0

        for _ in 0..<maxTurns {
            let result: AgentResult
            do {
                result = try await callOpenRouter(
                    messages: rawMessages,
                    tools: AgentTools.schema,
                    apiKey: key,
                    model: store.state.settings.llmModel
                )
            } catch {
                let msg = "Couldn't reach the agent. \(error.localizedDescription)"
                messages.append(ChatMessage(role: .error, text: msg))
                phase = .failed(msg)
                history.save(messages)
                return
            }

            rawMessages.append(result.assistantMessage)

            if let content = result.assistantMessage["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(ChatMessage(role: .assistant, text: content))
            }

            if result.toolCalls.isEmpty {
                phase = .idle
                history.save(messages)
                return
            }

            for toolCall in result.toolCalls {
                let resultJSON = await AgentTools.dispatch(
                    name: toolCall.name,
                    argsJSON: toolCall.arguments,
                    store: store,
                    batchID: batchID
                )
                rawMessages.append([
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": resultJSON,
                ])
                batchActionCount += 1
            }

            if let lastBatchIdx = messages.lastIndex(where: { msg in
                if case .toolBatch(let id, _) = msg.role, id == batchID { return true }
                return false
            }) {
                messages[lastBatchIdx] = ChatMessage(
                    role: .toolBatch(batchID: batchID, count: batchActionCount),
                    text: ""
                )
            } else {
                messages.append(ChatMessage(
                    role: .toolBatch(batchID: batchID, count: batchActionCount),
                    text: ""
                ))
            }
            history.save(messages)
        }

        let limitMsg = "The agent reached its turn limit. Try a simpler request or start a new conversation."
        messages.append(ChatMessage(role: .error, text: limitMsg))
        phase = .failed(limitMsg)
        history.save(messages)
    }

    private func seedRawMessagesFromHistory() {
        for msg in messages {
            switch msg.role {
            case .user:
                rawMessages.append(["role": "user", "content": msg.text])
            case .assistant:
                rawMessages.append(["role": "assistant", "content": msg.text])
            case .toolBatch, .error:
                continue
            }
        }
    }

    private func callOpenRouter(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String,
        model: String
    ) async throws -> AgentResult {
        var request = URLRequest(url: AgentNetworkConstants.openRouterURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AgentNetworkConstants.requestTimeout

        let body: [String: Any] = ["model": model, "messages": messages, "tools": tools]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw AgentError.httpError(body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any]
        else {
            throw AgentError.malformedResponse
        }

        var toolCalls: [AgentToolCall] = []
        if let rawCalls = message["tool_calls"] as? [[String: Any]] {
            for call in rawCalls {
                guard
                    let id = call["id"] as? String,
                    let fn = call["function"] as? [String: Any],
                    let name = fn["name"] as? String,
                    let arguments = fn["arguments"] as? String
                else { continue }
                toolCalls.append(AgentToolCall(id: id, name: name, arguments: arguments))
            }
        }

        return AgentResult(assistantMessage: message, toolCalls: toolCalls)
    }
}

// MARK: - Supporting types

struct AgentToolCall: Sendable {
    let id: String
    let name: String
    let arguments: String
}

struct AgentResult: @unchecked Sendable {
    let assistantMessage: [String: Any]
    let toolCalls: [AgentToolCall]
}

enum AgentError: LocalizedError {
    case httpError(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let body): "HTTP error: \(body)"
        case .malformedResponse: "Malformed response from API"
        }
    }
}
