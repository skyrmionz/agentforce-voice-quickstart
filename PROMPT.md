I want to build an Agentforce Voice Agent. Walk me through it end-to-end.

---

STEP 1 — ENVIRONMENT CHECK

Verify my setup before we do anything:

1. SF CLI installed:
   Run `sf --version`. If missing, install with `brew install sf`.

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
     (If this query fails on your org type, skip — license presence is validated during deploy.)

3. ADLC skill installed:
   Run `ls ~/.claude/skills/developing-agentforce/SKILL.md 2>/dev/null`.
   If missing, install: `curl -sSL https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh | bash`

4. AFCC voice skills installed:
   Check which skills are present:
   ```
   for skill in agent-on-native-voice agent-on-enhanced-chat-v2 agentforce-agent-creation omni-routing-supervisor afv-pstn-forward amazon-connect-setup; do
     [ -f ~/.claude/skills/$skill/SKILL.md ] && echo "✓ $skill" || echo "✗ $skill (missing)"
   done
   ```
   If any are missing, install from the quickstart repo:
   ```
   curl -sL https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/setup.sh | bash -s -- --bundle voice-all
   ```
   Or clone and run locally: `./setup.sh --bundle voice-all`
   (Note: some skills require Salesforce VPN + GHE access. If unavailable, proceed with what's installed.)

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

STEP 4 — CREATE BUILD PLAN

**MANDATORY.** Before building anything, create a plan file at `./BUILD_PLAN.md` in the current working directory. This is your guiding mandate for the entire build. You MUST refer to it before every deploy command to verify you're targeting the correct org.

Write it with this structure:

```markdown
# Build Plan — [Agent Name]

## Org Details
- **Alias:** <org-alias>
- **Username:** <username>
- **Instance URL:** <instance-url>
- **Org ID:** <org-id from sf org display>

## Build Details
- **Path:** <A / B1 / B2 / C>
- **Agent Name:** <developer name>
- **Agent Label:** <display name>
- **Agent User:** <agent user email — query with: sf data query --query "SELECT Username FROM User WHERE Profile.Name='Agentforce Service Agent User' LIMIT 1">
- **Queue:** <queue name for escalation>
- **Escalation Flow:** <flow developer name>

## Discovery Answers
<paste all answers from Step 3>

## Progress
- [ ] Environment verified
- [ ] Path chosen: <path>
- [ ] Discovery complete
- [ ] Plan created
- [ ] Agent .agent file written
- [ ] AiAuthoringBundle deployed
- [ ] Agent published (sf agent publish authoring-bundle)
- [ ] GenAiPlannerBundle patched (plannerType + surfaces)
- [ ] Omni-Channel configured (queue + routing)
- [ ] Escalation flow deployed
- [ ] Channel wired (MessagingChannel or PstnVoice)
- [ ] Agent activated
- [ ] [Path A] EmbeddedServiceConfig deployed
- [ ] [Path A] Voice mode enabled (manual)
- [ ] [Path A] ECV2 deployment published (manual)
- [ ] [Path B] Phone number provisioned (manual)
- [ ] [Path B] Inbound routing flow deployed
- [ ] [Path B] PstnVoice channel created (REST)
- [ ] Verification queries passed
- [ ] Testing complete

## Decisions & Notes
<track key decisions, workarounds, and anything learned during the build>
```

**RULES for the plan:**
- Read the plan before EVERY deploy or org-modifying command to confirm org alias matches.
- Update progress checkboxes as each step completes.
- If context gets compacted or conversation gets long, re-read the plan to re-anchor.
- Log any surprises, errors, or workarounds in the "Decisions & Notes" section.
- If the user provides new information that changes the build, update the plan immediately.

---

STEP 5 — BUILD

Execute the build using the installed skills as your guides. Skills contain the exact commands, error handling, and pitfalls. Read each skill file before starting that phase.

**How to use a skill:** Read `~/.claude/skills/<skill-name>/SKILL.md` and follow its step-by-step instructions. Skills are instruction documents with commands, validation queries, and error handling — not executable scripts.

=== COMMON (all paths) ===

1. **Write the agent (.agent file)**
   Read the `developing-agentforce` skill. Write an Agent Script file that defines the agent based on discovery answers.
   - Use TAB indentation (required by Agent Script)
   - Include: system instructions, model_config, config block, variables, connection messaging block, start_agent, and subagents
   - The `connection messaging:` block defines escalation routing — use `flow://` prefix for the outbound route name
   - The config `developer_name` becomes the agent's API name
   - Set `default_agent_user` to the agent user email from the plan (NOT a placeholder)

2. **Deploy the AiAuthoringBundle**
   ```
   sf project deploy start --source-dir <path-to-bundle-dir> --target-org <PLAN_ORG_ALIAS>
   ```
   Verify: deploy status = Succeeded, component type = AiAuthoringBundle.

3. **Publish the agent**
   ```
   sf agent publish authoring-bundle --api-name <bundle_developer_name> --target-org <PLAN_ORG_ALIAS>
   ```
   This compiles the Agent Script, creates Bot + BotVersion + GenAiPlanner metadata, and retrieves it back locally.
   **CRITICAL:** This command requires a full OAuth session (refresh token). If it fails with "Session expired or invalid" but other sf commands work, the user needs to re-auth with `sf org login web` (not just access-token).

4. **Patch the GenAiPlannerBundle for voice**
   After publish, retrieve the planner bundle that was created:
   - Find it locally (publish retrieves it) — look in `force-app/main/default/genAiPlannerBundles/`
   - The name may have a version suffix (e.g., `_v4`) — find the one matching your agent
   - Change `<plannerType>` from `Atlas__ConcurrentMultiAgentOrchestration` to `Atlas__VoiceAgent`
   - Add a Telephony plannerSurface (if Path B or C)
   - Verify the Messaging plannerSurface has outboundRouteConfigs pointing to your escalation flow
   - Deploy the patched planner:
     ```
     sf project deploy start --source-dir <planner-bundle-dir> --target-org <PLAN_ORG_ALIAS>
     ```

5. **Configure Omni-Channel** — Read the `omni-routing-supervisor` skill:
   - Create routing config and queue
   - Add user as queue member
   - Verify Omni-Channel settings are enabled

6. **Deploy escalation flow**
   Read the relevant skill (`agent-on-enhanced-chat-v2` for Path A, `afv-pstn-forward` for Path B).
   **MUST be deployed BEFORE the planner that references it.**

7. **Activate the agent**
   ```
   sf agent activate --api-name <agent_developer_name> --target-org <PLAN_ORG_ALIAS>
   ```

=== PATH A SPECIFIC: ECV2 Voice ===

8. **Create MessagingChannel (EmbeddedMessaging)** — Read `agent-on-enhanced-chat-v2` skill:
   - Set `sessionHandlerAsa` = agent DeveloperName (from publish — this is the Bot DeveloperName)
   - Set `sessionHandlerType` = `AgentforceServiceAgent`
   - Set `sessionHandlerQueue` = queue developer name
   - Deploy via Metadata API

9. **Create EmbeddedServiceConfig** — Read `agent-on-enhanced-chat-v2` skill:
   - Link to the MessagingChannel
   - Deploy via Metadata API

10. **[MANUAL] Enable Voice Mode:**
    Tell me: Navigate to Setup → Agents → open the agent → Channels → Enhanced Chat v2 → Voice Settings → Enable voice mode → Save.
    (Alternative: Setup → Messaging for In-App and Web → find channel → Voice Settings toggle)

11. **[MANUAL] Publish the ECV2 Deployment:**
    Tell me: Navigate to Setup → Embedded Service Deployments → find the deployment → Publish (or "Switch to v2" → "Switch & Publish").

=== PATH B1 SPECIFIC: Native PSTN ===

8. **[MANUAL] Provision phone number:**
    Tell me: Setup → Service → Voice → Agentforce Voice Setup → New Number → wait for status "Live".

9. **Deploy inbound voice routing flow** — Read `afv-pstn-forward` skill:
   - routingType = `Copilot`
   - copilotId.setupReferenceType = `BotDefinition`
   - serviceChannelLabel = `Phone` (NOT `Voice Call`)

10. **Create MessagingChannel (PstnVoice)** — Read `afv-pstn-forward` skill:
    - Create via REST POST (NOT Metadata API)
    - MessageType = `PstnVoice` (NOT `Phone`)
    - MessagingPlatformKey = phone number (E.164)
    - SessionHandlerId = FlowDefinition ID (300... prefix, NOT Flow version 301...)
    - FallbackQueueId = queue ID

=== PATH B2 SPECIFIC: Amazon Connect ===

Read the `amazon-connect-setup` skill for the full guided workflow. It covers:
- Identity provider setup, Voice enablement, tax registration
- Contact center creation, phone provisioning, contact flow
- Integration with the Agentforce agent built in the common steps above

=== PATH C: Both ===

Do Path A first (steps 8-11), then Path B (steps 8-10). The agent already has both Messaging + Telephony surfaces from step 4.

---

STEP 6 — VERIFY & TEST

Run verification queries (substitute actual values from your BUILD_PLAN.md):

```
sf data query --query "SELECT Id, DeveloperName FROM BotDefinition WHERE DeveloperName='<agent_name>'" --target-org <alias>
sf data query --query "SELECT Id, DeveloperName, SessionHandlerType FROM MessagingChannel WHERE DeveloperName='<channel_name>'" --target-org <alias>
```

Path A: confirm EmbeddedServiceConfig is deployed and channel has sessionHandlerAsa set.
Path B: confirm PstnVoice channel has correct SessionHandlerId and FallbackQueueId.

Test the agent:
- Path A: Open website → chat widget → voice mode → talk to agent
- Path B1: Call the provisioned phone number
- Path B2: Call the Amazon Connect DID number (NOT the AFV number)
- All paths: test escalation ("transfer me to a person")

Use `/testing-agentforce` to create an automated test suite.

---

STEP 7 — REPORT

Tell me:
- Which path(s) were deployed
- How to test (URL for Path A, phone number for Path B)
- What the agent handles and what it refuses
- Any manual Setup steps still needed
- How to receive escalated conversations (Omni-Channel widget in Service Console)
- What to do next (add more topics, tune the agent, add the other path)

Update BUILD_PLAN.md with final status.

---

RULES:
- **ALWAYS read BUILD_PLAN.md before any deploy or org command.** Verify org alias matches. This prevents deploying to the wrong org.
- **ALWAYS use `--target-org <alias>` on every sf command.** Never rely on the default org.
- Use `curl -sL` to fetch remote files (not WebFetch/Read on URLs — those summarize content).
- Parse SF CLI JSON output with `jq` or `grep`, never inline Python.
- To "use a skill": read `~/.claude/skills/<skill-name>/SKILL.md` and follow its instructions. Skills are documents, not executables.
- `sf agent publish authoring-bundle` is ADLC. `sf agent create` from a spec YAML is the OLD BUILDER — never use it.
- `sf agent publish authoring-bundle` requires full OAuth (refresh token). Access-token-only auth will fail with "Session expired." Guide user to `sf org login web` if this happens.
- After publish, the GenAiPlannerBundle `plannerType` will be `Atlas__ConcurrentMultiAgentOrchestration` — you MUST patch it to `Atlas__VoiceAgent` for voice.
- The planner bundle name after publish may have a version suffix (e.g., `_v4`). Find it by listing `force-app/main/default/genAiPlannerBundles/`.
- MessagingChannel (PstnVoice) must be created via REST POST, not Metadata API deploy.
- MessagingChannel (EmbeddedMessaging) is created via Metadata API deploy.
- Deploy escalation flow BEFORE the planner that references it.
- Use `MessageType=PstnVoice`, NOT `Phone`.
- Do not set `ChannelAddressIdentifier` on voice channels (system-assigned).
- `SessionHandlerId` must be a FlowDefinition ID (300...), NOT Flow version (301...).
- `isVoiceModeEnabled` cannot be deployed via Metadata API — always guide user through Builder UI.
- Agent drops calls/chats in <15 sec without topics — always add at least one topic.
- Queue `RoutingModel` must be `ExternalRouting` for PSTN voice (not `LeastActive`).
- Deactivate agent before deploying planner changes if it's active, then reactivate after.
- `sf agent deactivate/activate` requires working dir to be an SFDX project directory.
- Block on manual-step confirmation — don't queue more work until I confirm the UI step is done.
- Amazon Connect: customers must dial the Amazon Connect DID number, NOT the Agentforce Voice number directly.
- Amazon Connect: AWS does NOT support SIP external transfers for Agentforce Voice — use PSTN transfers only.
- Amazon Connect: agent must be DEACTIVATED before adding/modifying the telephony connection in Agentforce Builder.
- Amazon Connect: set voice Stability to 0.85 in the telephony connection settings.
- Amazon Connect contact center provisioning requires waiting for 2 confirmation emails (AWS + Salesforce) — there is no polling endpoint.
- If `sf` commands fail with "Session expired" or "INVALID_SESSION_ID", tell the user to re-auth with `sf org login web` or grab a fresh token.
- If a deploy fails with "DeveloperName already in use", a legacy bot with that name may exist. Use a different developer_name or delete the conflicting bot.
- The `default_agent_user` in the .agent file MUST be a real user in the target org. Query for it: `sf data query --query "SELECT Username FROM User WHERE Profile.Name='Agentforce Service Agent User' LIMIT 1"`.
