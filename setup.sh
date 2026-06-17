#!/usr/bin/env bash
# ==========================================================================
# Agentforce Voice Quickstart — Setup Script
#
# Installs Claude Code skills for building Agentforce Contact Center agents.
#
# Usage:
#   ./setup.sh                          # Install all skills (full suite)
#   ./setup.sh --minimal                # ADLC skills only (no GHE needed)
#   ./setup.sh --bundle voice-agent     # Install a pre-defined bundle
#   ./setup.sh --install <skill-name>   # Install specific skill(s)
#   ./setup.sh --list                   # Show all available skills
#   ./setup.sh --uninstall              # Remove skills installed by this script
# ==========================================================================
set -euo pipefail

# ---------- colors ----------
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'
    RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    GREEN=''; YELLOW=''; BLUE=''; RED=''; BOLD=''; DIM=''; NC=''
fi
info()  { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()    { printf "${GREEN} ✓${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW} !${NC}  %s\n" "$*"; }
err()   { printf "${RED} ✗${NC}  %s\n" "$*" >&2; }

# ---------- skill registry ----------
# Format: SKILL_NAME|SOURCE_PATH|DESCRIPTION|HAS_ARTIFACTS
SKILL_REGISTRY=(
    "voice-channel-omni-queue|Channel Configuration/Voice channel with omni queue/skill/SKILL.md|Voice channel routed to queue (no agent)|no"
    "enhanced-chat|Channel Configuration/enhanced-chat/SKILL.md|Enhanced Digital Engagement (Chat v1)|no"
    "enhanced-chat-v2|Channel Configuration/enhanced-chat-v2/SKILL.md|Enhanced Chat v2 (persistent, rich media)|no"
    "sms-channel|Channel Configuration/sms/SKILL.md|SMS messaging channel|no"
    "whatsapp-channel|Channel Configuration/whatsapp/SKILL.md|WhatsApp Business channel|no"
    "line-channel|Channel Configuration/Line/SKILL.md|LINE messaging channel|no"
    "apple-messages-channel|Channel Configuration/apple-messages-for-business/SKILL.md|Apple Messages for Business|no"
    "facebook-messenger-channel|Channel Configuration/FacebookMessenger/SKILL.md|Facebook Messenger (Enhanced)|artifacts"
    "voice-reports|Channel Configuration/OOTB Voice Reports/SKILL.md|Voice Reports (Rep/IVR Metrics)|no"
    "agentforce-agent-creation|Agent Configuration/Agentforce Agent Creation/Skill.md|Create Agentforce Service Agent via CLI|no"
    "agent-on-native-voice|Agent on Channel Configuration/Agent on Native Voice/skill/SKILL.md|Wire agent to PSTN voice channel|no"
    "agent-on-enhanced-chat|Agent on Channel Configuration/Agent on EC/SKILL.md|Connect agent to Enhanced Chat v1|artifacts"
    "agent-on-enhanced-chat-v2|Agent on Channel Configuration/Agent on EC V2/SKILL.md|Connect agent to Enhanced Chat v2|no"
    "agent-on-3p-channels|Agent on Channel Configuration/Agent on Native 3P Channels/SKILL.md|Wire agent to SMS/WhatsApp/LINE/Apple/FB|no"
    "omni-routing-supervisor|Omni Configuration/Omni Routing Rep Supervisor Setup/SKILL.md|Full Omni-Channel routing + supervisor|artifacts"
    "service-ai-grounding|Service AI Feature Configuration/service-ai-grounding/SKILL.md|Einstein Generative AI grounding|no"
    "agentforce-service-assistant|Service AI Feature Configuration/agentforce-service-assistant/SKILL.md|Agentforce Service Assistant|no"
    "einstein-article-recommendations|Service AI Feature Configuration/einstein-article-recommendations/SKILL.md|Einstein Article Recommendations|no"
    "einstein-service-replies|Service AI Feature Configuration/einstein-service-replies/SKILL.md|Einstein Service Replies|no"
    "einstein-conversation-insights|Service AI Feature Configuration/einstein-conversation-insights/SKILL.md|Einstein Conversation Insights|no"
    "conversation-mining|Service AI Feature Configuration/conversation-mining/SKILL.md|Conversation Mining (topic detection)|no"
    "voice-messaging-nba|Service AI Feature Configuration/voice-messaging-nba/SKILL.md|Voice & Messaging Next Best Action|no"
    "knowledge-creation|Service AI Feature Configuration/KnowledgeCreation/SKILL.md|Einstein Knowledge Creation|no"
    "real-time-translations|Service AI Feature Configuration/RealTimeTranslations/skill/SKILL.md|Real-Time Translations|no"
    "work-summaries|Service AI Feature Configuration/WorkSummary/SKILL.md|Work Summaries & Conversation Catch-Up|no"
    "afv-pstn-forward|AFV Setup with PSTN forward/SKILL.md|AFV with PSTN call forwarding|artifacts"
    "amazon-connect-setup|LOCAL:skills/amazon-connect-setup/SKILL.md|Amazon Connect setup for AFV (Path B2)|no"
    "transcription-recording|Enable transcription and recording/SKILL.md|Voice transcription + recording|no"
)

# ---------- bundle definitions ----------
# Path A: ECV2 Voice Widget (no phone needed)
BUNDLE_VOICE_ECV2="agentforce-agent-creation agent-on-enhanced-chat-v2 omni-routing-supervisor enhanced-chat-v2"
# Path B: PSTN Phone Call
BUNDLE_VOICE_AGENT="agentforce-agent-creation agent-on-native-voice afv-pstn-forward omni-routing-supervisor voice-channel-omni-queue transcription-recording"
# Path C: Both (includes Amazon Connect skill for B2 option)
BUNDLE_VOICE_ALL="agentforce-agent-creation agent-on-native-voice afv-pstn-forward amazon-connect-setup agent-on-enhanced-chat-v2 omni-routing-supervisor voice-channel-omni-queue transcription-recording enhanced-chat-v2"
BUNDLE_DIGITAL="enhanced-chat enhanced-chat-v2 sms-channel whatsapp-channel line-channel apple-messages-channel facebook-messenger-channel agent-on-3p-channels agent-on-enhanced-chat agent-on-enhanced-chat-v2"
BUNDLE_SERVICE_AI="service-ai-grounding agentforce-service-assistant einstein-article-recommendations einstein-service-replies einstein-conversation-insights conversation-mining voice-messaging-nba knowledge-creation real-time-translations work-summaries"
BUNDLE_FULL="$BUNDLE_VOICE_ALL $BUNDLE_DIGITAL $BUNDLE_SERVICE_AI voice-reports"

# ---------- args ----------
MODE="full"
INSTALL_TARGETS=()
BUNDLE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)   MODE="minimal"; shift ;;
        --full)      MODE="full"; shift ;;
        --uninstall) MODE="uninstall"; shift ;;
        --list)      MODE="list"; shift ;;
        --install)
            MODE="selective"
            shift
            [[ $# -gt 0 ]] || { err "--install requires a skill name"; exit 2; }
            INSTALL_TARGETS+=("$1"); shift ;;
        --bundle)
            MODE="bundle"
            shift
            [[ $# -gt 0 ]] || { err "--bundle requires a name (voice-ecv2|voice-agent|voice-all|digital-channels|service-ai|full)"; exit 2; }
            BUNDLE_NAME="$1"; shift ;;
        -h|--help)
            echo "Usage: ./setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no flags)                Install all skills (requires GHE)"
            echo "  --minimal                 ADLC skills only (no GHE needed)"
            echo "  --bundle <name>           Install a bundle:"
            echo "                              voice-ecv2       — Path A: ECV2 voice widget (no phone)"
            echo "                              voice-agent      — Path B: PSTN phone call"
            echo "                              voice-all        — Path C: Both paths"
            echo "                              digital-channels — All messaging channels"
            echo "                              service-ai       — All Service AI features"
            echo "                              full             — Everything"
            echo "  --install <skill-name>    Install one skill (repeatable)"
            echo "  --list                    List all available skills"
            echo "  --uninstall               Remove all skills installed by this script"
            echo "  -h, --help                Show this help"
            echo ""
            echo "Examples:"
            echo "  ./setup.sh --bundle voice-agent"
            echo "  ./setup.sh --install agent-on-native-voice --install omni-routing-supervisor"
            echo "  ./setup.sh --list"
            exit 0 ;;
        *) err "Unknown flag: $1. Use --help for usage."; exit 2 ;;
    esac
done

SKILLS_DIR="$HOME/.claude/skills"
CMDS_DIR="$HOME/.claude/commands"

# ---------- list mode ----------
if [[ "$MODE" == "list" ]]; then
    echo ""
    printf "${BOLD}%-30s %s${NC}\n" "SKILL" "DESCRIPTION"
    printf "%-30s %s\n" "-----" "-----------"
    for entry in "${SKILL_REGISTRY[@]}"; do
        IFS='|' read -r name path desc has_artifacts <<< "$entry"
        installed=""
        [[ -f "$SKILLS_DIR/$name/SKILL.md" ]] && installed="${GREEN}[installed]${NC} "
        printf "  ${BLUE}%-28s${NC} ${installed}%s\n" "$name" "$desc"
    done
    echo ""
    echo "${BOLD}Bundles:${NC}"
    echo "  ${BLUE}voice-ecv2${NC}         — Path A: ECV2 voice widget (no phone number needed)"
    echo "  ${BLUE}voice-agent${NC}        — Path B: PSTN phone call"
    echo "  ${BLUE}voice-all${NC}          — Path C: Both paths (recommended)"
    echo "  ${BLUE}digital-channels${NC}   — All messaging channels + agent wiring"
    echo "  ${BLUE}service-ai${NC}         — All Service AI features"
    echo "  ${BLUE}full${NC}               — Everything"
    echo ""
    echo "Install with: ./setup.sh --bundle <name>"
    echo "         or:  ./setup.sh --install <skill-name>"
    exit 0
fi

# ---------- uninstall ----------
if [[ "$MODE" == "uninstall" ]]; then
    info "Removing Agentforce Voice Quickstart skills..."
    for entry in "${SKILL_REGISTRY[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        if [[ -d "$SKILLS_DIR/$name" ]]; then
            rm -rf "$SKILLS_DIR/$name"
            ok "Removed $name"
        fi
    done
    # Also remove orchestrator pieces
    for s in afcc-demo-prep license-audit afcc-headless-configurator; do
        [[ -d "$SKILLS_DIR/$s" ]] && rm -rf "$SKILLS_DIR/$s" && ok "Removed $s"
    done
    for c in afcc-spar afcc-quickstart afcc-build; do
        [[ -e "$CMDS_DIR/$c.md" ]] && rm -f "$CMDS_DIR/$c.md" && ok "Removed /$c command"
    done
    echo ""
    ok "Uninstall complete."
    exit 0
fi

# ---------- resolve bundle to install targets ----------
if [[ "$MODE" == "bundle" ]]; then
    case "$BUNDLE_NAME" in
        voice-ecv2)        INSTALL_TARGETS=($BUNDLE_VOICE_ECV2) ;;
        voice-agent)       INSTALL_TARGETS=($BUNDLE_VOICE_AGENT) ;;
        voice-all)         INSTALL_TARGETS=($BUNDLE_VOICE_ALL) ;;
        digital-channels)  INSTALL_TARGETS=($BUNDLE_DIGITAL) ;;
        service-ai)        INSTALL_TARGETS=($BUNDLE_SERVICE_AI) ;;
        full)              INSTALL_TARGETS=($BUNDLE_FULL); MODE="full" ;;
        *)  err "Unknown bundle: $BUNDLE_NAME"
            err "Available: voice-ecv2, voice-agent, voice-all, digital-channels, service-ai, full"
            exit 2 ;;
    esac
    MODE="selective"
fi

# ---------- helper: install a single skill from the cloned repo ----------
install_skill() {
    local name="$1"
    local hs_dir="$2"

    for entry in "${SKILL_REGISTRY[@]}"; do
        IFS='|' read -r reg_name reg_path _ reg_artifacts <<< "$entry"
        if [[ "$reg_name" == "$name" ]]; then
            mkdir -p "$SKILLS_DIR/$name"
            # Handle LOCAL: prefix (skills bundled in this repo)
            if [[ "$reg_path" == LOCAL:* ]]; then
                local local_path="${reg_path#LOCAL:}"
                local script_dir
                script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                if cp "$script_dir/$local_path" "$SKILLS_DIR/$name/SKILL.md" 2>/dev/null; then
                    ok "$name (bundled)"
                else
                    err "Failed to install $name (not found at $script_dir/$local_path)"
                fi
            elif cp "$hs_dir/$reg_path" "$SKILLS_DIR/$name/SKILL.md" 2>/dev/null; then
                # Copy artifacts if the skill has them
                if [[ "$reg_artifacts" == "artifacts" ]]; then
                    local src_dir
                    src_dir="$(dirname "$hs_dir/$reg_path")"
                    [[ -d "$src_dir/artifacts" ]] && cp -R "$src_dir/artifacts" "$SKILLS_DIR/$name/" 2>/dev/null
                    # For omni, artifacts are at a different level
                    local parent_dir
                    parent_dir="$(dirname "$src_dir")"
                    [[ -d "$parent_dir/artifacts" ]] && cp -R "$parent_dir/artifacts" "$SKILLS_DIR/$name/" 2>/dev/null
                fi
                ok "$name"
            else
                err "Failed to install $name (source not found at $hs_dir/$reg_path)"
            fi
            return 0
        fi
    done
    err "Unknown skill: $name (use --list to see available skills)"
    return 1
}

# ---------- preflight ----------
info "Agentforce Voice Quickstart — Setup"
if [[ "$MODE" == "selective" ]]; then
    echo "    installing: ${INSTALL_TARGETS[*]}"
else
    echo "    mode: $MODE"
fi
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
info "Checking Agentforce ADLC skills..."
if [[ -f "$SKILLS_DIR/developing-agentforce/SKILL.md" ]]; then
    ok "ADLC skills already installed"
else
    info "Installing ADLC skills..."
    if curl -sSL https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh | bash; then
        ok "ADLC skills installed"
    else
        warn "ADLC install failed — you can install manually later"
    fi
fi

# ---------- Step 2: AFCC skills ----------
if [[ "$MODE" == "minimal" ]]; then
    # Skip AFCC skills in minimal mode
    :
elif [[ "$MODE" == "selective" || "$MODE" == "full" ]]; then
    info "Cloning AFCC skills source (requires GHE access)..."

    REPO_DIR="/tmp/afcc-voice-quickstart-skills"
    [[ -d "$REPO_DIR" ]] && rm -rf "$REPO_DIR"

    if git clone --depth 1 --filter=blob:none --sparse \
        https://git.soma.salesforce.com/gvasudev/agentforce_contact_center_pm.git \
        "$REPO_DIR" 2>/dev/null; then

        cd "$REPO_DIR"
        git sparse-checkout set workgroups/afcc_afv_headless_demo 2>/dev/null
        BASE="$REPO_DIR/workgroups/afcc_afv_headless_demo"
        HS="$BASE/Headless Skills"
        E2E="$BASE/Additional Info/Agentforce Contact Center End to End demo skill"

        if [[ "$MODE" == "full" ]]; then
            # Full mode: install orchestrator + all skills
            echo ""
            info "Installing orchestrator (afcc-demo-prep)..."
            if [[ -f "$E2E/install.sh" ]]; then
                cd "$E2E" && bash ./install.sh 2>/dev/null
                cd "$REPO_DIR"
                ok "afcc-demo-prep + /afcc-spar + /afcc-quickstart + /afcc-build"
            fi

            mkdir -p "$SKILLS_DIR/afcc-headless-configurator"
            cp "$BASE/Consolidated_skill.md" "$SKILLS_DIR/afcc-headless-configurator/SKILL.md"
            ok "afcc-headless-configurator"

            echo ""
            info "Installing all individual skills..."
            for entry in "${SKILL_REGISTRY[@]}"; do
                IFS='|' read -r name _ _ _ <<< "$entry"
                install_skill "$name" "$HS"
            done
        else
            # Selective mode: install only requested skills
            echo ""
            info "Installing selected skills..."
            for target in "${INSTALL_TARGETS[@]}"; do
                install_skill "$target" "$HS"
            done
        fi

        # Cleanup
        rm -rf "$REPO_DIR"

    else
        err "Could not clone from git.soma.salesforce.com"
        err "Make sure you're on VPN and have GHE access."
        err ""
        err "Alternatives:"
        err "  1. Connect VPN and retry"
        err "  2. Run with --minimal (ADLC skills only, no GHE needed)"
        err "  3. Ask a teammate to share the skill files manually"
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
echo "  2. Authenticate your Salesforce org (pick one):"
echo "     ${BLUE}sf org login web --set-default${NC}                    # Own org (opens browser)"
echo "     ${DIM}# OR for Agentforce Labs:${NC}"
echo "     ${BLUE}SF_ACCESS_TOKEN='<token>' sf org login access-token \\${NC}"
echo "     ${BLUE}  --instance-url <url> --set-default --no-prompt${NC}"
echo "     ${DIM}(Get token from: Agentforce Labs → Org dropdown → Org Details → SF CLI Authentication)${NC}"
echo ""
echo "  3. Open Claude Code and run:"
echo "     ${BLUE}curl -sL https://raw.githubusercontent.com/skyrmionz/agentforce-voice-quickstart/main/PROMPT.md${NC}"
echo "     Then tell Claude: \"Follow this prompt step by step.\""
echo ""
echo "  See SKILLS.md for the full skill catalog and bundle options."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
