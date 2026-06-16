#!/usr/bin/env bash
# ==========================================================================
# Agentforce Voice Quickstart — Setup Script
#
# Installs all required Claude Code skills for building a Voice Agent.
# Run this once, restart Claude Code, then paste the prompt from PROMPT.md.
#
# Usage:
#   ./setup.sh              # Install all skills (full suite)
#   ./setup.sh --minimal    # Voice-only skills (faster, no GHE needed)
#   ./setup.sh --uninstall  # Remove skills installed by this script
# ==========================================================================
set -euo pipefail

# ---------- colors ----------
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'
    RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; YELLOW=''; BLUE=''; RED=''; BOLD=''; NC=''
fi
info()  { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()    { printf "${GREEN} ✓${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW} !${NC}  %s\n" "$*"; }
err()   { printf "${RED} ✗${NC}  %s\n" "$*" >&2; }

# ---------- args ----------
MODE="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)   MODE="minimal"; shift ;;
        --full)      MODE="full"; shift ;;
        --uninstall) MODE="uninstall"; shift ;;
        -h|--help)
            echo "Usage: ./setup.sh [--minimal | --full | --uninstall]"
            echo "  --full      Install all AFCC skills (requires GHE access)"
            echo "  --minimal   Install only ADLC skills (no GHE needed)"
            echo "  --uninstall Remove skills installed by this script"
            exit 0 ;;
        *) err "Unknown flag: $1"; exit 2 ;;
    esac
done

SKILLS_DIR="$HOME/.claude/skills"
CMDS_DIR="$HOME/.claude/commands"

# ---------- uninstall ----------
if [[ "$MODE" == "uninstall" ]]; then
    info "Removing Agentforce Voice Quickstart skills..."
    VOICE_SKILLS=(
        agent-on-native-voice agentforce-agent-creation omni-routing-supervisor
        voice-channel-omni-queue transcription-recording afcc-headless-configurator
        afcc-demo-prep license-audit afv-pstn-forward voice-reports
        agent-on-enhanced-chat agent-on-enhanced-chat-v2 agent-on-3p-channels
        enhanced-chat enhanced-chat-v2 sms-channel whatsapp-channel
        line-channel apple-messages-channel facebook-messenger-channel
        service-ai-grounding agentforce-service-assistant
        einstein-article-recommendations einstein-service-replies
        einstein-conversation-insights conversation-mining voice-messaging-nba
        knowledge-creation real-time-translations work-summaries
        banking-agentforce-agent
    )
    for s in "${VOICE_SKILLS[@]}"; do
        if [[ -d "$SKILLS_DIR/$s" ]]; then
            rm -rf "$SKILLS_DIR/$s"
            ok "Removed $s"
        fi
    done
    for c in afcc-spar afcc-quickstart afcc-build; do
        [[ -e "$CMDS_DIR/$c.md" ]] && rm -f "$CMDS_DIR/$c.md" && ok "Removed /$c command"
    done
    echo ""
    ok "Uninstall complete."
    exit 0
fi

# ---------- preflight ----------
info "Agentforce Voice Quickstart — Setup"
echo "    mode: $MODE"
echo ""

# Check for sf CLI
if command -v sf &>/dev/null; then
    ok "SF CLI found: $(sf --version 2>/dev/null | head -1)"
else
    warn "SF CLI not found. Install with: brew install sf"
fi

# Check for Claude Code
if command -v claude &>/dev/null; then
    ok "Claude Code found"
else
    warn "Claude Code not found. Install from: https://claude.ai/code"
fi

mkdir -p "$SKILLS_DIR" "$CMDS_DIR"

# ---------- Step 1: ADLC skills (always) ----------
info "Installing Agentforce ADLC skills..."
if [[ -f "$SKILLS_DIR/developing-agentforce/SKILL.md" ]]; then
    ok "ADLC skills already installed"
else
    if curl -sSL https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh | bash; then
        ok "ADLC skills installed"
    else
        warn "ADLC install failed — you can install manually later"
    fi
fi

# ---------- Step 2: AFCC skills (full mode only) ----------
if [[ "$MODE" == "full" ]]; then
    info "Installing AFCC Headless Skills (requires GHE access)..."

    REPO_DIR="/tmp/afcc-voice-quickstart-skills"
    if [[ -d "$REPO_DIR" ]]; then
        rm -rf "$REPO_DIR"
    fi

    if git clone --depth 1 --filter=blob:none --sparse \
        https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm.git \
        "$REPO_DIR" 2>/dev/null; then

        cd "$REPO_DIR"
        git sparse-checkout set workgroups/afcc_afv_headless_demo 2>/dev/null
        BASE="$REPO_DIR/workgroups/afcc_afv_headless_demo"
        HS="$BASE/Headless Skills"
        E2E="$BASE/Additional Info/Agentforce Contact Center End to End demo skill"

        # End-to-End orchestrator (install.sh)
        if [[ -f "$E2E/install.sh" ]]; then
            cd "$E2E" && bash ./install.sh 2>/dev/null
            cd "$REPO_DIR"
            ok "afcc-demo-prep + /afcc-spar + /afcc-quickstart + /afcc-build"
        fi

        # Consolidated skill
        mkdir -p "$SKILLS_DIR/afcc-headless-configurator"
        cp "$BASE/Consolidated_skill.md" "$SKILLS_DIR/afcc-headless-configurator/SKILL.md"
        ok "afcc-headless-configurator"

        # Channel Configuration
        declare -A CHANNEL_SKILLS=(
            ["voice-channel-omni-queue"]="Channel Configuration/Voice channel with omni queue/skill/SKILL.md"
            ["enhanced-chat"]="Channel Configuration/enhanced-chat/SKILL.md"
            ["enhanced-chat-v2"]="Channel Configuration/enhanced-chat-v2/SKILL.md"
            ["sms-channel"]="Channel Configuration/sms/SKILL.md"
            ["whatsapp-channel"]="Channel Configuration/whatsapp/SKILL.md"
            ["line-channel"]="Channel Configuration/Line/SKILL.md"
            ["apple-messages-channel"]="Channel Configuration/apple-messages-for-business/SKILL.md"
            ["facebook-messenger-channel"]="Channel Configuration/FacebookMessenger/SKILL.md"
            ["voice-reports"]="Channel Configuration/OOTB Voice Reports/SKILL.md"
        )
        for name in "${!CHANNEL_SKILLS[@]}"; do
            mkdir -p "$SKILLS_DIR/$name"
            cp "$HS/${CHANNEL_SKILLS[$name]}" "$SKILLS_DIR/$name/SKILL.md" 2>/dev/null && ok "$name"
        done

        # Agent Configuration
        mkdir -p "$SKILLS_DIR/agentforce-agent-creation"
        cp "$HS/Agent Configuration/Agentforce Agent Creation/Skill.md" "$SKILLS_DIR/agentforce-agent-creation/SKILL.md"
        ok "agentforce-agent-creation"

        # Agent on Channel
        mkdir -p "$SKILLS_DIR/agent-on-native-voice"
        cp "$HS/Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md" "$SKILLS_DIR/agent-on-native-voice/SKILL.md"
        ok "agent-on-native-voice"

        mkdir -p "$SKILLS_DIR/agent-on-enhanced-chat"
        cp "$HS/Agent on Channel Configuration/Agent on EC/SKILL.md" "$SKILLS_DIR/agent-on-enhanced-chat/SKILL.md"
        cp -R "$HS/Agent on Channel Configuration/Agent on EC/artifacts" "$SKILLS_DIR/agent-on-enhanced-chat/" 2>/dev/null
        ok "agent-on-enhanced-chat"

        mkdir -p "$SKILLS_DIR/agent-on-enhanced-chat-v2"
        cp "$HS/Agent on Channel Configuration/Agent on EC V2/SKILL.md" "$SKILLS_DIR/agent-on-enhanced-chat-v2/SKILL.md"
        ok "agent-on-enhanced-chat-v2"

        mkdir -p "$SKILLS_DIR/agent-on-3p-channels"
        cp "$HS/Agent on Channel Configuration/Agent on Native 3P Channels/SKILL.md" "$SKILLS_DIR/agent-on-3p-channels/SKILL.md"
        ok "agent-on-3p-channels"

        # Omni Configuration
        mkdir -p "$SKILLS_DIR/omni-routing-supervisor"
        cp "$HS/Omni Configuration/Omni Routing Rep Supervisor Setup/SKILL.md" "$SKILLS_DIR/omni-routing-supervisor/SKILL.md"
        cp -R "$HS/Omni Configuration/Omni Routing Rep Supervisor Setup/artifacts" "$SKILLS_DIR/omni-routing-supervisor/" 2>/dev/null
        ok "omni-routing-supervisor"

        # Service AI Features
        declare -A AI_SKILLS=(
            ["service-ai-grounding"]="Service AI Feature Configuration/service-ai-grounding/SKILL.md"
            ["agentforce-service-assistant"]="Service AI Feature Configuration/agentforce-service-assistant/SKILL.md"
            ["einstein-article-recommendations"]="Service AI Feature Configuration/einstein-article-recommendations/SKILL.md"
            ["einstein-service-replies"]="Service AI Feature Configuration/einstein-service-replies/SKILL.md"
            ["einstein-conversation-insights"]="Service AI Feature Configuration/einstein-conversation-insights/SKILL.md"
            ["conversation-mining"]="Service AI Feature Configuration/conversation-mining/SKILL.md"
            ["voice-messaging-nba"]="Service AI Feature Configuration/voice-messaging-nba/SKILL.md"
            ["knowledge-creation"]="Service AI Feature Configuration/KnowledgeCreation/SKILL.md"
            ["real-time-translations"]="Service AI Feature Configuration/RealTimeTranslations/skill/SKILL.md"
            ["work-summaries"]="Service AI Feature Configuration/WorkSummary/SKILL.md"
        )
        for name in "${!AI_SKILLS[@]}"; do
            mkdir -p "$SKILLS_DIR/$name"
            cp "$HS/${AI_SKILLS[$name]}" "$SKILLS_DIR/$name/SKILL.md" 2>/dev/null && ok "$name"
        done

        # Misc
        mkdir -p "$SKILLS_DIR/afv-pstn-forward"
        cp "$HS/AFV Setup with PSTN forward/SKILL.md" "$SKILLS_DIR/afv-pstn-forward/SKILL.md" 2>/dev/null
        cp -R "$HS/AFV Setup with PSTN forward/artifacts" "$SKILLS_DIR/afv-pstn-forward/" 2>/dev/null
        ok "afv-pstn-forward"

        mkdir -p "$SKILLS_DIR/transcription-recording"
        cp "$HS/Enable transcription and recording/SKILL.md" "$SKILLS_DIR/transcription-recording/SKILL.md" 2>/dev/null
        ok "transcription-recording"

        # Cleanup
        rm -rf "$REPO_DIR"

    else
        err "Could not clone from git.soma.salesforce.com"
        err "Make sure you're on VPN and have GHE access."
        err "You can still use ADLC skills — run with --minimal to skip this step."
        exit 1
    fi
fi

# ---------- done ----------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "${BOLD}Setup complete!${NC}"
echo ""
echo "  ${BOLD}Next steps:${NC}"
echo ""
echo "  1. ${BOLD}Restart Claude Code${NC} (skills are cached at session start)"
echo ""
echo "  2. Authenticate your Salesforce org:"
echo "     ${BLUE}sf org login web --alias my-org --set-default${NC}"
echo ""
echo "  3. Open Claude Code and paste:"
echo "     ${BLUE}Read https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/PROMPT.md and follow it.${NC}"
echo ""
echo "     Or open PROMPT.md from this repo and paste it directly."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
