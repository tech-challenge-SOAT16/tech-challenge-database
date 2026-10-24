# AWS lab demo

Use the three temporary session secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN. AWS_REGION is us-east-1 for this deployment. Never commit credentials. Enable AWS_DEPLOY_ENABLED only when prerequisites exist.

Changes in this integration: Lambda can use an existing execution role and explicitly opted-in private lab SMTP; K8s provides an internal SMTP NLB (inbox remains private); Database runs on develop/main with one serialized state; Application publishes an immutable ECR image and publishes a deployment branch for a reviewed overlay PR. Main remains review-protected. Both application overlays are read from main by Argo CD.

The application workflow pushes a deployment branch and prints a compare URL. An authenticated team member opens the PR; normal pull_request checks then run and another reviewer approves it. No workflow approval permissions are enabled. After merge, Argo CD applies the versioned image; do not use kubectl apply for this release.

Deploy order: K8s, Database initial bootstrap, Application/migrations, auth_clients Job completion, Lambda, then Application issuer/authority configuration. Obtain the internal mailpit-smtp LoadBalancer hostname in the matching namespace for Lambda SMTP_HOST; do not use cluster-local DNS from Lambda. SMTP is only for the disposable private lab. Keep SES as the normal cloud default.

The session expires at the time supplied by the lab owner. Confirm run outcomes and live requests before recording. No AWS console is needed: use GitHub Actions, kubectl, HTTP requests and Grafana for dashboards/logs/traces.
