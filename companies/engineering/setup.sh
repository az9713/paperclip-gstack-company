#!/usr/bin/env bash
# setup.sh — Provision the gstack Engineering Company in Paperclip
#
# Usage:
#   ./setup.sh
#   PAPERCLIP_URL=http://localhost:4040 ./setup.sh
#
# Requirements:
#   - Paperclip server must be running
#   - jq must be installed
#   - Run from the companies/engineering/ directory (or set SCRIPT_DIR)

set -euo pipefail

PAPERCLIP_URL="${PAPERCLIP_URL:-http://localhost:4040}"
API="${PAPERCLIP_URL}/api"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSTACK_DIR="$(cd "${SCRIPT_DIR}/../../gstack" && pwd)"
BRIDGE_SKILL_DIR="${SCRIPT_DIR}/skills/gstack-bridge"

echo "==> gstack Engineering Company Setup"
echo "    Paperclip: ${PAPERCLIP_URL}"
echo "    gstack:    ${GSTACK_DIR}"
echo ""

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

api_post() {
  local path="$1"
  local body="$2"
  curl -sf -X POST "${API}${path}" \
    -H "Content-Type: application/json" \
    -d "${body}"
}

api_get() {
  local path="$1"
  curl -sf "${API}${path}"
}

import_skill() {
  local company_id="$1"
  local source_path="$2"
  echo "    Importing skill from: ${source_path}"
  api_post "/companies/${company_id}/skills/import" \
    "{\"source\": \"${source_path}\"}" | jq -r '.imported[].slug // empty' | sed 's/^/      + /'
}

# ─────────────────────────────────────────────
# Step 1: Create company
# ─────────────────────────────────────────────

echo "--> Step 1: Create company"

COMPANY=$(api_post "/companies" '{
  "name": "Engineering Co",
  "issuePrefix": "ENG"
}')

COMPANY_ID=$(echo "${COMPANY}" | jq -r '.id')
echo "    Company ID: ${COMPANY_ID}"

# ─────────────────────────────────────────────
# Step 2: Import gstack skills
# ─────────────────────────────────────────────

echo ""
echo "--> Step 2: Import gstack skills"

GSTACK_SKILLS=(
  autoplan
  plan-ceo-review
  office-hours
  plan-eng-review
  review
  ship
  investigate
  codex
  land-and-deploy
  canary
  document-release
  setup-deploy
  devex-review
  plan-devex-review
  retro
  benchmark
  qa-only
  qa
  cso
  careful
  guard
  design-review
  design-html
  design-consultation
  design-shotgun
  plan-design-review
)

for skill in "${GSTACK_SKILLS[@]}"; do
  skill_path="${GSTACK_DIR}/${skill}"
  if [ -d "${skill_path}" ]; then
    import_skill "${COMPANY_ID}" "${skill_path}"
  else
    echo "    WARNING: gstack skill not found: ${skill_path}"
  fi
done

# Import the Paperclip skill (built into Paperclip server, but import explicitly)
PAPERCLIP_SKILL_DIR="$(cd "${SCRIPT_DIR}/../../paperclip/skills/paperclip" 2>/dev/null && pwd)" || true
if [ -n "${PAPERCLIP_SKILL_DIR}" ] && [ -d "${PAPERCLIP_SKILL_DIR}" ]; then
  import_skill "${COMPANY_ID}" "${PAPERCLIP_SKILL_DIR}"
fi

# ─────────────────────────────────────────────
# Step 3: Import bridge skill
# ─────────────────────────────────────────────

echo ""
echo "--> Step 3: Import gstack-bridge skill"
import_skill "${COMPANY_ID}" "${BRIDGE_SKILL_DIR}"

# ─────────────────────────────────────────────
# Step 4: Create agents
# ─────────────────────────────────────────────

echo ""
echo "--> Step 4: Create agents"

create_agent() {
  local name="$1"
  local role="$2"
  local title="$3"
  local reports_to_id="$4"   # UUID or empty string
  local capabilities="$5"
  local model="$6"
  local max_turns="$7"
  local timeout_sec="$8"
  local heartbeat_schedule="$9"
  shift 9
  local desired_skills=("$@")

  # Build reportsTo field
  local reports_to_json="null"
  if [ -n "${reports_to_id}" ]; then
    reports_to_json="\"${reports_to_id}\""
  fi

  # Build desiredSkills JSON array
  local skills_json
  skills_json=$(printf '"%s",' "${desired_skills[@]}")
  skills_json="[${skills_json%,}]"

  # Build onboarding dir path
  local onboarding_key
  onboarding_key=$(echo "${name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
  local onboarding_dir="${SCRIPT_DIR}/onboarding/${onboarding_key}"

  local body
  body=$(cat <<EOF
{
  "name": "${name}",
  "role": "${role}",
  "title": "${title}",
  "reportsTo": ${reports_to_json},
  "capabilities": "${capabilities}",
  "adapterType": "claude_local",
  "adapterConfig": {
    "model": "${model}",
    "maxTurnsPerRun": ${max_turns},
    "timeoutSec": ${timeout_sec},
    "dangerouslySkipPermissions": true,
    "onboardingDir": "${onboarding_dir}",
    "heartbeat": {
      "schedule": "${heartbeat_schedule}"
    },
    "paperclipSkillSync": {
      "desiredSkills": ${skills_json}
    }
  }
}
EOF
)

  local result
  result=$(api_post "/companies/${COMPANY_ID}/agents" "${body}")
  local agent_id
  agent_id=$(echo "${result}" | jq -r '.id')
  echo "    Created ${name} (${agent_id})"
  echo "${agent_id}"
}

# CEO (no reportsTo)
CEO_ID=$(create_agent \
  "CEO" "ceo" "Chief Executive Officer" "" \
  "Strategic planning, task delegation, cross-functional coordination, plan review at CEO level" \
  "claude-opus-4-6" 80 900 "*/15 * * * *" \
  paperclip gstack-bridge gstack-autoplan gstack-plan-ceo-review gstack-office-hours)

# CTO (reports to CEO)
CTO_ID=$(create_agent \
  "CTO" "manager" "Chief Technology Officer" "${CEO_ID}" \
  "Engineering management, code review, release management, technical planning" \
  "claude-sonnet-4-6" 150 1800 "*/20 * * * *" \
  paperclip gstack-bridge gstack-plan-eng-review gstack-review gstack-ship)

# QA Lead (reports to CEO)
QA_LEAD_ID=$(create_agent \
  "QALead" "manager" "QA Lead" "${CEO_ID}" \
  "Report-only QA oversight, bug triage, quality metrics" \
  "claude-sonnet-4-6" 150 1200 "0 */4 * * *" \
  paperclip gstack-bridge gstack-qa-only)

# Security Officer (reports to CEO)
SECURITY_ID=$(create_agent \
  "SecurityOfficer" "ic" "Chief Security Officer" "${CEO_ID}" \
  "OWASP Top 10, STRIDE threat modeling, security audits, safety controls" \
  "claude-sonnet-4-6" 150 1200 "0 */6 * * *" \
  paperclip gstack-bridge gstack-cso gstack-careful gstack-guard)

# Design Lead (reports to CEO)
DESIGN_ID=$(create_agent \
  "DesignLead" "ic" "Design Lead" "${CEO_ID}" \
  "UI/UX review, design systems, design-to-HTML, visual exploration, plan design review" \
  "claude-sonnet-4-6" 150 1200 "*/30 * * * *" \
  paperclip gstack-bridge gstack-design-review gstack-design-html gstack-design-consultation gstack-design-shotgun gstack-plan-design-review)

# Senior Engineer (reports to CTO)
SENIOR_ENG_ID=$(create_agent \
  "SeniorEngineer" "ic" "Senior Software Engineer" "${CTO_ID}" \
  "Feature implementation, bug fixing, root-cause debugging, multi-AI second opinion" \
  "claude-sonnet-4-6" 200 1800 "*/30 * * * *" \
  paperclip gstack-bridge gstack-investigate gstack-codex)

# Release Engineer (reports to CTO)
RELEASE_ENG_ID=$(create_agent \
  "ReleaseEngineer" "ic" "Release Engineer" "${CTO_ID}" \
  "Merge, deploy, canary monitoring, release documentation, deploy setup" \
  "claude-sonnet-4-6" 200 1800 "*/30 * * * *" \
  paperclip gstack-bridge gstack-land-and-deploy gstack-canary gstack-document-release gstack-setup-deploy)

# DevEx Engineer (reports to CTO)
DEVEX_ID=$(create_agent \
  "DevExEngineer" "ic" "Developer Experience Engineer" "${CTO_ID}" \
  "DX reviews, plan DX review, retrospectives, performance benchmarking" \
  "claude-sonnet-4-6" 150 1200 "0 * * * *" \
  paperclip gstack-bridge gstack-devex-review gstack-plan-devex-review gstack-retro gstack-benchmark)

# QA Engineer (reports to QA Lead)
QA_ENG_ID=$(create_agent \
  "QAEngineer" "ic" "QA Engineer" "${QA_LEAD_ID}" \
  "Full QA loop: find bugs, write tests, fix, verify. Atomic commits per fix." \
  "claude-sonnet-4-6" 200 1800 "*/30 * * * *" \
  paperclip gstack-bridge gstack-qa)

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────

echo ""
echo "==> Engineering Company provisioned!"
echo ""
echo "    Company ID: ${COMPANY_ID}"
echo "    Agents:"
echo "      CEO:             ${CEO_ID}"
echo "      CTO:             ${CTO_ID}"
echo "      SeniorEngineer:  ${SENIOR_ENG_ID}"
echo "      ReleaseEngineer: ${RELEASE_ENG_ID}"
echo "      DevExEngineer:   ${DEVEX_ID}"
echo "      QALead:          ${QA_LEAD_ID}"
echo "      QAEngineer:      ${QA_ENG_ID}"
echo "      SecurityOfficer: ${SECURITY_ID}"
echo "      DesignLead:      ${DESIGN_ID}"
echo ""
echo "    Open Paperclip at: ${PAPERCLIP_URL}"
echo "    Create an issue to start the team working:"
echo "      POST ${API}/companies/${COMPANY_ID}/issues"
echo '      {"title": "Your task here", "assigneeAgentId": "'${CEO_ID}'"}'
