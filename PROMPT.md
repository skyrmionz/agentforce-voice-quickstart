# Voice Agent Build Prompt

Paste this into Claude Code. Claude will check your environment, install skills if needed, ask discovery questions, and build the agent end-to-end.

---

## How to use

Open Claude Code and run:

```
curl -sL https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/PROMPT.md
```

Then tell Claude: "Follow this prompt step by step."

---

## The Prompt

```
I want to build an Agentforce Voice Agent. Walk me through it end-to-end.

---

STEP 1 — ENVIRONMENT CHECK

Verify my setup before we do anything:

1. SF CLI installed:
   Run `sf --version`. If missing, install with `brew install sf`.

2. SF CLI authenticated to my org:
   Run `sf org display --json`.
   - If not authenticated, ask me for my org's instance URL and help me log in via `sf org login web` or access token.
   - Confirm the org has required licenses:
     `sf data query --query "SELECT MasterLabel, TotalLicenses, UsedLicenses FROM UserLicense WHERE MasterLabel IN ('Salesforce','Service Cloud','Einstein Agent','Agentforce Guest User')" --json`

3. Agentforce ADLC skills installed:
   Run `ls ~/.claude/skills/developing-agentforce/SKILL.md 2>/dev/null`.
   If missing, install: `curl -sSL https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh | bash`
   (Note: skill changes require restarting Claude Code to take effect.)

4. AFCC voice skills installed:
   Check which skills are present:
   ```
   ls ~/.claude/skills/agent-on-native-voice/SKILL.md 2>/dev/null
   ls ~/.claude/skills/agent-on-enhanced-chat-v2/SKILL.md 2>/dev/null
   ls ~/.claude/skills/agentforce-agent-creation/SKILL.md 2>/dev/null
   ls ~/.claude/skills/omni-routing-supervisor/SKILL.md 2>/dev/null
   ls ~/.claude/skills/afv-pstn-forward/SKILL.md 2>/dev/null
   ```
   If missing, install from the repo:
   ```
   git clone https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm.git /tmp/afcc-skills
   BASE="/tmp/afcc-skills/workgroups/afcc_afv_headless_demo/Headless Skills"
   mkdir -p ~/.claude/skills/agent-on-native-voice && cp "$BASE/Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md" ~/.claude/skills/agent-on-native-voice/SKILL.md
   mkdir -p ~/.claude/skills/agent-on-enhanced-chat-v2 && cp "$BASE/Agent on Channel Configuration/Agent on EC V2/SKILL.md" ~/.claude/skills/agent-on-enhanced-chat-v2/SKILL.md
   mkdir -p ~/.claude/skills/agentforce-agent-creation && cp "$BASE/Agent Configuration/Agentforce Agent Creation/Skill.md" ~/.claude/skills/agentforce-agent-creation/SKILL.md
   mkdir -p ~/.claude/skills/omni-routing-supervisor && cp "$BASE/Omni Configuration/Omni Routing Rep Supervisor Setup/SKILL.md" ~/.claude/skills/omni-routing-supervisor/SKILL.md
   cp -R "$BASE/Omni Configuration/Omni Routing Rep Supervisor Setup/artifacts" ~/.claude/skills/omni-routing-supervisor/
   mkdir -p ~/.claude/skills/afv-pstn-forward && cp "$BASE/AFV Setup with PSTN forward/SKILL.md" ~/.claude/skills/afv-pstn-forward/SKILL.md
   cp -R "$BASE/AFV Setup with PSTN forward/artifacts" ~/.claude/skills/afv-pstn-forward/
   mkdir -p ~/.claude/skills/voice-channel-omni-queue && cp "$BASE/Channel Configuration/Voice channel with omni queue/skill/SKILL.md" ~/.claude/skills/voice-channel-omni-queue/SKILL.md
   mkdir -p ~/.claude/skills/transcription-recording && cp "$BASE/Enable transcription and recording/SKILL.md" ~/.claude/skills/transcription-recording/SKILL.md
   ```
   (Note: requires Salesforce VPN + GHE access. If unavailable, proceed with ADLC skills only.)

Report what's ready and what's missing. Fix what you can automatically. For anything that needs my input (org credentials), ask me.

---

STEP 2 — CHOOSE YOUR PATH

Present me with these options:

**A) Voice via Enhanced Chat V2 Web Widget**
   - No phone number needed — fastest path to first voice interaction
   - Customers talk to the agent through a web chat widget with voice mode
   - Requires: a website domain (your sandbox Experience Cloud site works)
   - ~88% automated by Claude; you'll do 2-3 clicks in Agentforce Builder to enable voice mode
   - Best for: quick testing, demos, internal use

**B) Voice via Phone Call (PSTN)**
   - Real phone call experience — customers dial a number and talk to the agent
   - Requires: a provisioned PSTN phone number (status: Live)
   - ~100% automated by Claude (after phone number is provisioned)
   - Best for: production deployments, realistic end-user experience
   - Phone provisioning path: Setup → Service → Voice → Agentforce Voice Setup

**C) Both (Recommended)**
   - Start with A for immediate voice testing (no phone needed)
   - Add B when your phone number is ready
   - Agent works on both channels simultaneously

Ask which path I want.

---

STEP 3 — DISCOVERY

Once I've chosen a path, ask me these questions (one message, I'll answer all at once):

Common (all paths):
1. What's your org alias? (from `sf org list`)
2. What business is this agent for? (company name + 1-sentence description)
3. What should the agent handle? (e.g., order status, appointment scheduling, FAQ, returns)
4. What's the agent's name and personality? (e.g., "Alex — friendly and concise")
5. What's your Salesforce username? (for queue membership so you receive escalated conversations)
6. Any topics the agent should refuse or escalate immediately? (e.g., billing disputes, cancellations)

Path A only (ECV2 Voice):
7. What website domain will host the chat widget? (e.g., your Experience Cloud site URL, or any domain you control)

Path B only (PSTN):
7. What's your provisioned phone number? (E.164 format, e.g. +14155551234)
   If not provisioned yet, I'll guide you: Setup → Service → Voice → Agentforce Voice Setup → claim a number → wait for "Live" status.

Path C: ask all of the above (7 from Path A + 7 from Path B).

---

STEP 4 — BUILD

With my answers, execute the full build using the installed skills.

=== PATH A: ECV2 Voice ===

1. **Create the agent** — Use the agentforce-agent-creation or afv-pstn-forward skill:
   - Deploy EinsteinGptSettings (enable platform + all 4 fields)
   - Assign permission sets (CopilotSalesforceUser, CopilotSalesforceAdmin, AgentforceServiceAgentBuilder)
   - Create agent via Bot + BotVersion + GenAiPlannerBundle metadata deploy
   - Set `plannerType=Atlas__VoiceAgent`
   - Add `Messaging` plannerSurface with outboundRouteConfigs
   - Add topics (at least 1 — agent drops conversations without topics)
   - Add Escalation topic with `canEscalate=true`
   - Activate the agent

2. **Configure Omni-Channel** — Use the omni-routing-supervisor skill:
   - Create routing config and queue (with MessagingSession SObject access)
   - Add my user as queue member
   - Verify Omni-Channel settings are enabled

3. **Deploy outbound escalation flow** — Use agent-on-enhanced-chat-v2 skill:
   - Create Omni-Channel routing flow for agent → human escalation
   - Deploy via Metadata API

4. **Create MessagingChannel** — Use agent-on-enhanced-chat-v2 skill:
   - Type: `EmbeddedMessaging`
   - Set `sessionHandlerAsa` = agent API name (THIS enables automatic routing to agent)
   - Set `sessionHandlerType` = `AgentforceServiceAgent`
   - Set `sessionHandlerQueue` = fallback queue developer name
   - Deploy via Metadata API

5. **Create EmbeddedServiceConfig** — Use agent-on-enhanced-chat-v2 skill:
   - Link to the MessagingChannel
   - Set deployment type: Web
   - Configure branding
   - Deploy via Metadata API

6. **[MANUAL — Guide me] Enable Voice Mode in Agentforce Builder:**
   Tell me exactly what to click:
   - Navigate to Setup → Agentforce → Agents (or use `sf org open --path "/lightning/setup/AgentStudio/home"`)
   - Open the agent I just created
   - Click "Channels" or "Connections" tab
   - Add "Enhanced Chat v2" connection → select the channel we just created
   - Go to Voice Settings → enable voice mode
   - Save

7. **[MANUAL — Guide me] Publish the ECV2 Deployment:**
   Tell me exactly what to click:
   - Navigate to Setup → Embedded Service Deployments (or use `sf org open --path "/lightning/setup/EmbeddedServiceDeployments/home"`)
   - Find the deployment we created
   - Click it → Publish (or "Switch to v2" if prompted)
   - Copy the deployment code snippet

8. **Verify** — Run SOQL probes:
   ```
   sf data query --query "SELECT Id, DeveloperName, SessionHandlerType FROM MessagingChannel WHERE MessageType='EmbeddedMessaging' AND DeveloperName='<channel_dev_name>'"
   sf data query --query "SELECT Id, DeveloperName, IsEnabled FROM EmbeddedServiceConfig WHERE DeveloperName='<config_dev_name>'" --use-tooling-api
   ```

=== PATH B: PSTN Voice ===

1. **Create the agent** — Use the afv-pstn-forward skill:
   - Deploy EinsteinGptSettings (enable platform + all 4 fields)
   - Assign permission sets
   - Create agent with `plannerType=Atlas__VoiceAgent`
   - Add BOTH `Messaging` AND `Telephony` plannerSurfaces with escalation flow references
   - Add topics + Escalation topic with `canEscalate=true`
   - Activate

2. **Create Routing Config + Queue** — Use afv-pstn-forward skill:
   - RoutingModel = `ExternalRouting` (NOT LeastActive — that breaks PSTN routing)
   - QueueSObject = VoiceCall
   - Add my user as queue member

3. **Deploy Escalation Flow** — Use afv-pstn-forward skill:
   - routingType = `QueueBased`
   - serviceChannelDevName = `sfdc_phone`
   - MUST deploy BEFORE the planner that references it

4. **Deploy Inbound Voice Routing Flow** — Use afv-pstn-forward skill:
   - routingType = `Copilot`
   - copilotId.setupReferenceType = `BotDefinition`
   - serviceChannelLabel = `Phone` (NOT `Voice Call`)

5. **Create MessagingChannel (PstnVoice)** — Use afv-pstn-forward skill:
   - MessageType = `PstnVoice` (NOT `Phone`)
   - MessagingPlatformKey = phone number
   - SessionHandlerId = FlowDefinition ID (300... prefix, NOT Flow version 301...)
   - FallbackQueueId = queue from step 2
   - IsActive = true
   - Create via REST POST (not Metadata API deploy)

6. **Verify** — Run SOQL probes:
   ```
   sf data query --query "SELECT Id, DeveloperName, SessionHandlerId, FallbackQueueId FROM MessagingChannel WHERE MessageType='PstnVoice'"
   sf data query --query "SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%<agent_name>%'" --use-tooling-api
   sf data query --query "SELECT Id, GroupId, UserOrGroupId FROM GroupMember WHERE UserOrGroupId='<my-user-id>'"
   ```

=== PATH C: Both ===

Do Path A first (immediate voice testing via widget), then Path B (add phone when ready).
The agent already has both Messaging + Telephony surfaces from Path A step 1.

---

STEP 5 — TEST

Path A testing:
- Open the website where you deployed the chat widget
- Click the chat bubble
- Start a text conversation, then click the microphone/voice button to switch to voice
- Talk to your agent — test the happy path and escalation
- Say "transfer me to an agent" to test escalation

Path B testing:
- Call the provisioned phone number from your phone
- Talk to your agent — test the happy path and escalation
- Say "transfer me to a real person" to test escalation
- Check Omni-Channel in your org to see escalated calls arrive

Run automated tests:
- Use /testing-agentforce to create a test suite covering: greeting, topic routing, escalation trigger, out-of-scope refusal
- Run the tests and iterate on failures

---

STEP 6 — REPORT

Tell me:
- Which path(s) were deployed
- How to test (URL for Path A, phone number for Path B)
- What the agent handles and what it refuses
- Any manual Setup steps still needed (e.g., Omni-Channel login behavior radio button)
- How to receive escalated conversations (Omni-Channel widget in Service Console)
- What to do next (add more topics, tune the agent, add the other path)

---

RULES:
- Use `curl -sL` to fetch remote files (not WebFetch/Read on URLs — those summarize content).
- Use `--async` + poll for multi-component deploys, never `--wait N` for long deploys.
- Parse SF CLI JSON output with `jq`, never inline Python.
- MessagingChannel (PstnVoice) must be created via REST POST, not Metadata API deploy.
- MessagingChannel (EmbeddedMessaging) is created via Metadata API deploy.
- Deploy escalation flow BEFORE the planner that references it.
- Use `MessageType=PstnVoice`, NOT `Phone`.
- Do not set `ChannelAddressIdentifier` on voice channels (system-assigned).
- `SessionHandlerId` must be a FlowDefinition ID (300...), NOT Flow version (301...).
- `isVoiceModeEnabled` cannot be deployed via Metadata API — always guide user through Builder UI.
- Agent drops calls/chats in <15 sec without topics — always add at least one topic.
- `plannerType` must be `Atlas__VoiceAgent` for voice (not `AiCopilot__ReAct` or `Atlas__ConcurrentMultiAgentOrchestration`).
- Queue `RoutingModel` must be `ExternalRouting` for PSTN voice (not `LeastActive`).
- Always run `sf agent deactivate` before deploying planner changes, then `sf agent activate` after.
- `sf agent deactivate/activate` requires working dir to be an SFDX project directory.
- Block on manual-step confirmation — don't queue more work until I confirm the UI step is done.
- If a sub-agent dispatch fails with HTTP 500 twice, fall back to inline execution.
```
