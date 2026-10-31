set -a
source ./.env.production
set +a
kamal deploy -d staging
