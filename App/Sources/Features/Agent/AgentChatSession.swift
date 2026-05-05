import Foundation
import Observation

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
        case toolBatch(batchID: UUID, count: Int)
        case error
    }

    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date

    init(role: Role, text: String, timestamp: Date = Date()) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
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

    private let store: AppStateStore
    private let maxTurns: Int
    private var rawMessages: [[String: Any]] = []

    init(store: AppStateStore, maxTurns: Int = 12) {
        self.store = store
        self.maxTurns = maxTurns
    }

    var canSend: Bool {
        if case .sending = phase { return false }
        return true
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
        }

        rawMessages.append(["role": "user", "content": trimmed])
        messages.append(ChatMessage(role: .user, text: trimmed))
        phase = .sending

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
                return
            }

            rawMessages.append(result.assistantMessage)

            if let content = result.assistantMessage["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(ChatMessage(role: .assistant, text: content))
            }

            if result.toolCalls.isEmpty {
                phase = .idle
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
        }

        phase = .idle
    }

    private func callOpenRouter(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String,
        model: String
    ) async throws -> AgentResult {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AgentError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

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
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let body): "HTTP error: \(body)"
        case .malformedResponse: "Malformed response from API"
        case .invalidURL: "Invalid API endpoint URL"
        }
    }
}
