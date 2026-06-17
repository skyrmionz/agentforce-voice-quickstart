# Agentforce Voice Quickstart

Build an Agentforce Voice Agent — from your browser or your phone — entirely from Claude Code.

This repo gives Claude Code the skills and context to stand up a working voice agent on your Salesforce org. You pick the persona, the business logic, and the channel. Claude handles the metadata, routing flows, planner config, and channel wiring.

---

## Choose Your Path

| Path | Channel | What you need | Time to first voice interaction |
|---|---|---|---|
| **A) ECV2 Voice Widget** | Web chat with voice mode | A website domain (sandbox site works) | ~15 min |
| **B1) Amazon Connect** | Real phone number + warm transfer | Amazon Connect contact center | ~30 min + AWS provisioning wait |
| **B2) Native PSTN** | Real phone number (simpler) | A provisioned phone number (status: Live) | ~12 min + provisioning wait |
| **C) Both** | Widget + phone | Path A + B1 or B2 | ~35 min |

**Path A** is the fastest — no phone number needed. Customers talk to your agent through a web chat widget that supports voice mode. Claude automates ~88% of the setup; you do 2-3 clicks in Agentforce Builder to enable voice.

**Path B1 (Amazon Connect)** is the preferred phone path — the only option that supports warm transfer to live agents. Customer dials an Amazon Connect DID → Connect forwards to Agentforce Voice → AI agent handles → on escalation, call returns to Connect → routes to human rep with full context.

**Path B2 (Native PSTN)** is simpler — just an Agentforce Voice phone number, no Amazon Connect needed. But escalation disconnects the call (no warm transfer). Good for quick voice testing.

**Path C** is recommended — start with A for immediate testing, add B1/B2 when your phone setup is ready.

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
| A Salesforce org (pick one below) | See "Org Options" | All paths |
| Digital Engagement license | Included in Enterprise+ with Foundations/Agentforce 1 Edition | Path A, C |
| A website domain | Your Experience Cloud site or any domain you control | Path A, C |
| Amazon Connect contact center | Setup → Voice → Amazon Setup (Claude guides full setup) | Path B1, C |
| A provisioned PSTN phone number (status: Live) | Setup → Service → Voice → Agentforce Voice Setup | Path B2, C |
| GHE access (for full skill suite) | VPN + `git.soma.salesforce.com` credentials | Optional |

### Org Options

**Option 1 — Use your own org**

Any Salesforce org with Agentforce licenses (CDO, SDO, OrgFarm, or trial). Authenticate via:
```bash
sf org login web --set-default
```

**Option 2 — Use Agentforce Labs (fastest for new users)**

[Agentforce Labs](http://labs.agentforce.com/) provisions a ready-to-go test org with all required licenses. To authenticate:

1. Go to Agentforce Labs → click the **Org dropdown** (top nav bar, left of your name) → **Org Details**
2. Scroll to **SF CLI Authentication** — copy your Instance URL and Access Token
3. Run:
```bash
SF_ACCESS_TOKEN='<your-token>' sf org login access-token --instance-url <your-instance-url> --set-default --no-prompt
```

> **Note:** Agentforce Labs tokens expire in ~2 hours. If you get session expired errors, grab a fresh token from Org Details.

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

# Authenticate your org (pick one):
sf org login web --set-default                          # Own org (opens browser)
# OR for Agentforce Labs:
SF_ACCESS_TOKEN='<token>' sf org login access-token \
  --instance-url <instance-url> --set-default --no-prompt

# Install skills for your chosen path:
./setup.sh --bundle voice-ecv2          # Path A: ECV2 voice widget
./setup.sh --bundle voice-agent         # Path B1/B2: PSTN phone call (Amazon Connect or native)
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

### Path B1 (Amazon Connect)

1. Call the **Amazon Connect DID number** (NOT the Agentforce Voice number)
2. Amazon Connect receives the call and forwards to Agentforce Voice
3. Talk to your agent — test topic routing
4. Say "transfer me to a real person" — call returns to Connect → routes to human via Omni-Channel
5. Open Service Console → set status to Available → receive the escalated call with full context

### Path B2 (Native PSTN)

1. Call the Agentforce Voice provisioned phone number directly
2. Talk to your agent — test the happy path and escalation
3. Say "transfer me to a real person" (disconnects and routes to queue — no warm transfer)
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
| Enable Salesforce Voice + Amazon Connect | B1, C | Setup → Voice → Amazon Setup → Turn on Voice → wait for 2 emails |
| Create Amazon Connect contact center | B1, C | Setup → Voice → Amazon Contact Centers → New → configure region |
| Claim phone number in Amazon Connect | B1, C | Connect console → Channels → Phone Numbers → Claim a number |
| Create Amazon Connect contact flow | B1, C | Connect console → Contact Flows → create AFV inbound flow |
| Add telephony connection to agent | B1, C | Agentforce Builder → Agent → Connections → + Telephony → Voice Settings |
| Provision Agentforce Voice number | B1, B2, C | Setup → Agentforce Voice Setup → New Number |
| Omni-Channel login behavior | All | Setup → Omni-Channel Settings → select login behavior radio |

---

## Troubleshooting

| Issue | Path | Fix |
|---|---|---|
| "Permission denied" on GHE clone | All | Connect to VPN, run `gh auth login --hostname git.soma.salesforce.com` |
| Agent doesn't respond to chat | A | Check `MessagingChannel.sessionHandlerAsa` is set to agent API name |
| No voice button in chat widget | A | Verify voice mode enabled in Agentforce Builder → Voice Settings |
| Agent doesn't pick up phone calls | B1, B2 | Check `MessagingChannel.SessionHandlerId` is a FlowDefinition ID (300...) |
| Calls not reaching Salesforce | B1 | Amazon Connect contact flow not forwarding to Agentforce Voice number — check flow is published and DID is assigned to it |
| Escalation doesn't transfer to human | B1 | Verify Amazon Connect flow has "Transfer to queue" after AFV transfer block |
| Calling Agentforce Voice number directly | B1 | Always dial the Amazon Connect DID — that's the customer-facing number |
| "Confirm Settings" button greyed out | B1 | Refresh the page and try again (common during initial setup) |
| Contact center not appearing | B1 | AWS provisioning takes a few minutes — refresh and wait |
| Escalation doesn't work | All | Verify `plannerType=Atlas__VoiceAgent` and surface has `outboundRouteConfigs` |
| "Flow not found" on deploy | B1, B2 | Deploy the escalation flow before the planner that references it |
| Agent drops calls in <15 seconds | B1, B2 | Planner has no topics — add at least one topic |
| Queue not receiving escalations | B1, B2 | Queue `RoutingModel` must be `ExternalRouting` (not `LeastActive`) |
| `isVoiceModeEnabled` deploy fails | A | This field cannot be deployed via API — enable in Builder UI instead |
| SSO failure / "Fail to connect to telephone provider" | B1 | Check third-party cookies and microphone permissions in browser |

---

## Source skills

All skills sourced from the [AFCC AFV Headless Demo workgroup](https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm/tree/master/workgroups/afcc_afv_headless_demo).

ECV2 Voice mode (release 262, June 2026) setup goes through Agentforce Builder — Claude will guide you through the clicks where APIs don't exist.
