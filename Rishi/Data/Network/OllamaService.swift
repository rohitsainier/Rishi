//
//  OllamaService.swift
//  Rishi
//
//  Created by Rohit Saini on 04/05/25.
//

import Foundation

final class OllamaService: NSObject, URLSessionDataDelegate {
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var currentTask: URLSessionDataTask?

    func sendStream(
        messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        attachedImages: [Data]
    ) async throws -> AsyncThrowingStream<String, Error> {

        guard let url = URL(string: "http://localhost:11434/api/chat") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messagePayload: [[String: Any]] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messagePayload.append(["role": "system", "content": systemPrompt])
        }

        for message in messages {
            var item: [String: Any] = [
                "role": message.sender.rawValue,
                "content": message.content
            ]

            if message.sender == .user && !attachedImages.isEmpty {
                item["images"] = attachedImages.map { $0.base64EncodedString() }
            }

            messagePayload.append(item)
        }

        let payload: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messagePayload
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }

                        let token = (json["message"] as? [String: Any])?["content"] as? String
                            ?? json["response"] as? String

                        if let token = token {
                            continuation.yield(token)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func stopStreaming() {
        currentTask?.cancel()
        continuation?.finish()
        continuation = nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }

        let lines = string.components(separatedBy: .newlines)

        for line in lines where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            let token = (json["message"] as? [String: Any])?["content"] as? String
                ?? json["response"] as? String

            if let token = token {
                continuation?.yield(token)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }

        continuation = nil
        currentTask = nil
    }

    func fetchAvailableModels() async throws -> [String] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            throw OllamaError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw OllamaError.invalidResponse
        }

        return models.compactMap { $0["name"] as? String }
    }
}

extension OllamaService: ChatServiceProtocol {}
