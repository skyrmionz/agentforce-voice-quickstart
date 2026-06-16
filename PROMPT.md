# Voice Agent Build Prompt

Paste this into Claude Code. Claude will check your environment, install skills if needed, ask discovery questions, and build the agent end-to-end.

---

## The Prompt

```
I want to build an Agentforce Voice Agent I can call from my phone. Walk me through it end-to-end.

---

STEP 1 — ENVIRONMENT CHECK

Verify my setup before we do anything:

1. SF CLI installed:
   Run `sf --version`. If missing, install with `brew install sf`.

2. SF CLI authenticated to my org:
   Run `sf org display --json`.
   - If not authenticated, ask me for my org's instance URL and help me log in via `sf org login web` or access token.
   - Confirm the org has Agentforce Contact Center licenses by running:
     `sf data query --query "SELECT MasterLabel, TotalLicenses, UsedLicenses FROM UserLicense WHERE MasterLabel LIKE '%Service%'" --json`

3. Agentforce ADLC skills installed:
   Run `ls ~/.claude/skills/developing-agentforce/SKILL.md 2>/dev/null`.
   If missing, install: `curl -sSL https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh | bash`
   (Note: skill changes require restarting Claude Code to take effect.)

4. AFCC voice skills installed:
   Run `ls ~/.claude/skills/agent-on-native-voice/SKILL.md 2>/dev/null`.
   If missing, install from the repo:
   ```
   git clone https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm.git /tmp/afcc-skills
   BASE="/tmp/afcc-skills/workgroups/afcc_afv_headless_demo/Headless Skills"
   mkdir -p ~/.claude/skills/agent-on-native-voice && cp "$BASE/Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md" ~/.claude/skills/agent-on-native-voice/SKILL.md
   mkdir -p ~/.claude/skills/agentforce-agent-creation && cp "$BASE/Agent Configuration/Agentforce Agent Creation/Skill.md" ~/.claude/skills/agentforce-agent-creation/SKILL.md
   mkdir -p ~/.claude/skills/omni-routing-supervisor && cp "$BASE/Omni Configuration/Omni Routing Rep Supervisor Setup/SKILL.md" ~/.claude/skills/omni-routing-supervisor/SKILL.md
   cp -R "$BASE/Omni Configuration/Omni Routing Rep Supervisor Setup/artifacts" ~/.claude/skills/omni-routing-supervisor/
   mkdir -p ~/.claude/skills/voice-channel-omni-queue && cp "$BASE/Channel Configuration/Voice channel with omni queue/skill/SKILL.md" ~/.claude/skills/voice-channel-omni-queue/SKILL.md
   mkdir -p ~/.claude/skills/transcription-recording && cp "$BASE/Enable transcription and recording/SKILL.md" ~/.claude/skills/transcription-recording/SKILL.md
   ```
   (Note: requires Salesforce VPN + GHE access. If unavailable, proceed with ADLC skills only.)

5. Phone number provisioned:
   Run: `sf data query --query "SELECT Id, DeveloperName, MessagingPlatformKey FROM MessagingChannel WHERE MessageType='PstnVoice'" --json`
   If no results, ask me to provision a number in Setup > Communication Channels > Numbers.

Report what's ready and what's missing. Fix what you can automatically. For anything that needs my input (org credentials, phone number), ask me.

---

STEP 2 — DISCOVERY

Once the environment is confirmed, ask me these questions (one message, I'll answer all at once):

1. What's your org alias? (from `sf org list`)
2. What business is this agent for? (company name + 1-sentence description)
3. What should the agent handle? (e.g., order status, appointment scheduling, FAQ, returns)
4. What's the agent's name and personality? (e.g., "Alex — friendly and concise")
5. What's your provisioned phone number? (E.164 format, e.g. +14155551234)
6. What's your Salesforce username? (for queue membership so you receive escalated calls)
7. Any topics the agent should refuse or escalate immediately? (e.g., billing disputes, cancellations)

---

STEP 3 — BUILD

With my answers, execute the full build using the installed skills:

1. **Create the agent** — Use /developing-agentforce:
   - Generate agent spec via `sf agent generate agent-spec`
   - Create agent via `sf agent create`
   - Retrieve metadata, fix the planner bundle:
     - `genAiPlugins` → `localTopicLinks`
     - `plannerType` → `Atlas__VoiceAgent`
     - Add `Telephony` plannerSurface with escalation flow reference
   - Set `canEscalate=true` on the escalation topic
   - Deploy and activate

2. **Wire voice channel** — Use the agent-on-native-voice skill:
   - Create escalation routing flow (routes to human queue on `sfdc_phone`)
   - Create inbound routing flow (routes to the agent, `routingType=Copilot`)
   - Create or identify the `MessagingChannel` (type `PstnVoice`) via REST
   - Wire `SessionHandlerId` (use the FlowDefinition 300-ID, not the version 301-ID)
   - Set `FallbackQueueId`

3. **Configure Omni-Channel** — Use the omni-routing-supervisor skill:
   - Ensure routing config, queue, and presence statuses exist
   - Add my user as a queue member
   - Verify Omni-Channel settings are enabled

4. **Verify the wiring** — Run SOQL probes:
   ```
   sf data query --query "SELECT Id, DeveloperName, SessionHandlerId, FallbackQueueId FROM MessagingChannel WHERE MessageType='PstnVoice'"
   sf data query --query "SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%Route%'" --use-tooling-api
   sf data query --query "SELECT Id, GroupId, UserOrGroupId FROM GroupMember WHERE UserOrGroupId='<my-user-id>'"
   ```

5. **Test** — Use /testing-agentforce:
   - Create a basic test suite covering: greeting, topic routing, escalation trigger, out-of-scope refusal
   - Run the tests and report results
   - Iterate on any failures

6. **Report** — Tell me:
   - The phone number to call
   - What the agent will handle
   - Any manual Setup steps I need to do (e.g., Omni-Channel login behavior radio)
   - How to receive escalated calls (Omni-Channel widget in Service Console)

---

RULES:
- Use `--async` + poll for multi-component deploys, never `--wait N` for long deploys.
- Parse SF CLI JSON output with `jq`, never inline Python.
- MessagingChannel (PstnVoice) must be created via REST POST, not Metadata API deploy.
- Deploy escalation flow BEFORE the planner that references it.
- Use `MessageType=PstnVoice`, NOT `Phone`.
- Do not set `ChannelAddressIdentifier` on voice channels (system-assigned).
- If a sub-agent dispatch fails with HTTP 500 twice, fall back to inline execution.
- Block on manual-step confirmation — don't queue more work until I confirm.
```
