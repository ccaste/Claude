# Claude OS

This directory is my personal "Claude OS" — the source of truth for who I am, what I'm building, how I want you to write, and what's happened over time. Read these files at the start of every session in this directory and use them to ground your responses.

## Files in this directory

- **About Me.md** — personal facts: relationships, preferences, goals, health, daily context.
- **About My Business.md** — LUX Lighting Services: services, pricing, customers, vendors, ongoing projects, goals.
- **Writing Rules.md** — how I want you to write (tone, formatting, phrases to use and avoid). Governs anything you write on my behalf.
- **Memory.md** — append-only log of events, decisions, and things I want remembered. Newest entry at the top. Every entry dated.

## Related directory

- **~/LUX Lighting Services/** — business documents, proposals, vendor info, customer records. When a transcript concerns a specific project/customer already tracked there, update both the LUX file and About My Business.md.

## Limitless MCP integration

The Limitless MCP server is connected (verify with `claude mcp list`). It exposes tools that return transcripts ("lifelogs") from my pendant — what I've said and heard throughout the day.

**Call the Limitless tools whenever:**
- I ask about my day, a conversation, a meeting, or what someone said.
- I ask to update these files "from today" / "this week" / "since last time".
- Answering well depends on recent context (e.g. "what did I promise Julia?").

**Typical tools:** `list_lifelogs` (date range), `get_lifelog` (one transcript in full), plus any search tool the server exposes.

## Routing rules — what goes where

When you process Limitless transcripts, classify each piece of info and route it:

| Signal in the transcript | File | How |
|---|---|---|
| New personal fact (preference, relationship, goal, health, schedule) | About Me.md | Edit in place under the right section. If it contradicts existing info, update and log the change in Memory.md. |
| New business fact (pricing, service, vendor, process) | About My Business.md | Edit in place. Mirror to `~/LUX Lighting Services/` if it touches a tracked project/customer. |
| Commitment I made (or that was made to me) | Memory.md → "Open Commitments" | Append with date, who, what, by when. |
| Decision made | Memory.md → "Decisions" | Append with date and rationale. |
| Notable but not a fact/commitment/decision | Memory.md → "Notes" | Append with date. |
| Customer/vendor interaction for LUX | About My Business.md + `~/LUX Lighting Services/<file>` | Summary in About My Business, full detail in the project file. |

## Update discipline

- **Dedup.** Before adding a fact, grep these files. If it's already there, edit in place — don't duplicate.
- **Timestamp.** Memory.md entries start with `## YYYY-MM-DD`.
- **Ask when uncertain.** If a reference is ambiguous (which customer, which project), ask instead of guessing.
- **Never transcribe secrets.** Passwords, SSNs, card numbers, API keys — note that they came up, don't record the values.
- **Follow Writing Rules.md.** Anything you write into these files must match that style guide.
- **Writing Rules.md is read-only from transcripts.** I edit it, you don't.

## After each update

Summarize what changed: files touched, sections updated, key new facts. So I can catch mistakes early.
