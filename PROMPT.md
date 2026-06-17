I want to build an Agentforce Voice Agent. Walk me through it end-to-end.

---

STEP 1 — ENVIRONMENT CHECK

Verify my setup before we do anything:

1. SF CLI installed:
   Run `sf --version`. If missing, install with `brew install sf`. If found, update: `sf update`.

2. Salesforce org authenticated:
   Run `sf org display --json`.
   - If authenticated: confirm the org alias, username, and instance URL. Ask me to confirm this is the org I want to use.
   - If NOT authenticated: ask me which option I want:

     **Option A — Use my own org (already authenticated or I'll log in now)**
     Help me log in via `sf org login web --set-default` (opens browser) or `sf org login access-token` if I have a token.

     **Option B — Use Agentforce Labs (provisioned test org)**
     I'll provide an access token and instance URL from Agentforce Labs.
     Tell me: "Go to Agentforce Labs → click the Org dropdown (top nav, left of your name) → Org Details → scroll to 'SF CLI Authentication' for your Instance URL and Access Token."
     Then authenticate with:
     ```
     SF_ACCESS_TOKEN='<my-token>' sf org login access-token --instance-url <my-instance-url> --set-default --no-prompt
     ```
     (Note: Agentforce Labs tokens expire in ~2 hours. Re-authenticate if you get session expired errors.)

   - Once authenticated, confirm the org has required licenses:
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
   ls ~/.claude/skills/amazon-connect-setup/SKILL.md 2>/dev/null
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

Report what's ready and what's missing. Fix what you can automatically. For anything that needs my input (org choice, credentials), ask me.

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
   - Two sub-options:

     **B1) Native PSTN (Recommended — simplest phone path)**
     - Straightforward setup — just a provisioned Agentforce Voice phone number
     - Requires: a provisioned PSTN phone number (status: Live)
     - ~100% automated by Claude (after phone number is provisioned)
     - Escalation routes to Omni-Channel queue (call disconnects and re-queues)
     - Best for: quick voice testing, demos, most use cases

     **B2) Amazon Connect (Advanced — warm transfer to live agents)**
     - Full warm transfer to live agents — call stays connected during escalation
     - Requires: Amazon Connect contact center configured in your org (Claude guides you through setup)
     - Call flow: Customer dials Amazon Connect DID → Connect forwards to Agentforce Voice → AI agent handles → escalation returns call to Connect → routes to human rep
     - More setup steps (~20 min manual + waiting for AWS provisioning emails)
     - Best for: production deployments requiring seamless human escalation

   - Phone provisioning path: Setup → Service → Voice → Agentforce Voice Setup

**C) Both (Recommended)**
   - Start with A for immediate voice testing (no phone needed)
   - Add B when your phone number / Amazon Connect is ready
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
7. Do you want Native PSTN (B1 — recommended, simpler setup) or Amazon Connect (B2 — advanced, warm transfer to live agents)?
8. Do you have an Agentforce Voice phone number? (Check: Setup → Service → Agentforce Voice Setup)
   - If yes: provide it (E.164 format, e.g. +14155551234)
   - If no: I'll guide you through provisioning one
9. (B2 only) Is Amazon Connect already configured in your org? (Check: Setup → Voice → Amazon Contact Centers — do you see a contact center listed?)
   - If yes: what's your Amazon Connect DID phone number? (the number customers will dial)
   - If no: I'll guide you through the full Amazon Connect setup (takes ~20 min of manual steps + waiting for AWS provisioning emails)

Path C: ask all of the above (7 from Path A + questions from Path B).

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

--- PATH B1: Native PSTN (Recommended — simplest phone path) ---

1. **[MANUAL — Guide me] Provision an Agentforce Voice phone number:**
   - Setup → Service → Voice → Agentforce Voice Setup
   - Click "New Number" → claim a number → wait for status "Live"

2. **Create the agent** — Use the afv-pstn-forward skill:
   - Deploy EinsteinGptSettings (enable platform + all 4 fields)
   - Assign permission sets
   - Create agent with `plannerType=Atlas__VoiceAgent`
   - Add BOTH `Messaging` AND `Telephony` plannerSurfaces with escalation flow references
   - Add topics + Escalation topic with `canEscalate=true`
   - Activate

3. **Create Routing Config + Queue** — Use afv-pstn-forward skill:
   - RoutingModel = `ExternalRouting` (NOT LeastActive — that breaks PSTN routing)
   - QueueSObject = VoiceCall
   - Add my user as queue member

4. **Deploy Escalation Flow** — Use afv-pstn-forward skill:
   - routingType = `QueueBased`
   - serviceChannelDevName = `sfdc_phone`
   - MUST deploy BEFORE the planner that references it

5. **Deploy Inbound Voice Routing Flow** — Use afv-pstn-forward skill:
   - routingType = `Copilot`
   - copilotId.setupReferenceType = `BotDefinition`
   - serviceChannelLabel = `Phone` (NOT `Voice Call`)

6. **Create MessagingChannel (PstnVoice)** — Use afv-pstn-forward skill:
   - MessageType = `PstnVoice` (NOT `Phone`)
   - MessagingPlatformKey = phone number
   - SessionHandlerId = FlowDefinition ID (300... prefix, NOT Flow version 301...)
   - FallbackQueueId = queue from step 3
   - IsActive = true
   - Create via REST POST (not Metadata API deploy)

7. **Verify** — Run SOQL probes:
   ```
   sf data query --query "SELECT Id, DeveloperName, SessionHandlerId, FallbackQueueId FROM MessagingChannel WHERE MessageType='PstnVoice'"
   sf data query --query "SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%<agent_name>%'" --use-tooling-api
   sf data query --query "SELECT Id, GroupId, UserOrGroupId FROM GroupMember WHERE UserOrGroupId='<my-user-id>'"
   ```

--- PATH B2: Amazon Connect (Advanced — warm transfer to live agents) ---

Use the `amazon-connect-setup` skill for full guidance. If boto3 + AWS credentials are available, phone provisioning and contact flow creation are programmatic. Otherwise, guide user through manual steps.

Phase 1 — Set up Amazon Connect (if not already configured):

1. **[MANUAL — Guide me] Enable Identity Provider:**
   - Setup → search "Identity Providers" → click Enable

2. **[MANUAL — Guide me] Turn on Salesforce Voice:**
   - Setup → search "Voice" → Amazon Setup
   - Toggle on "Enable Service Cloud Voice"
   - Enter a unique AWS root email: `username+scv[YYYYMMDD]@domain.com`
   - Click "Turn on Voice"
   - WAIT for two emails: one from AWS (sub-account enabled) + one from Salesforce (Voice is on)
   - Refresh the page after receiving both emails

3. **[MANUAL — Guide me] Confirm Tax Registration Number:**
   - Setup → Voice → Amazon Setup → Register Tax Number section
   - Click "Confirm Settings" → Acknowledge
   - (If button is greyed out, refresh and try again)

4. **[MANUAL — Guide me] Create Amazon Connect Contact Center:**
   - Setup → Voice → Amazon Contact Centers → click Refresh
   - In "Create Contact Center" section → click New
   - Display Name: `Service Cloud Voice`, API Name: `ServiceCloudVoice`
   - Region: `US West (Oregon)` (recommended)
   - Click Next → select Admin User as Contact Center Admin → Done
   - Wait for contact center to appear (may take a few minutes)

5. **Assign Contact Center permissions** (programmatic):
   - Assign `ContactCenterAdmin` permission set to admin user
   - Assign `ContactCenterAgent` permission set to rep users

6. **[MANUAL — Guide me] Claim a phone number in Amazon Connect:**
   - Setup → Voice → Amazon Contact Centers → click your contact center
   - Click "Telephony Provider Settings" (opens Amazon Connect console via SSO)
   - In Connect console: Channels → Phone Numbers → Claim a number
   - Country: United States (+1), Type: DID
   - Select any available number
   - Assign Inbound Contact Flow: "Sample SCV Inbound Flow" (temporary — replaced in step 15)
   - Click Save
   - NOTE THIS NUMBER — this is the Amazon Connect DID that customers will dial

7. **[MANUAL — Guide me] Configure Basic Queue outbound caller ID:**
   - In Amazon Connect console: Routing → Queues → Basic Queue → Edit
   - Outbound Caller ID: your claimed Amazon phone number
   - Outbound Whisper Flow: `Sample SCV Outbound Flow With Transcription Using Contact Lens`
   - Save

Phase 2 — Build the Agentforce Agent (programmatic):

8. **Create the agent** — Use the afv-pstn-forward skill:
   - Deploy EinsteinGptSettings (enable platform + all 4 fields)
   - Assign permission sets (CopilotSalesforceUser, CopilotSalesforceAdmin, AgentforceServiceAgentBuilder)
   - Create agent with `plannerType=Atlas__VoiceAgent`
   - Add BOTH `Messaging` AND `Telephony` plannerSurfaces with escalation flow references
   - Add topics + Escalation topic with `canEscalate=true`
   - Activate

9. **[MANUAL — Guide me] Add Telephony Connection in Agentforce Builder:**
   - DEACTIVATE the agent first (`sf agent deactivate`)
   - Setup → Agentforce → Agents → open your agent
   - Connections → Add Connections → + Telephony
   - Voice Settings: set Stability to 0.85
   - Configure Escalations → point to the outbound escalation flow
   - Activate the agent

10. **[MANUAL — Guide me] Get the Agentforce Voice phone number:**
    - Setup → search "Agentforce Voice" → Agentforce Voice Setup
    - Toggle ON: "Connect Related Voice Calls" + "Record Voice Calls with Agent"
    - Click "New Number" to provision the Agentforce Voice number
    - NOTE THIS NUMBER — Amazon Connect will forward calls here

Phase 3 — Wire the routing (programmatic + manual):

11. **Create Routing Config + Queue** — Use afv-pstn-forward skill:
    - RoutingModel = `ExternalRouting`
    - QueueSObject = VoiceCall
    - Add my user as queue member

12. **Deploy Inbound Voice Routing Omni-Flow** — Use afv-pstn-forward skill:
    - routingType = `Copilot`
    - copilotId.setupReferenceType = `BotDefinition`
    - serviceChannelLabel = `Phone` (NOT `Voice Call`)

13. **Deploy Escalation Flow** — Use afv-pstn-forward skill:
    - routingType = `QueueBased`
    - serviceChannelDevName = `sfdc_phone`
    - MUST deploy BEFORE the planner that references it

14. **Create MessagingChannel (PstnVoice)** — Use afv-pstn-forward skill:
    - MessageType = `PstnVoice` (NOT `Phone`)
    - MessagingPlatformKey = Agentforce Voice phone number (from step 10)
    - SessionHandlerId = FlowDefinition ID (300... prefix, NOT Flow version 301...)
    - FallbackQueueId = queue from step 11
    - IsActive = true
    - Create via REST POST (not Metadata API deploy)

15. **[MANUAL — Guide me] Create the Amazon Connect Contact Flow for AFV:**
    - In Amazon Connect console: Contact Flows → Create contact flow
    - Name: "AFV Inbound Flow"
    - Build the flow:
      a. Set Logging Behavior → Enable
      b. Set Recording and Analytics Behavior → Agent + Customer recording ON, Contact Lens enabled (Real-time + Post-call)
      c. Transfer to phone number → enter the Agentforce Voice number (from step 10), timeout 30s
      d. On transfer success → Transfer to queue (for escalation return)
      e. On failure/timeout/error → Disconnect
    - Save and Publish
    - Go to Phone Numbers → reassign your DID to use "AFV Inbound Flow"

16. **Verify** — Run SOQL probes:
    ```
    sf data query --query "SELECT Id, DeveloperName, SessionHandlerId, FallbackQueueId FROM MessagingChannel WHERE MessageType='PstnVoice'"
    sf data query --query "SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%<agent_name>%'" --use-tooling-api
    sf data query --query "SELECT Id FROM CallCenter" --target-org <alias>
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

Path B1 testing (Native PSTN):
- Call the Agentforce Voice provisioned phone number
- Talk to your agent — test the happy path and escalation
- Say "transfer me to a real person" to test escalation
- Check Omni-Channel in your org to see escalated calls arrive in the queue

Path B2 testing (Amazon Connect):
- Call the AMAZON CONNECT DID number (NOT the Agentforce Voice number directly)
- Amazon Connect receives the call and forwards to Agentforce Voice
- Talk to your agent — test the happy path
- Say "transfer me to a real person" to test escalation
- On escalation: call returns to Amazon Connect → routes to human rep via Omni-Channel
- Open Service Console → set status to Available in Omni-Channel utility bar → receive the escalated call

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
- Amazon Connect: customers must dial the Amazon Connect DID number, NOT the Agentforce Voice number directly.
- Amazon Connect: AWS does NOT support SIP external transfers for Agentforce Voice — use PSTN transfers only.
- Amazon Connect: agent must be DEACTIVATED before adding/modifying the telephony connection in Agentforce Builder.
- Amazon Connect: set voice Stability to 0.85 in the telephony connection settings.
- Amazon Connect contact center provisioning requires waiting for 2 confirmation emails (AWS + Salesforce) — there is no polling endpoint.
- If a sub-agent dispatch fails with HTTP 500 twice, fall back to inline execution.
- If `sf` commands fail with "Session expired" or "INVALID_SESSION_ID", tell the user to grab a fresh token from Agentforce Labs (Org dropdown → Org Details → SF CLI Authentication) or re-run `sf org login web`.
