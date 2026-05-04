import Foundation
import Observation

/// Drives the tool-calling agent loop for a single user utterance.
/// Owns the message thread, dispatches tool calls through AgentTools,
/// and feeds results back to the model until it stops emitting tool calls
/// or the turn cap is reached.
///
/// Usage:
///   let session = AgentSession(store: store)
///   await session.run(transcript: "Add buy groceries to my list")
@MainActor
@Observable
final class AgentSession {
    enum Phase: Equatable {
        case idle
        case running(turn: Int)
        case completed(turnsExhausted: Bool)
        case failed(message: String)
    }

    private(set) var phase: Phase = .idle

    private let store: AppStateStore
    private let maxTurns: Int

    init(store: AppStateStore, maxTurns: Int = 12) {
        self.store = store
        self.maxTurns = maxTurns
    }

    func run(transcript: String) async {
        let key = store.state.settings.openRouterAPIKey
        guard !key.isEmpty else {
            phase = .failed(message: "OpenRouter API key not configured. Add it in Settings.")
            return
        }

        let systemPrompt = AgentPrompt.build(for: store.state)
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcript.trimmingCharacters(in: .whitespacesAndNewlines)],
        ]

        phase = .running(turn: 0)

        for turn in 0..<maxTurns {
            phase = .running(turn: turn)

            let result: AgentResult
            do {
                result = try await callOpenRouter(
                    messages: messages,
                    tools: AgentTools.schema,
                    apiKey: key,
                    model: store.state.settings.llmModel
                )
            } catch {
                phase = .failed(message: "API call failed: \(error.localizedDescription)")
                return
            }

            // Append the assistant turn (including any tool_calls array) to the thread
            messages.append(result.assistantMessage)

            if result.toolCalls.isEmpty {
                // No tool calls → final answer, loop ends
                phase = .completed(turnsExhausted: false)
                return
            }

            // Dispatch each tool call and feed results back
            for toolCall in result.toolCalls {
                let resultJSON = await AgentTools.dispatch(
                    name: toolCall.name,
                    argsJSON: toolCall.arguments,
                    store: store
                )
                messages.append([
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": resultJSON,
                ])
            }
        }

        phase = .completed(turnsExhausted: true)
    }

    // MARK: - OpenRouter HTTP call

    private func callOpenRouter(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String,
        model: String
    ) async throws -> AgentResult {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
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

struct AgentResult: Sendable {
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
