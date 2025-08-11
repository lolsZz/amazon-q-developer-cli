# Chat Session Auditing

The CLI records a detailed, append-only audit log for each chat session.  
Each file is newline-delimited JSON (`.jsonl`) where every line is an event object.

## Location

The directory is determined in this order:

1. `XDG_DATA_HOME` if set (e.g. on many sandboxed / snap / flatpak environments)
2. Otherwise the standard XDG path: `$HOME/.local/share`
3. (If resolution fails, a temporary directory is used)

Final path pattern:
```
$XDG_DATA_HOME/amazon-q-cli/audit/session-<UUID>.jsonl
# Example:
# /home/user/.local/share/amazon-q-cli/audit/session-d1e2f3a4-....jsonl
```

In your environment (snap-based VS Code), logs appeared under:
```
/home/<user>/snap/code/<rev>/.local/share/amazon-q-cli/audit
```

## When Logs Are Created

A new audit file is created at the start of each `q chat` session (interactive or non‑interactive).  
No flag is required; logging is automatic.

## Events Captured

Each event includes a timestamp (`ts` RFC3339), `session_id`, `type`, and a `data` payload.

Event types:
- `session_start` / `session_end`
- `user_input` (raw user prompt)
- `assistant_message` (model textual output)
- `tool_validation_succeeded`
- `tool_validation_failed`
- `tool_execute_start`
- `tool_execute_end` (status: success / error, output or error message)
- `tool_decision` (accept / deny / trust)
  
All tool arguments, outputs, and assistant text are logged in full (unredacted) as per your configuration request.

## JSONL Record Example

```
{"ts":"2025-08-11T21:52:18Z","session_id":"163409ac-...","type":"user_input","data":{"input":"ping"}}
{"ts":"2025-08-11T21:52:18Z","session_id":"163409ac-...","type":"assistant_message","data":{"content":"pong"}}
{"ts":"2025-08-11T21:52:19Z","session_id":"163409ac-...","type":"session_end","data":{}}
```

## Viewing Logs

List all audit files:
```bash
ls -1 "$XDG_DATA_HOME/amazon-q-cli/audit"/session-*.jsonl 2>/dev/null \
  || ls -1 ~/.local/share/amazon-q-cli/audit/session-*.jsonl 2>/dev/null
```

Tail the newest file (fish shell example):
```fish
set base $XDG_DATA_HOME/amazon-q-cli/audit; or set base ~/.local/share/amazon-q-cli/audit
set f (ls -t $base/session-*.jsonl | head -n1)
echo "Tailing $f"
tail -f $f
```

Pretty-print in real time:
```bash
tail -f /path/to/audit/session-*.jsonl | jq
```

## Non-Interactive Example

```bash
cargo run --bin chat_cli -- chat --no-interactive "ping"
```

The above generates a new session log immediately.

## Data Sensitivity

Because full prompt text, tool arguments (including file contents or commands), and outputs are stored, treat these files as sensitive. Rotate or archive according to your security policies.

## Future Enhancements (Not Yet Implemented)

- Optional environment variable override (e.g. `QCLI_AUDIT_DIR`) to force a custom directory
- Redaction mode for secrets
- Remote streaming (syslog / SIEM) feature flag
