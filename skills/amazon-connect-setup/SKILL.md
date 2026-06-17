# Amazon Connect Setup for Agentforce Voice

## Metadata

```yaml
name: amazon-connect-setup
description: Configure Amazon Connect as telephony provider for Agentforce Voice (Path B2). Creates contact center, provisions phone number, builds contact flow, and wires routing — programmatically where possible via AWS SDK, with guided manual steps where APIs don't exist.
triggers:
  - "setup Amazon Connect"
  - "configure Amazon Connect for voice"
  - "Path B2"
  - "warm transfer setup"
  - "Amazon Connect contact center"
```

---

## Overview

This skill sets up **Salesforce Voice with Amazon Connect (Resell/Bundle model)** and wires it to Agentforce Voice for the full warm-transfer experience:

**Call flow:** Customer dials Amazon Connect DID → Connect contact flow forwards via PSTN to Agentforce Voice number → AI agent handles conversation → on escalation, call returns to Connect → routes to human rep via Omni-Channel.

**What's automatable vs manual:**

| Phase | Automatable | Manual (guided) |
|---|---|---|
| Identity Provider enablement | No | Setup UI toggle |
| Turn on Salesforce Voice | No | Setup UI + wait for 2 emails |
| Tax Registration Number | No | Setup UI acknowledgment |
| Contact Center creation | No | Setup UI wizard + wait for provisioning |
| Permission set assignment | Yes (SF CLI / REST API) | — |
| Phone number claiming (AWS) | Yes (boto3 `ClaimPhoneNumber`) | Alt: Connect console UI |
| Contact flow creation (AWS) | Yes (boto3 `CreateContactFlow`) | Alt: Connect console UI |
| Phone→flow association (AWS) | Yes (boto3 `AssociatePhoneNumberContactFlow`) | — |
| Queue outbound config (AWS) | Yes (boto3 `UpdateQueueOutboundCallerConfig`) | Alt: Connect console UI |
| Agentforce Voice number | No | Setup UI "New Number" button |
| Telephony connection on agent | No | Agentforce Builder UI |

---

## Prerequisites

Before running this skill:

1. **SF CLI authenticated** — `sf org display --json` returns a valid org
2. **Python 3.8+** installed — `python3 --version`
3. **boto3 installed** — `pip3 install boto3` (only needed for programmatic path)
4. **AWS credentials configured** (only needed for programmatic path):
   - Either `~/.aws/credentials` with a profile that has `AmazonConnectFullAccess` policy
   - Or environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`

> **Note:** If the user does NOT have AWS credentials or boto3, fall back to guiding them through the Amazon Connect console UI for steps 6–9. The Salesforce-side steps (1–5, 10+) don't require AWS access.

---

## Required Inputs

| Input | Example | How to get it |
|---|---|---|
| SF org alias | `my-org` | `sf org list` |
| AWS region | `us-west-2` | User choice (us-west-2 recommended for US) |
| Amazon Connect Instance ID | `abc123-...` | After step 4, from `sf data query` or Connect console URL |
| Amazon Connect Instance ARN | `arn:aws:connect:...` | After step 4, from Connect console |
| Agentforce Voice phone number | `+14155551234` | After step 10 (provisioned in SF Setup) |
| Agent API name | `My_Voice_Agent` | From agent creation step |

---

## Phase 1 — Enable Salesforce Voice (Manual — guide user through each step)

### Step 1: Enable Identity Provider

```
[MANUAL — Guide user]
1. Setup → search "Identity Providers" in Quick Find
2. Click "Enable"
3. If you get an error on first attempt, retry
```

**Verification:**
```bash
sf org open --path "/lightning/setup/IdProvider/home" --target-org <alias>
```

### Step 2: Turn on Salesforce Voice

```
[MANUAL — Guide user]
1. Setup → search "Voice" → select "Amazon Setup"
2. Toggle ON "Enable Service Cloud Voice"
3. Enter a unique AWS root email: username+scv[YYYYMMDD]@yourdomain.com
   (Use a unique suffix each time — AWS requires globally unique emails)
4. Click "Turn on Voice"
5. WAIT for TWO emails:
   - One from AWS (sub-account enabled)
   - One from Salesforce (Voice is on)
6. After receiving BOTH emails, refresh the Setup page
```

> **⚠️ No polling endpoint exists.** The user must wait for emails (typically 2–10 minutes). Do NOT proceed until they confirm both emails received.

### Step 3: Confirm Tax Registration Number

```
[MANUAL — Guide user]
1. Setup → search "Voice" → select "Amazon Setup"
2. In the "Register Tax Number" section, click "Confirm Settings"
3. Click "Acknowledge"

If "Confirm Settings" is greyed out: refresh the page and try again.
```

### Step 4: Create Amazon Connect Contact Center

```
[MANUAL — Guide user]
1. Setup → search "Voice" → select "Amazon Contact Centers"
2. Click "Refresh" to ensure latest state loads
3. In the "Create Contact Center" section, click "New"
4. Fill in:
   - Display Name: Service Cloud Voice
   - API Name: ServiceCloudVoice
   - Region: US West (Oregon) [recommended for US demos]
5. Click "Next"
6. Select Admin User as Contact Center Admin (click +)
7. Click "Done"
8. Wait for the contact center to appear (may take a few minutes — refresh periodically)
```

**Verification (after contact center appears):**
```bash
sf data query --query "SELECT Id, InternalName FROM CallCenter LIMIT 5" --target-org <alias>
```

### Step 5: Assign Contact Center Permissions (Programmatic)

```bash
# Get the running user's ID
USER_ID=$(sf data query --query "SELECT Id FROM User WHERE Username='<username>'" --target-org <alias> --json | jq -r '.result.records[0].Id')

# Assign ContactCenterAdmin
ADMIN_PS_ID=$(sf data query --query "SELECT Id FROM PermissionSet WHERE Name='ContactCenterAdmin'" --target-org <alias> --json | jq -r '.result.records[0].Id')
sf data create record --sobject PermissionSetAssignment --values "AssigneeId='$USER_ID' PermissionSetId='$ADMIN_PS_ID'" --target-org <alias>

# Assign ContactCenterAgent
AGENT_PS_ID=$(sf data query --query "SELECT Id FROM PermissionSet WHERE Name='ContactCenterAgent'" --target-org <alias> --json | jq -r '.result.records[0].Id')
sf data create record --sobject PermissionSetAssignment --values "AssigneeId='$USER_ID' PermissionSetId='$AGENT_PS_ID'" --target-org <alias>
```

---

## Phase 2 — Provision Phone Number + Contact Flow (Programmatic via boto3 OR Manual)

### Step 6: Claim a Phone Number

**Option A — Programmatic (boto3):**

```python
#!/usr/bin/env python3
"""Claim a DID phone number in Amazon Connect."""
import boto3
import sys
import json

REGION = sys.argv[1] if len(sys.argv) > 1 else 'us-west-2'
INSTANCE_ID = sys.argv[2]  # Amazon Connect Instance ID

connect = boto3.client('connect', region_name=REGION)

# Get the instance ARN
instance = connect.describe_instance(InstanceId=INSTANCE_ID)
instance_arn = instance['Instance']['Arn']

# Search for available DID numbers
available = connect.search_available_phone_numbers(
    TargetArn=instance_arn,
    PhoneNumberCountryCode='US',
    PhoneNumberType='DID',
    MaxResults=10
)

if not available.get('AvailableNumbersList'):
    print("ERROR: No phone numbers available. Try a different region or file an AWS support case.", file=sys.stderr)
    sys.exit(1)

# Claim the first available number
phone_number = available['AvailableNumbersList'][0]['PhoneNumber']
claimed = connect.claim_phone_number(
    TargetArn=instance_arn,
    PhoneNumber=phone_number
)

result = {
    "phoneNumber": phone_number,
    "phoneNumberId": claimed['PhoneNumberId'],
    "phoneNumberArn": claimed['PhoneNumberArn'],
    "instanceArn": instance_arn
}
print(json.dumps(result, indent=2))
```

Run:
```bash
python3 claim_phone_number.py us-west-2 <INSTANCE_ID>
```

**Option B — Manual (Connect console):**

```
[MANUAL — Guide user]
1. Setup → Voice → Amazon Contact Centers → click your contact center name
2. Click "Telephony Provider Settings" (opens Amazon Connect console via SSO)
3. In Connect console: hover Channels icon (left nav) → select "Phone Numbers"
4. Click "Claim a number"
5. Country: United States (+1)
6. Type: DID (Direct Inward Dialing)
7. Select any available number from the list
8. Assign Inbound Contact Flow: "Sample SCV Inbound Flow" (temporary — replaced in step 8)
9. Click "Save"
10. NOTE THIS NUMBER — this is the Amazon Connect DID that customers will dial
```

### Step 7: Configure Basic Queue Outbound Caller ID

**Option A — Programmatic (boto3):**

```python
#!/usr/bin/env python3
"""Configure the Basic Queue outbound caller ID."""
import boto3
import sys

REGION = sys.argv[1] if len(sys.argv) > 1 else 'us-west-2'
INSTANCE_ID = sys.argv[2]
PHONE_NUMBER_ID = sys.argv[3]

connect = boto3.client('connect', region_name=REGION)

# Find the Basic Queue
queues = connect.list_queues(InstanceId=INSTANCE_ID, QueueTypes=['STANDARD'])
basic_queue = next((q for q in queues['QueueSummaryList'] if q['Name'] == 'BasicQueue'), None)

if not basic_queue:
    print("ERROR: BasicQueue not found. Looking for available queues...")
    for q in queues['QueueSummaryList']:
        print(f"  - {q['Name']} ({q['Id']})")
    sys.exit(1)

# Find the outbound whisper flow
flows = connect.list_contact_flows(InstanceId=INSTANCE_ID, ContactFlowTypes=['OUTBOUND_WHISPER'])
whisper_flow = next(
    (f for f in flows['ContactFlowSummaryList']
     if 'Transcription' in f['Name'] and 'Contact Lens' in f['Name']),
    None
)

config = {
    'OutboundCallerIdName': 'Service Cloud Voice',
    'OutboundCallerIdNumberId': PHONE_NUMBER_ID,
}
if whisper_flow:
    config['OutboundFlowId'] = whisper_flow['Id']

connect.update_queue_outbound_caller_config(
    InstanceId=INSTANCE_ID,
    QueueId=basic_queue['Id'],
    OutboundCallerConfig=config
)
print(f"BasicQueue updated with outbound caller ID: {PHONE_NUMBER_ID}")
```

**Option B — Manual (Connect console):**

```
[MANUAL — Guide user]
1. In Amazon Connect console: Routing → Queues
2. Select "Basic Queue" → click Edit
3. Set Outbound Caller ID: your claimed Amazon phone number
4. Set Outbound Whisper Flow: "Sample SCV Outbound Flow With Transcription Using Contact Lens"
5. Click Save
```

### Step 8: Create the AFV Inbound Contact Flow

**Option A — Programmatic (boto3):**

```python
#!/usr/bin/env python3
"""Create the AFV inbound contact flow and associate it with the phone number."""
import boto3
import sys
import json

REGION = sys.argv[1] if len(sys.argv) > 1 else 'us-west-2'
INSTANCE_ID = sys.argv[2]
PHONE_NUMBER_ID = sys.argv[3]
AFV_PHONE_NUMBER = sys.argv[4]  # Agentforce Voice number (from SF Setup, e.g. +14155551234)

connect = boto3.client('connect', region_name=REGION)

# Find the Basic Queue ID for escalation routing
queues = connect.list_queues(InstanceId=INSTANCE_ID, QueueTypes=['STANDARD'])
basic_queue = next((q for q in queues['QueueSummaryList'] if q['Name'] == 'BasicQueue'), None)
basic_queue_id = basic_queue['Id'] if basic_queue else 'BASIC_QUEUE_ID'
basic_queue_arn = basic_queue['Arn'] if basic_queue else ''

# Contact Flow JSON — routes calls to Agentforce Voice via PSTN transfer
flow_content = json.dumps({
    "Version": "2019-10-30",
    "StartAction": "set-logging",
    "Actions": [
        {
            "Identifier": "set-logging",
            "Type": "UpdateFlowLoggingBehavior",
            "Parameters": {"LoggingBehavior": "Enable"},
            "Transitions": {"NextAction": "set-recording"}
        },
        {
            "Identifier": "set-recording",
            "Type": "UpdateContactRecordingBehavior",
            "Parameters": {
                "RecordingBehavior": {
                    "RecordedParticipants": ["Agent", "Customer"]
                },
                "AnalyticsBehavior": {
                    "Enabled": "True",
                    "AnalyticsLanguage": "en-US",
                    "AnalyticsRedactionBehavior": "Disabled",
                    "AnalyticsModes": ["RealTime", "PostContact"]
                }
            },
            "Transitions": {"NextAction": "transfer-to-afv"}
        },
        {
            "Identifier": "transfer-to-afv",
            "Type": "TransferToPhoneNumber",
            "Parameters": {
                "PhoneNumber": {"Value": AFV_PHONE_NUMBER},
                "CallTimeout": "30"
            },
            "Transitions": {
                "Success": "transfer-to-queue",
                "CallFailure": "disconnect",
                "Timeout": "disconnect",
                "Error": "disconnect"
            }
        },
        {
            "Identifier": "transfer-to-queue",
            "Type": "TransferContactToQueue",
            "Parameters": {
                "QueueId": {"Type": "UserDefined", "Value": basic_queue_arn}
            },
            "Transitions": {
                "Success": "disconnect",
                "AtCapacity": "disconnect",
                "Error": "disconnect"
            }
        },
        {
            "Identifier": "disconnect",
            "Type": "DisconnectParticipant",
            "Parameters": {},
            "Transitions": {}
        }
    ]
})

# Create the contact flow
flow = connect.create_contact_flow(
    InstanceId=INSTANCE_ID,
    Name='AFV Inbound Flow',
    Description='Routes inbound calls to Agentforce Voice via PSTN transfer. On escalation, transfers to BasicQueue for human agent.',
    Type='CONTACT_FLOW',
    Content=flow_content
)

flow_id = flow['ContactFlowId']
flow_arn = flow['ContactFlowArn']
print(f"Contact flow created: {flow_id}")
print(f"ARN: {flow_arn}")

# Associate the phone number with the new flow
connect.associate_phone_number_contact_flow(
    PhoneNumberId=PHONE_NUMBER_ID,
    InstanceId=INSTANCE_ID,
    ContactFlowId=flow_id
)
print(f"Phone number {PHONE_NUMBER_ID} now routes to AFV Inbound Flow")

result = {
    "contactFlowId": flow_id,
    "contactFlowArn": flow_arn,
    "afvPhoneNumber": AFV_PHONE_NUMBER,
    "basicQueueId": basic_queue_id
}
print(json.dumps(result, indent=2))
```

Run:
```bash
python3 create_afv_flow.py us-west-2 <INSTANCE_ID> <PHONE_NUMBER_ID> <AFV_PHONE_NUMBER>
```

**Option B — Manual (Connect console):**

```
[MANUAL — Guide user]
1. In Amazon Connect console: Contact Flows → Create contact flow
2. Name: "AFV Inbound Flow"
3. Build the flow with these blocks (in order):
   a. "Set Logging Behavior" → Enable logging
   b. "Set Recording and Analytics Behavior":
      - Channel: Voice
      - Agent and customer voice recording: ON (Agent and customer)
      - Automated interaction call recording: Off
      - Contact Lens speech analytics: Enabled (Real-time and post-call analytics)
   c. "Transfer to phone number":
      - Set Manually → enter the Agentforce Voice phone number
      - Timeout: 30 seconds
      - On Success → connect to "Transfer to queue" (step d)
      - On CallFailure, Timeout, Error → connect to "Disconnect" (step e)
   d. "Transfer to queue":
      - Queue: Basic Queue
      - At Capacity → Disconnect
      - Error → Disconnect
   e. "Disconnect participant"
4. Click "Save" then "Publish"
5. Go to Phone Numbers → click your DID → change Contact Flow to "AFV Inbound Flow"
6. Click Save
```

### Step 9: Verify Amazon Connect Setup

```bash
# Verify CallCenter exists in Salesforce
sf data query --query "SELECT Id, InternalName, AdapterUrl FROM CallCenter" --target-org <alias>
```

If using boto3, also verify:
```python
# Verify phone number is associated with the flow
phone_numbers = connect.list_phone_numbers_v2(TargetArn=instance_arn)
for pn in phone_numbers.get('ListPhoneNumbersSummaryList', []):
    print(f"{pn['PhoneNumber']} → flow: {pn.get('TargetArn', 'none')}")
```

---

## Phase 3 — Provision Agentforce Voice Number + Wire Agent (Salesforce side)

### Step 10: Get the Agentforce Voice Phone Number

```
[MANUAL — Guide user]
1. Setup → search "Agentforce Voice" → Agentforce Voice Setup
2. Toggle ON: "Connect Related Voice Calls"
3. Toggle ON: "Record Voice Calls with Agent"
4. Click "New Number" to provision the Agentforce Voice number
5. Wait for status to show "Live"
6. NOTE THIS NUMBER — this is what Amazon Connect will forward calls to

⚠️ No public API exists for the "New Number" button.
This step must be done via Setup UI.
```

### Step 11: Add Telephony Connection to Agent

```
[MANUAL — Guide user]
1. DEACTIVATE the agent first:
   sf agent deactivate --name <agent_api_name> --target-org <alias>
2. Setup → Agentforce → Agents → open your agent
3. Click "Connections" tab → "Add Connections" → select "+ Telephony"
4. In Voice Settings:
   - Set Stability to 0.85 (recommended for consistent voice quality)
   - Select preferred voice persona
5. Configure Escalations:
   - Point to the outbound escalation Omni-Channel flow
6. Click Save
7. Reactivate the agent:
   sf agent activate --name <agent_api_name> --target-org <alias>

⚠️ Agent MUST be deactivated before adding/modifying telephony connection.
Making changes while active causes "Agentforce Voice not answering calls" errors.
```

### Step 12: Create the Salesforce-side Routing (use afv-pstn-forward skill)

At this point, hand off to the `afv-pstn-forward` skill for:

- Create Routing Config + Queue (`RoutingModel=ExternalRouting`, `QueueSObject=VoiceCall`)
- Deploy Inbound Voice Routing Omni-Flow (`routingType=Copilot`)
- Deploy Escalation Flow (`routingType=QueueBased`, `serviceChannelDevName=sfdc_phone`)
- Create MessagingChannel (`PstnVoice` type, `SessionHandlerId=FlowDefinition ID`)

These are fully programmatic — see the `afv-pstn-forward` skill for implementation details.

---

## Phase 4 — Verify End-to-End

### Step 13: Run Verification Queries

```bash
# Salesforce side
sf data query --query "SELECT Id, DeveloperName, SessionHandlerId, FallbackQueueId FROM MessagingChannel WHERE MessageType='PstnVoice'" --target-org <alias>
sf data query --query "SELECT Id FROM CallCenter" --target-org <alias>
sf data query --query "SELECT Id, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%Inbound%'" --target-org <alias> --use-tooling-api

# Check agent is active
sf data query --query "SELECT Id, DeveloperName, Status FROM BotDefinition WHERE DeveloperName='<agent_api_name>'" --target-org <alias> --use-tooling-api
```

### Step 14: Test the Call

```
[Guide user]
1. Open Service Console app (App Launcher → Service Console)
2. Open Omni-Channel utility bar → set status to "Available"
3. From your phone, dial the AMAZON CONNECT DID number
   (NOT the Agentforce Voice number — that's internal only)
4. Expected flow:
   - Amazon Connect receives the call
   - Contact flow transfers to Agentforce Voice number
   - AI agent greets you and handles the conversation
   - Say "transfer me to a real person" to test escalation
   - Call returns to Amazon Connect → routes to human via Omni-Channel
   - You receive the call in Service Console with full context
```

---

## Contact Flow JSON Reference

The complete Amazon Connect contact flow JSON for direct import. Replace `AGENTFORCE_VOICE_PHONE_NUMBER` with your provisioned number and `BASIC_QUEUE_ARN` with your queue ARN:

```json
{
  "Version": "2019-10-30",
  "StartAction": "set-logging",
  "Actions": [
    {
      "Identifier": "set-logging",
      "Type": "UpdateFlowLoggingBehavior",
      "Parameters": {"LoggingBehavior": "Enable"},
      "Transitions": {"NextAction": "set-recording"}
    },
    {
      "Identifier": "set-recording",
      "Type": "UpdateContactRecordingBehavior",
      "Parameters": {
        "RecordingBehavior": {
          "RecordedParticipants": ["Agent", "Customer"]
        },
        "AnalyticsBehavior": {
          "Enabled": "True",
          "AnalyticsLanguage": "en-US",
          "AnalyticsRedactionBehavior": "Disabled",
          "AnalyticsModes": ["RealTime", "PostContact"]
        }
      },
      "Transitions": {"NextAction": "transfer-to-afv"}
    },
    {
      "Identifier": "transfer-to-afv",
      "Type": "TransferToPhoneNumber",
      "Parameters": {
        "PhoneNumber": {"Value": "AGENTFORCE_VOICE_PHONE_NUMBER"},
        "CallTimeout": "30"
      },
      "Transitions": {
        "Success": "transfer-to-queue",
        "CallFailure": "disconnect",
        "Timeout": "disconnect",
        "Error": "disconnect"
      }
    },
    {
      "Identifier": "transfer-to-queue",
      "Type": "TransferContactToQueue",
      "Parameters": {
        "QueueId": {"Type": "UserDefined", "Value": "BASIC_QUEUE_ARN"}
      },
      "Transitions": {
        "Success": "disconnect",
        "AtCapacity": "disconnect",
        "Error": "disconnect"
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| No phone numbers available | AWS region limits | Try a different region or file AWS support case |
| "Confirm Settings" button greyed out | Page not fully loaded | Refresh the page |
| Contact center not appearing after creation | AWS provisioning delay | Wait 2–5 minutes and refresh |
| Calls go to Agentforce but no escalation to human | Contact flow missing "Transfer to queue" block | Edit flow: add Transfer to queue after AFV transfer success |
| Calling AFV number directly skips Amazon Connect | Wrong number dialed | Always dial the Amazon Connect DID — that's the customer-facing number |
| SSO failure / "Fail to connect to telephone provider" | Browser cookie/permission issue | Check third-party cookies and microphone permissions |
| boto3 `ClaimPhoneNumber` fails | Wrong ARN or insufficient permissions | Verify ARN with `describe_instance`; ensure IAM policy has `AmazonConnectFullAccess` |
| Agent not answering after telephony connection added | Agent was active during modification | Deactivate agent → re-add telephony connection → reactivate |
| Voice quality issues (choppy, delayed) | Network latency to AWS region | Ensure < 200ms latency, > 100 Kbps bandwidth to the Connect region |
| E-1012 Omni-Channel error | Routing config not linked to Voice Channel | Verify Omni-Channel routing config is linked to Voice Channel |
| `SDO_Service_Voice_Call_On_Create` flow interfering | Pre-existing SDO flow auto-routing calls | Deactivate that flow in Setup → Flows |

---

## Key Rules

- **PSTN only, no SIP:** AWS does NOT support SIP external transfers for Agentforce Voice. All transfers use PSTN.
- **Voice Stability:** Set to 0.85 in telephony connection settings for consistent quality.
- **Agent must be deactivated** when modifying telephony connections in Agentforce Builder.
- **Dial the Amazon Connect DID** — never the Agentforce Voice number directly (that bypasses the full flow).
- **Two emails required** — do NOT proceed past Step 2 until both AWS and Salesforce emails are received.
- **Contact center provisioning has no polling endpoint** — must wait for UI to show it.
- **Agentforce Voice "New Number" has no public API** — must use Setup UI.
- **boto3 requires `AmazonConnectFullAccess`** IAM policy on the credentials being used.
