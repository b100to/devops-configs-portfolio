#!/usr/bin/env bash
set -e

# .env 로드
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

echo "▶ Starting n8n..."
docker compose up -d

echo "⏳ Waiting for n8n to be ready..."
until docker exec n8n wget -qO- http://localhost:5678/healthz > /dev/null 2>&1; do
  sleep 2
done
echo "✅ n8n is ready"

echo "▶ Setting up owner account..."
RESPONSE=$(curl -s -X POST http://localhost:5678/rest/owner/setup \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${N8N_OWNER_EMAIL}\",
    \"firstName\": \"${N8N_OWNER_FIRST_NAME}\",
    \"lastName\": \"${N8N_OWNER_LAST_NAME}\",
    \"password\": \"${N8N_OWNER_PASSWORD}\"
  }" 2>&1 || true)

if echo "$RESPONSE" | grep -q '"email"'; then
  echo "✅ Owner account created: ${N8N_OWNER_EMAIL}"
else
  echo "ℹ️  Owner already configured (skipping)"
fi

echo "▶ Submitting personalization survey..."
TOKEN=$(curl -si -X POST http://localhost:5678/rest/login \
  -H "Content-Type: application/json" \
  -d "{\"emailOrLdapLoginId\": \"${N8N_OWNER_EMAIL}\", \"password\": \"${N8N_OWNER_PASSWORD}\"}" \
  | grep "Set-Cookie" | sed 's/.*n8n-auth=\([^;]*\).*/\1/')

SURVEY_RESPONSE=$(curl -s -X POST http://localhost:5678/rest/me/survey \
  -H "Content-Type: application/json" \
  -b "n8n-auth=${TOKEN}" \
  -d "{
    \"version\": \"v4\",
    \"personalization_survey_submitted_at\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
    \"personalization_survey_n8n_version\": \"$(docker exec n8n n8n --version 2>/dev/null)\",
    \"companyType\": \"other\",
    \"companyIndustryExtended\": [\"IT\"],
    \"role\": \"devops\",
    \"usageModes\": [\"myself\"],
    \"reportedSource\": \"other\"
  }" 2>&1 || true)

if echo "$SURVEY_RESPONSE" | grep -q '"success":true'; then
  echo "✅ Personalization survey submitted"
else
  echo "ℹ️  Survey already submitted or skipped"
fi

echo ""
echo "🚀 n8n is running at http://localhost:5678"
echo "   Email: ${N8N_OWNER_EMAIL}"
