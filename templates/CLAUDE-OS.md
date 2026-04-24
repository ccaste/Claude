# Claude OS

This directory is my personal "Claude OS," the source of truth for who I am, what I'm building, how I want you to write, and what's happened over time. Read these files at the start of every session in this directory and use them to ground your responses.

## Files in this directory

- **About Me.md**: personal facts, including relationships, preferences, goals, health, daily context.
- **About My Business.md**: LUX Lighting Services, including services, pricing, customers, vendors, ongoing projects, goals.
- **Writing Rules.md**: how I want you to write (tone, formatting, phrases to use and avoid). Governs anything you write on my behalf.
- **Memory.md**: append-only log of events, decisions, and things I want remembered. Newest entry at the top. Every entry dated.

## Related directory

- **~/Documents/Claude/Projects/LUX Lighting Services/**: business documents, proposals, vendor info, customer records. This is the source of truth for LUX. When a transcript concerns a specific project/customer already tracked there, update both the LUX file and About My Business.md.

> Note: other copies of `LUX Lighting Services` exist at `~/Library/Mobile Documents/com~apple~CloudDocs/LUX Lighting Services` and `~/Documents/Documents - Carlos's Mac mini/LUX Lighting Services`. Do not write to those. They are stale or sync copies.

## Limitless MCP integration

The Limitless MCP server is connected (verify with `claude mcp list`). It exposes tools that return transcripts ("lifelogs") from my pendant, which captures what I've said and heard throughout the day.

**Call the Limitless tools whenever:**
- I ask about my day, a conversation, a meeting, or what someone said.
- I ask to update these files "from today" / "this week" / "since last time".
- Answering well depends on recent context (e.g. "what did I promise Julia?").

**Typical tools:** `mcp__limitless__searchLifelogsWithTranscripts`. Search or list lifelogs (supply a date range or a query). Run `/mcp` inside Claude Code to see the full, current list; treat this file as guidance, not a hardcoded inventory.

## Routing rules: what goes where

When you process Limitless transcripts, classify each piece of info and route it:

| Signal in the transcript | File | How |
|---|---|---|
| New personal fact (preference, relationship, goal, health, schedule) | About Me.md | Edit in place under the right section. If it contradicts existing info, update and log the change in Memory.md. |
| New business fact (pricing, service, vendor, process) | About My Business.md | Edit in place. Mirror to `~/Documents/Claude/Projects/LUX Lighting Services/` if it touches a tracked project/customer. |
| Commitment I made (or that was made to me) | Memory.md → "Open Commitments" | Append with date, who, what, by when. |
| Decision made | Memory.md → "Decisions" | Append with date and rationale. |
| Notable but not a fact/commitment/decision | Memory.md → "Notes" | Append with date. |
| Customer/vendor interaction for LUX | About My Business.md + `~/Documents/Claude/Projects/LUX Lighting Services/<file>` | Summary in About My Business, full detail in the project file. If no existing file matches, ask before creating a new one. |

## Update discipline

- **Dedup.** Before adding a fact, grep these files. If it's already there, edit in place. Don't duplicate.
- **Timestamp.** Memory.md entries start with `## YYYY-MM-DD`.
- **Ask when uncertain.** If a reference is ambiguous (which customer, which project), ask instead of guessing.
- **Never transcribe secrets.** For passwords, SSNs, card numbers, API keys, and similar, note that they came up but don't record the values.
- **Follow Writing Rules.md.** Anything you write into these files must match that style guide.
- **Writing Rules.md is read-only from transcripts.** I edit it, you don't.

## After each update

Summarize what changed: files touched, sections updated, key new facts. So I can catch mistakes early.
