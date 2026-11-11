import Darwin
import Foundation

enum CoreClientError: LocalizedError {
    case callFailed(String)
    case invalidResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .callFailed(let message): return message
        case .invalidResponse: return "The native core returned an invalid response."
        case .decoding(let message): return "The native core response could not be read: \(message)"
        }
    }
}

struct CoreClient {
    static let shared = CoreClient()

    func initialize(storagePath: String, day: String) throws -> TimerState {
        try call(
            ["cmd": "initialize", "storagePath": storagePath, "day": day],
            as: TimerState.self
        )
    }

    func tick(nowMs: Int, day: String) throws -> TimerState {
        try call(
            ["cmd": "tick", "nowMs": nowMs, "day": day],
            as: TimerState.self
        )
    }

    func performTimer(
        _ command: String,
        nowMs: Int,
        day: String,
        phase: PomodoroPhase? = nil,
        config: PomodoroConfig? = nil,
        intention: String? = nil,
        taskId: String? = nil
    ) throws -> TimerState {
        var request: [String: Any] = [
            "cmd": command,
            "nowMs": nowMs,
            "day": day
        ]
        if let phase {
            request["phase"] = phase.rawValue
        }
        if let config {
            request["config"] = try jsonObject(config)
        }
        if let intention {
            request["intention"] = intention
        }
        if let taskId {
            request["taskId"] = taskId
        }
        return try call(request, as: TimerState.self)
    }

    func assignTask(_ taskId: String?, nowMs: Int, day: String) throws -> TimerState {
        var request: [String: Any] = [
            "cmd": "timer.assignTask",
            "nowMs": nowMs,
            "day": day
        ]
        if let taskId {
            request["taskId"] = taskId
        }
        return try call(request, as: TimerState.self)
    }

    func setLength(minutes: Int, nowMs: Int, day: String) throws -> TimerState {
        try call(
            ["cmd": "timer.setLength", "minutes": minutes, "nowMs": nowMs, "day": day],
            as: TimerState.self
        )
    }

    func tasks(nowMs: Int, day: String) throws -> [TaskItem] {
        try call(
            ["cmd": "tasks.list", "nowMs": nowMs, "day": day],
            as: [TaskItem].self
        )
    }

    func sessions(nowMs: Int, day: String) throws -> [FocusSession] {
        try call(
            ["cmd": "sessions.list", "nowMs": nowMs, "day": day],
            as: [FocusSession].self
        )
    }

    func addTask(
        title: String,
        priority: TaskPriority,
        estimateBlocks: Int,
        inProgress: Bool = false,
        estimateMinutes: Int? = nil,
        dueAtMs: Int? = nil,
        nowMs: Int,
        day: String
    ) throws -> [TaskItem] {
        var request: [String: Any] = [
            "cmd": "tasks.add",
            "title": title,
            "priority": priority.rawValue,
            "estimateBlocks": estimateBlocks,
            "inProgress": inProgress,
            "nowMs": nowMs,
            "day": day
        ]
        if let dueAtMs { request["dueAtMs"] = dueAtMs }
        if let estimateMinutes { request["estimateMinutes"] = estimateMinutes }
        return try call(request, as: [TaskItem].self)
    }

    func updateTask(
        id: String,
        title: String? = nil,
        priority: TaskPriority? = nil,
        estimateBlocks: Int? = nil,
        inProgress: Bool? = nil,
        archived: Bool? = nil,
        estimateMinutes: Int? = nil,
        dueAtMs: Int?? = nil,
        nowMs: Int,
        day: String
    ) throws -> [TaskItem] {
        var request: [String: Any] = [
            "cmd": "tasks.update",
            "id": id,
            "nowMs": nowMs,
            "day": day
        ]
        if let title { request["title"] = title }
        if let priority { request["priority"] = priority.rawValue }
        if let estimateBlocks { request["estimateBlocks"] = estimateBlocks }
        if let inProgress { request["inProgress"] = inProgress }
        if let archived { request["archived"] = archived }
        if let estimateMinutes { request["estimateMinutes"] = estimateMinutes }
        // .some(nil) clears the deadline.
        if let dueAtMs { request["dueAtMs"] = dueAtMs ?? NSNull() }
        return try call(request, as: [TaskItem].self)
    }

    func reorderTasks(ids: [String], nowMs: Int, day: String) throws -> [TaskItem] {
        try call(
            ["cmd": "tasks.reorder", "ids": ids, "nowMs": nowMs, "day": day],
            as: [TaskItem].self
        )
    }

    func toggleTask(id: String, nowMs: Int, day: String) throws -> [TaskItem] {
        try call(
            ["cmd": "tasks.toggle", "id": id, "nowMs": nowMs, "day": day],
            as: [TaskItem].self
        )
    }

    func deleteTask(id: String, nowMs: Int, day: String) throws -> [TaskItem] {
        try call(
            ["cmd": "tasks.delete", "id": id, "nowMs": nowMs, "day": day],
            as: [TaskItem].self
        )
    }

    func clearOpenTasks(nowMs: Int, day: String) throws -> [TaskItem] {
        try call(
            ["cmd": "tasks.clearOpen", "nowMs": nowMs, "day": day],
            as: [TaskItem].self
        )
    }

    func buildPlan(nowMs: Int, targetMinutes: Int, bufferMinutes: Int) throws -> DayPlan {
        try call(
            [
                "cmd": "plan.build",
                "nowMs": nowMs,
                "targetMinutes": targetMinutes,
                "bufferMinutes": bufferMinutes
            ],
            as: DayPlan.self
        )
    }

    private func call<T: Decodable>(_ request: [String: Any], as type: T.Type) throws -> T {
        guard JSONSerialization.isValidJSONObject(request) else {
            throw CoreClientError.invalidResponse
        }
        let requestData = try JSONSerialization.data(withJSONObject: request)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            throw CoreClientError.invalidResponse
        }

        let output: UnsafeMutablePointer<CChar>? = requestString.withCString { pointer in
            cadence_core_invoke(pointer)
        }
        guard let output else {
            throw CoreClientError.callFailed("The native core did not answer.")
        }
        defer { cadence_core_free(output) }

        let responseData = Data(bytes: output, count: strlen(output))
        guard let root = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw CoreClientError.invalidResponse
        }
        if (root["ok"] as? Bool) == false {
            let message = root["error"] as? String ?? "The native core reported an unknown error."
            throw CoreClientError.callFailed(message)
        }
        guard let payload = root["data"] else {
            throw CoreClientError.invalidResponse
        }
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        do {
            return try JSONDecoder().decode(type, from: payloadData)
        } catch {
            throw CoreClientError.decoding(error.localizedDescription)
        }
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    static func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }
}
