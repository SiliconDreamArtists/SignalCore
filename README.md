# SovereignTrust-SignalCore

**SovereignTrust-SignalCore** defines the universal result and feedback object used across the entire [SovereignTrust](https://sovereigntrust.foundation) protocol stack. The `Signal<T>` class provides a structured, verifiable format for propagating execution results, feedback entries, and command metadata between agents.

This library serves as the core language for decentralized execution coordination.

---

## 🧠 Purpose

`Signal<T>` enables:

- ✅ Structured execution feedback (including errors, warnings, retries)
- ✅ Typed result propagation (`Signal<T>`)
- ✅ Consistent format across languages, runtimes, and queue systems
- ✅ Decoupling of *execution logic* from *reporting and coordination*

It is the **canonical envelope** for verifiable interaction in SovereignTrust.

---

## 🧱 Architecture

```plaintext
[ Intent Source ]     [ Relay ]     [ Router ]     [ Result Sink ]
      ───────▶  [ Signal<T> ] ─────▶  [ Signal<T> ] ─────▶  [ Signal<T> ]
                    ↑ Includes: Level, FeedbackEntries, Result
```

---

## 📦 Core Features

- `Signal<T>` generic for typed result storage
- `Signal` base class for signal-only messages
- `SignalFeedbackEntry` for level-tagged logs
- Feedback levels: `Information`, `Warning`, `Retry`, `Critical`
- Feedback nature: `Code`, `Operations`, `Security`, `Content`
- Entry de-duplication via `SignalFeedbackEntryComparer`
- JSON roundtrip compatible (`ToJson()` / `FromJson()`)

---

## 📄 Sample

```csharp
var signal = Signal.Start();
signal.LogWarning("Partial data received");

var typed = Signal.Start(new MyResultObject());
typed.LogInformation("Success with result");
```

Serialized:

```json
{
  "Level": "Information",
  "Entries": [
    {
      "Level": "Warning",
      "Message": "Partial data received",
      "CreatedDate": "2025-04-26T18:24:53Z"
    }
  ],
  "Result": {
    "property1": "value1"
  }
}
```

---

## 🔁 Feedback Levels

| Level               | Value |
|---------------------|-------|
| Unspecified         | 0     |
| SensitiveInformation| 1     |
| VerboseInformation  | 2     |
| Information         | 4     |
| Warning             | 8     |
| Retry               | 16    |
| Critical            | 32    |

---

## 🚀 Usage

```csharp
Signal signal = Signal.Start();
signal.LogWarning("Disk space low");

var final = signal.ToJson();
```

---

## 🔄 Compatibility

| Language | Status     |
|----------|------------|
| C# (.NET Standard 2.0) | ✅ Complete |
| PowerShell             | ✅ Native psm1 |
| Python                 | 🔜 In planning |
| JSON Schema            | ✅ Roundtrip-compatible |

---

## 🧠 Design Philosophy

SignalCore formalizes the **execution result layer** of decentralized intent coordination. It ensures every SovereignTrust action, regardless of platform, produces a **verifiable, readable, mergeable record** of what happened and why.

---

## 📄 License

MIT — see [`LICENSE`](./LICENSE)

---

## 🔗 Related Repos

- [`SovereignTrust.Router`](https://github.com/SiliconDreamArtists/SovereignTrust.Router) – Execution engine
- [`SovereignTrust.Emitter`](https://github.com/SiliconDreamArtists/SovereignTrust.Emitter) – Intent authoring
- [`SovereignTrust.Relay`](https://github.com/SiliconDreamArtists/SovereignTrust.Relay) – External-to-internal signal bridge
