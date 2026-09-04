# SaninLegacy

Rails 8 application for Magic: The Gathering card trade management (MVP).

## Setup

### Prerequisites
- Docker & Docker Compose
- Ruby 3.3.12 (for local development)
- PostgreSQL 17

### Development Setup

#### Initial Setup

On the first setup, build the Docker image with the development stage and start all services:

```bash
docker compose up --build
```

This command will:
- Build the Docker image including the development stage (with all gems including development and test dependencies)
- Start the PostgreSQL database service
- Run database preparation (`db:prepare`)
- Start the Rails application server on http://localhost:3000

#### Subsequent Startups

For subsequent startups (when the Docker image is already built), simply use:

```bash
docker compose up
```

#### Stopping Services

To stop all services:

```bash
docker compose down
```

#### Common Development Tasks

View application logs:

```bash
docker compose logs -f app
```

Access the Rails console:

```bash
docker compose exec app bundle exec rails console
```

Run database migrations:

```bash
docker compose exec app bundle exec rails db:migrate
```

Seed the database:

```bash
docker compose exec app bundle exec rails db:seed
```

Run tests:

```bash
docker compose exec app bundle exec rspec
```

Run code quality checks:

```bash
docker compose exec app bundle exec rubocop
```

The application will be available at `http://localhost:3000`

### Environment Configuration

Copy `.env.example` to `.env` and update as needed:

```bash
cp .env.example .env
```

## Google Sheets API Configuration

### Phase 7.1: Service Account Authentication

The application uses Google Sheets API for exporting trade data. Service account authentication is configured via Rails credentials (encrypted `config/credentials.yml.enc`).

#### Setting up Google Sheets Service Account Credentials

1. **Obtain GCP Service Account Key**
   - Create a Google Cloud Project and enable Google Sheets API / Google Drive API
   - Create a Service Account and download the JSON key file

2. **Add credentials to Rails credentials**

   ```bash
   bin/rails credentials:edit
   ```

   Add the following structure under `google_sheets:` (replace placeholder values with actual service account JSON content):

   ```yaml
   google_sheets:
     type: "service_account"
     project_id: "your-gcp-project-id"
     private_key_id: "your-private-key-id"
     private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----\n"
     client_email: "your-service-account@your-project.iam.gserviceaccount.com"
     client_id: "1234567890"
     auth_uri: "https://accounts.google.com/o/oauth2/auth"
     token_uri: "https://oauth2.googleapis.com/token"
     auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
     client_x509_cert_url: "https://www.googleapis.com/certificates/..."
   ```

   **Important**: The `private_key` field must preserve line breaks as `\n` (not literal newlines).

3. **In Production (Kamal Deployment)**
   - The `RAILS_MASTER_KEY` is automatically injected via `.kamal/secrets` → `config/deploy.yml`
   - No additional configuration is needed; existing secrets management will handle credentials decryption

### Client Usage

The application provides `GoogleSheetsConfig` module for accessing authenticated API clients:

```ruby
# Sheets API
sheets_client = GoogleSheetsConfig.sheets_client

# Drive API
drive_client = GoogleSheetsConfig.drive_client
```

Both clients are pre-configured with appropriate OAuth scopes for:
- Reading/writing Google Sheets
- Managing Google Drive files

If credentials are not configured, both methods will raise `GoogleSheetsConfig::CredentialsNotConfiguredError`.

## Testing

```bash
docker compose exec app bundle exec rspec
```

## Code Quality

```bash
docker compose exec app bundle exec rubocop
```
