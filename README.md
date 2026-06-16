# Agentforce Voice Quickstart

Build an Agentforce Voice Agent you can call from your phone — entirely from Claude Code.

This repo gives Claude Code the skills and context to stand up a working inbound voice agent on your Salesforce org. You pick the persona, the business logic, and the phone number. Claude handles the metadata, routing flows, planner config, and channel wiring.

---

## What you'll end up with

- An Agentforce Service Agent responding to inbound phone calls
- Omni-Channel routing with human escalation (agent says "let me transfer you" and it works)
- A test suite validating the agent's behavior
- A change log of everything deployed to your org

---

## Prerequisites

| Requirement | How to get it |
|---|---|
| Claude Code | `brew install claude` or [claude.ai/code](https://claude.ai/code) |
| Salesforce CLI (`sf`) | `brew install sf` |
| A Salesforce org with AFCC licenses | CDO, SDO, or a provisioned OrgFarm/trial org |
| A provisioned phone number | Setup > Communication Channels > Numbers (Status: Live) |
| GHE access (for full skill suite) | VPN + `git.soma.salesforce.com` credentials |

---

## Three ways to get started

### Option 1 — Hand this entire repo to Claude (easiest)

Open Claude Code and paste:

```
Read https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/PROMPT.md and follow it.
```

Claude will install skills, check your environment, ask you discovery questions, and build the agent.

### Option 2 — Copy/paste the prompt yourself

Open [PROMPT.md](./PROMPT.md), fill in your org details, and paste it into Claude Code.

### Option 3 — Run the setup script first, then build

```bash
# Clone and run setup
git clone https://github.com/skyrmionz/agentforce-voice-quickstart.git
cd agentforce-voice-quickstart

# Full install (all skills):
./setup.sh

# Or install just what you need:
./setup.sh --bundle voice-agent         # Voice agent essentials
./setup.sh --bundle digital-channels    # All messaging channels
./setup.sh --bundle service-ai          # Service AI features
./setup.sh --install agent-on-native-voice --install omni-routing-supervisor  # Pick specific skills
./setup.sh --list                       # See all available skills

# Restart Claude Code, then in a new session:
# Paste the prompt from PROMPT.md (setup.sh prints it at the end)
```

See [SKILLS.md](./SKILLS.md) for the full catalog with descriptions and headless coverage %.

---

## What gets installed

The setup installs Claude Code skills that teach it how to configure Agentforce Contact Center:

| Skill | What it does |
|---|---|
| `developing-agentforce` | Agent Script authoring lifecycle (create, preview, publish, test) |
| `testing-agentforce` | Structured test suites and evaluation |
| `agent-on-native-voice` | Wire an agent to a PSTN voice channel |
| `agentforce-agent-creation` | Create + fix planner bundle via `sf agent` CLI |
| `omni-routing-supervisor` | Omni-Channel routing, queues, presence, supervisor |
| `voice-channel-omni-queue` | Voice channel creation (no agent, direct to queue) |
| `afcc-headless-configurator` | All-in-one orchestrator for the full AFCC stack |
| `transcription-recording` | Voice transcription + recording setup |
| `voice-reports` | OOB Voice Reports (Rep/IVR Metrics) |

Plus 20+ additional skills for digital channels, Service AI features, and the full demo-prep workflow (`/afcc-spar`, `/afcc-quickstart`, `/afcc-build`).

---

## After the build

Once Claude says it's ready:

1. Call the provisioned phone number from your phone
2. Talk to your agent — test the happy path and escalation
3. Check Omni-Channel in your org to see escalated calls arrive
4. Use `/testing-agentforce` to run automated evals and iterate

---

## Troubleshooting

| Issue | Fix |
|---|---|
| "Permission denied" on GHE clone | Connect to VPN, run `gh auth login --hostname git.soma.salesforce.com` |
| Agent doesn't pick up calls | Check `MessagingChannel.SessionHandlerId` is wired (SOQL query in PROMPT.md) |
| Escalation doesn't work | Verify `plannerType=Atlas__VoiceAgent` and Telephony `plannerSurface` has `outboundRouteConfigs` |
| "Flow not found" on deploy | Deploy the escalation flow before the planner that references it |
| Agent responds but no voice | Check `modality voice:` block exists in the `.agent` file with `voice_id` set |

---

## Source skills

All skills sourced from the [AFCC AFV Headless Demo workgroup](https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm/tree/master/workgroups/afcc_afv_headless_demo).
