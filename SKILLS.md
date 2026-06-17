# Available Skills

Browse and install individual skills. Use `./setup.sh --install <skill-name>` or copy the manual install command.

---

## Voice & Channel Setup

| Skill | Description | Path | Headless % |
|---|---|---|---|
| `agent-on-native-voice` | Wire an Agentforce agent to a PSTN voice channel with escalation | B1, B2 | ~100% |
| `afv-pstn-forward` | Full end-to-end AFV PSTN setup (agent + flows + channel wiring) | B1, B2 | ~100% |
| `amazon-connect-setup` | Amazon Connect telephony provider + contact flow + phone provisioning | B2 | ~50% |
| `voice-channel-omni-queue` | Create a voice channel routed directly to a queue (no agent) | B1, B2 | ~88% |
| `agent-on-enhanced-chat-v2` | Wire agent to Enhanced Chat v2 via `sessionHandlerAsa` + deploy widget | A | ~88% |
| `transcription-recording` | Enable voice transcription and call recording | B1, B2 | varies |
| `voice-reports` | OOB Voice Reports — Rep/IVR Metrics + Command Center Reports tab | B1, B2 | ~80% |

> **Note on ECV2 Voice:** The `agent-on-enhanced-chat-v2` skill handles channel wiring and widget deployment (~88% headless). Enabling voice mode on the channel requires Agentforce Builder UI — Claude will guide you through the clicks. The `isVoiceModeEnabled` metadata field cannot be deployed via API.

> **Note on Amazon Connect (Path B2):** The `amazon-connect-setup` skill covers the full Amazon Connect configuration — contact center creation, phone number provisioning (via boto3 or manual), contact flow JSON, and wiring. The `afv-pstn-forward` skill handles the Salesforce-side routing (agent, flows, channel). Together they cover the complete warm-transfer path. ~50% is programmatic via AWS SDK (boto3); the rest requires Setup UI (identity provider, voice enable, contact center wizard, AFV number provisioning).

## Agent Creation & Wiring

| Skill | Description | Path | Headless % |
|---|---|---|---|
| `agentforce-agent-creation` | Create + configure an Agentforce Service Agent via `sf` CLI | All | 100% |
| `agent-on-enhanced-chat` | Connect agent to Enhanced Chat v1 (MIAW) | — | ~88% |
| `agent-on-3p-channels` | Bulk-wire agent to SMS/WhatsApp/LINE/Apple/FB channels | — | ~85% |

## Digital Channels

| Skill | Description | Path | Headless % |
|---|---|---|---|
| `enhanced-chat` | Migrate from Live Agent to Enhanced Digital Engagement (Chat v1) | — | ~43% |
| `enhanced-chat-v2` | Set up Enhanced Chat v2 (persistent chat, rich media) | A | ~50% |
| `sms-channel` | Configure SMS messaging channel | — | ~40% |
| `whatsapp-channel` | Configure WhatsApp Business messaging channel | — | ~50% |
| `line-channel` | Configure LINE messaging channel | — | ~67% |
| `apple-messages-channel` | Configure Apple Messages for Business channel | — | ~40% |
| `facebook-messenger-channel` | Configure Facebook Messenger (Enhanced) channel | — | ~60% |

## Omni-Channel & Routing

| Skill | Description | Path | Headless % |
|---|---|---|---|
| `omni-routing-supervisor` | Full Omni-Channel setup: routing, queues, presence, skills, supervisor | All | ~95% |

## Service AI Features

| Skill | Description | Path | Headless % |
|---|---|---|---|
| `service-ai-grounding` | Einstein Generative AI data grounding | — | ~60% |
| `agentforce-service-assistant` | Agentforce Service Assistant (agent-side copilot) | — | ~25% |
| `einstein-article-recommendations` | Einstein Article Recommendations for cases | — | ~70% |
| `einstein-service-replies` | Einstein Service Replies (messaging channels) | — | ~30% |
| `einstein-conversation-insights` | Einstein Conversation Insights (transcription + sentiment) | — | ~65% |
| `conversation-mining` | Conversation Mining (topic detection from transcripts) | — | ~55% |
| `voice-messaging-nba` | Voice & Messaging Next Best Action recommendations | — | ~60% |
| `knowledge-creation` | Einstein Knowledge Creation from cases | — | ~83% |
| `real-time-translations` | Real-Time Translations for messaging | — | 100% |
| `work-summaries` | Work Summaries & Conversation Catch-Up | — | ~83% |

## Orchestrators (install multiple skills at once)

| Skill | Description |
|---|---|
| `afcc-demo-prep` | Full demo-prep workflow with `/afcc-spar`, `/afcc-quickstart`, `/afcc-build` |
| `afcc-headless-configurator` | All-in-one orchestrator that composes all sub-skills |

---

## Bundles (common combinations)

### `voice-ecv2` — Voice via Enhanced Chat V2 web widget (Path A)
```bash
./setup.sh --bundle voice-ecv2
```
Installs: `agentforce-agent-creation`, `agent-on-enhanced-chat-v2`, `omni-routing-supervisor`, `enhanced-chat-v2`

### `voice-agent` — Voice via PSTN phone call (Path B)
```bash
./setup.sh --bundle voice-agent
```
Installs: `agentforce-agent-creation`, `agent-on-native-voice`, `afv-pstn-forward`, `omni-routing-supervisor`, `voice-channel-omni-queue`, `transcription-recording`

### `voice-all` — Both paths (Path C)
```bash
./setup.sh --bundle voice-all
```
Installs: everything from `voice-ecv2` + `voice-agent` (deduplicated)

### `digital-channels` — All digital messaging channels
```bash
./setup.sh --bundle digital-channels
```
Installs: `enhanced-chat`, `enhanced-chat-v2`, `sms-channel`, `whatsapp-channel`, `line-channel`, `apple-messages-channel`, `facebook-messenger-channel`, `agent-on-3p-channels`, `agent-on-enhanced-chat`, `agent-on-enhanced-chat-v2`

### `service-ai` — All Service AI features
```bash
./setup.sh --bundle service-ai
```
Installs: `service-ai-grounding`, `agentforce-service-assistant`, `einstein-article-recommendations`, `einstein-service-replies`, `einstein-conversation-insights`, `conversation-mining`, `voice-messaging-nba`, `knowledge-creation`, `real-time-translations`, `work-summaries`

### `full` — Everything (default)
```bash
./setup.sh --bundle full
# or just:
./setup.sh
```

---

## Install a single skill

```bash
# By name:
./setup.sh --install agent-on-native-voice

# Multiple:
./setup.sh --install agent-on-native-voice --install omni-routing-supervisor

# List available skills:
./setup.sh --list
```

---

## Manual install (without the script)

Each skill is a `SKILL.md` file placed in `~/.claude/skills/<skill-name>/`. Example:

```bash
# Clone the source repo (requires GHE access)
git clone --depth 1 https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm.git /tmp/afcc
BASE="/tmp/afcc/workgroups/afcc_afv_headless_demo/Headless Skills"

# Install one skill
mkdir -p ~/.claude/skills/agent-on-native-voice
cp "$BASE/Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md" \
   ~/.claude/skills/agent-on-native-voice/SKILL.md

# Restart Claude Code
```

See the source paths table below for every skill:

| Skill name | Source path (under `Headless Skills/`) |
|---|---|
| `voice-channel-omni-queue` | `Channel Configuration/Voice channel with omni queue/skill/SKILL.md` |
| `enhanced-chat` | `Channel Configuration/enhanced-chat/SKILL.md` |
| `enhanced-chat-v2` | `Channel Configuration/enhanced-chat-v2/SKILL.md` |
| `sms-channel` | `Channel Configuration/sms/SKILL.md` |
| `whatsapp-channel` | `Channel Configuration/whatsapp/SKILL.md` |
| `line-channel` | `Channel Configuration/Line/SKILL.md` |
| `apple-messages-channel` | `Channel Configuration/apple-messages-for-business/SKILL.md` |
| `facebook-messenger-channel` | `Channel Configuration/FacebookMessenger/SKILL.md` |
| `voice-reports` | `Channel Configuration/OOTB Voice Reports/SKILL.md` |
| `agentforce-agent-creation` | `Agent Configuration/Agentforce Agent Creation/Skill.md` |
| `agent-on-native-voice` | `Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md` |
| `agent-on-enhanced-chat` | `Agent on Channel Configuration/Agent on EC/SKILL.md` |
| `agent-on-enhanced-chat-v2` | `Agent on Channel Configuration/Agent on EC V2/SKILL.md` |
| `agent-on-3p-channels` | `Agent on Channel Configuration/Agent on Native 3P Channels/SKILL.md` |
| `omni-routing-supervisor` | `Omni Configuration/Omni Routing Rep Supervisor Setup/SKILL.md` |
| `afv-pstn-forward` | `AFV Setup with PSTN forward/SKILL.md` |
| `transcription-recording` | `Enable transcription and recording/SKILL.md` |
| `service-ai-grounding` | `Service AI Feature Configuration/service-ai-grounding/SKILL.md` |
| `agentforce-service-assistant` | `Service AI Feature Configuration/agentforce-service-assistant/SKILL.md` |
| `einstein-article-recommendations` | `Service AI Feature Configuration/einstein-article-recommendations/SKILL.md` |
| `einstein-service-replies` | `Service AI Feature Configuration/einstein-service-replies/SKILL.md` |
| `einstein-conversation-insights` | `Service AI Feature Configuration/einstein-conversation-insights/SKILL.md` |
| `conversation-mining` | `Service AI Feature Configuration/conversation-mining/SKILL.md` |
| `voice-messaging-nba` | `Service AI Feature Configuration/voice-messaging-nba/SKILL.md` |
| `knowledge-creation` | `Service AI Feature Configuration/KnowledgeCreation/SKILL.md` |
| `real-time-translations` | `Service AI Feature Configuration/RealTimeTranslations/skill/SKILL.md` |
| `work-summaries` | `Service AI Feature Configuration/WorkSummary/SKILL.md` |
