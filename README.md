# Agentforce Voice Quickstart

Build an Agentforce Voice Agent — from your browser or your phone — entirely from Claude Code.

This repo gives Claude Code the skills and context to stand up a working voice agent on your Salesforce org. You pick the persona, the business logic, and the channel. Claude handles the metadata, routing flows, planner config, and channel wiring.

---

## Choose Your Path

| Path | Channel | What you need | Time to first voice interaction |
|---|---|---|---|
| **A) ECV2 Voice Widget** | Web chat with voice mode | A website domain (sandbox site works) | ~15 min |
| **B) PSTN Phone Call** | Real phone number | A provisioned phone number (status: Live) | ~12 min + provisioning wait |
| **C) Both** | Widget + phone | Both of the above | ~20 min |

**Path A** is the fastest — no phone number needed. Customers talk to your agent through a web chat widget that supports voice mode. Claude automates ~88% of the setup; you do 2-3 clicks in Agentforce Builder to enable voice.

**Path B** is the most realistic end-user experience — customers call a real phone number. Claude automates ~100% of the setup (after phone provisioning). Phone provisioning: Setup → Service → Voice → Agentforce Voice Setup.

**Path C** is recommended — start with A for immediate testing, add B when your number is ready.

---

## What you'll end up with

- An Agentforce Service Agent responding to voice conversations (via web widget, phone, or both)
- Omni-Channel routing with human escalation ("let me transfer you" actually works)
- A test suite validating the agent's behavior
- A change log of everything deployed to your org

---

## Prerequisites

| Requirement | How to get it | Needed for |
|---|---|---|
| Claude Code | `brew install claude` or [claude.ai/code](https://claude.ai/code) | All paths |
| Salesforce CLI (`sf`) | `brew install sf` | All paths |
| A Salesforce org with Agentforce licenses | CDO, SDO, or a provisioned OrgFarm/trial org | All paths |
| Digital Engagement license | Included in Enterprise+ with Foundations/Agentforce 1 Edition | Path A, C |
| A website domain | Your Experience Cloud site or any domain you control | Path A, C |
| A provisioned PSTN phone number (status: Live) | Setup → Service → Voice → Agentforce Voice Setup | Path B, C |
| GHE access (for full skill suite) | VPN + `git.soma.salesforce.com` credentials | Optional |

---

## Three ways to get started

### Option 1 — Hand this entire repo to Claude (easiest)

Open Claude Code and run:

```
curl -sL https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/PROMPT.md
```

Then tell Claude: "Follow this prompt step by step."

Claude will install skills, check your environment, let you choose your path, ask discovery questions, and build the agent.

### Option 2 — Copy/paste the prompt yourself

Open [PROMPT.md](./PROMPT.md), copy the prompt block, and paste it into Claude Code.

### Option 3 — Run the setup script first, then build

```bash
# Clone and run setup
git clone https://github.com/skyrmionz/agentforce-voice-quickstart.git
cd agentforce-voice-quickstart

# Install skills for your chosen path:
./setup.sh --bundle voice-ecv2          # Path A: ECV2 voice widget
./setup.sh --bundle voice-agent         # Path B: PSTN phone call
./setup.sh --bundle voice-all           # Path C: Both paths

# Or install everything:
./setup.sh --bundle full

# Or pick specific skills:
./setup.sh --install agent-on-enhanced-chat-v2 --install omni-routing-supervisor
./setup.sh --list                       # See all available skills

# Restart Claude Code, then in a new session:
# Paste the prompt from PROMPT.md (setup.sh prints it at the end)
```

See [SKILLS.md](./SKILLS.md) for the full catalog with descriptions and headless coverage %.

---

## What gets installed

The setup installs Claude Code skills that teach it how to configure Agentforce Contact Center:

### Path A skills (ECV2 Voice)

| Skill | What it does |
|---|---|
| `agentforce-agent-creation` | Create + fix planner bundle via `sf` CLI |
| `agent-on-enhanced-chat-v2` | Wire agent to ECV2 channel via `sessionHandlerAsa` + deploy widget |
| `omni-routing-supervisor` | Omni-Channel routing, queues, presence, supervisor |

### Path B skills (PSTN Voice)

| Skill | What it does |
|---|---|
| `agentforce-agent-creation` | Create + fix planner bundle via `sf` CLI |
| `afv-pstn-forward` | Full end-to-end PSTN voice setup (agent + flows + channel) |
| `agent-on-native-voice` | Wire agent to a PSTN voice channel with escalation |
| `omni-routing-supervisor` | Omni-Channel routing, queues, presence, supervisor |
| `voice-channel-omni-queue` | Voice channel creation (no agent, direct to queue) |
| `transcription-recording` | Voice transcription + call recording setup |

### Additional skills (all paths)

| Skill | What it does |
|---|---|
| `developing-agentforce` | Agent Script authoring lifecycle (create, preview, publish, test) |
| `testing-agentforce` | Structured test suites and evaluation |
| `afcc-headless-configurator` | All-in-one orchestrator for the full AFCC stack |

---

## After the build

### Path A (ECV2 Voice Widget)

1. Open the website where the chat widget was deployed
2. Click the chat bubble → start a text conversation
3. Click the microphone/voice button to switch to voice mode
4. Talk to your agent — test topic routing and escalation
5. Check Omni-Channel in your org to see escalated conversations arrive

### Path B (PSTN Phone Call)

1. Call the provisioned phone number from your phone
2. Talk to your agent — test the happy path and escalation
3. Say "transfer me to a real person" to test escalation
4. Check Omni-Channel in your org to see escalated calls arrive

### Both paths

Use `/testing-agentforce` to run automated evals and iterate on agent quality.

---

## Manual steps Claude will guide you through

Some steps can't be automated via API. Claude will pause and tell you exactly what to click:

| Step | Path | What to do |
|---|---|---|
| Enable voice mode | A, C | Agentforce Builder → Agent → Channels → ECV2 → Voice Settings → Enable |
| Publish ECV2 deployment | A, C | Setup → Embedded Service Deployments → Select → Publish |
| Provision phone number | B, C | Setup → Service → Voice → Agentforce Voice Setup → Claim number |
| Omni-Channel login behavior | All | Setup → Omni-Channel Settings → select login behavior radio |

---

## Troubleshooting

| Issue | Path | Fix |
|---|---|---|
| "Permission denied" on GHE clone | All | Connect to VPN, run `gh auth login --hostname git.soma.salesforce.com` |
| Agent doesn't respond to chat | A | Check `MessagingChannel.sessionHandlerAsa` is set to agent API name |
| No voice button in chat widget | A | Verify voice mode enabled in Agentforce Builder → Voice Settings |
| Agent doesn't pick up phone calls | B | Check `MessagingChannel.SessionHandlerId` is a FlowDefinition ID (300...) |
| Escalation doesn't work | All | Verify `plannerType=Atlas__VoiceAgent` and surface has `outboundRouteConfigs` |
| "Flow not found" on deploy | B | Deploy the escalation flow before the planner that references it |
| Agent drops calls in <15 seconds | B | Planner has no topics — add at least one topic |
| Queue not receiving escalations | B | Queue `RoutingModel` must be `ExternalRouting` (not `LeastActive`) |
| `isVoiceModeEnabled` deploy fails | A | This field cannot be deployed via API — enable in Builder UI instead |

---

## Source skills

All skills sourced from the [AFCC AFV Headless Demo workgroup](https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm/tree/master/workgroups/afcc_afv_headless_demo).

ECV2 Voice mode (release 262, June 2026) setup goes through Agentforce Builder — Claude will guide you through the clicks where APIs don't exist.
