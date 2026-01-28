---
created: 2026-01-27T21:45:00Z
github_issue: 526
---

# Multi-Provider OAuth with Account Linking (BFF Pattern)

> **Source:** GitHub issue #526 - Epic: Multi-Provider OAuth with Account Linking (BFF Pattern)
> **Link:** https://github.com/krazyuniks/guitar-tone-shootout/issues/526

## Problem Statement

Guitar Tone Shootout (GTS) currently only supports Tone3000 (T3K) authentication. Users need the ability to authenticate via multiple OAuth providers (Facebook, GitHub, Google, T3K) with equal weighting. Additionally, users who have multiple social accounts with the same email should be able to link them to a single GTS account.

The implementation must follow the BFF (Backend for Frontend) pattern where all OAuth secrets remain on the backend, browsers only receive httponly session cookies, and tokens are stored encrypted in the database.

## Success Criteria

- [ ] Users can login with Facebook, GitHub, Google, or Tone3000
- [ ] All providers displayed alphabetically with equal visual weight
- [ ] Users can link multiple providers to one account
- [ ] Auto-linking works for matching verified emails
- [ ] Users cannot unlink their last provider
- [ ] All OAuth flows use PKCE
- [ ] State parameters are signed and time-limited (10 min expiry)
- [ ] Session IDs regenerated after OAuth success
- [ ] Tokens encrypted at rest (Fernet)
- [ ] Rate limiting active on auth endpoints
- [ ] Existing T3K users migrated without disruption

## Execution Guidelines

**Use background agents for parallel sub-tasks.** When implementing stories, use the Task tool with `run_in_background: true` to maximize throughput:

1. **Background agents for independent work:**
   - `Explore` agent - Codebase research, finding related files/patterns
   - `Bash` agent - Running tests, builds, type checks in background
   - `general-purpose` agent - Complex multi-step research tasks

2. **When to use background agents:**
   - Long-running tests while you continue implementing
   - Searching large codebases for patterns
   - Build/typecheck validation while moving to next file
   - Exploring multiple subsystems in parallel

3. **OAuth-specific guidance:**
   - All providers use the same adapter interface
   - PKCE is mandatory for all providers
   - State parameter must include: nonce, timestamp, user_id (if linking), operation, code_verifier
   - Token encryption uses Fernet with per-provider key rotation capability

## User Stories

---

### Phase 1: Database Migration & Core Infrastructure

---

### STORY-001: Create OAuth Provider Configuration

**As a** developer
**I want to** have a centralised OAuth provider configuration
**So that** all providers can be configured consistently

**Acceptance Criteria:**
- [ ] Create `OAuthProvider` enum with values: facebook, github, google, t3k
- [ ] Add provider configuration to `backend/app/core/config.py`
- [ ] Environment variables for each provider's client_id and client_secret
- [ ] Provider-specific settings (auth_url, token_url, userinfo_url, scopes)
- [ ] Typecheck passes
- [ ] Unit tests pass

**Technical Notes:**
- T3K uses custom OAuth flow, not standard client credentials
- Use pydantic Settings for validation
- Reference: `.claude/rules/authentication.md`

---

### STORY-002: Create UserIdentity Model and Migration

**As a** developer
**I want to** store multiple OAuth identities per user
**So that** users can link multiple providers to one account

**Acceptance Criteria:**
- [ ] Create `UserIdentity` SQLAlchemy model in `backend/app/models/user_identity.py`
- [ ] Fields: id, user_id, provider, provider_id, email, email_verified, access_token (encrypted), refresh_token (encrypted), token_expires_at, created_at, updated_at
- [ ] Unique constraint on (provider, provider_id)
- [ ] Index on user_id
- [ ] Index on email WHERE email_verified = TRUE
- [ ] Create Alembic migration for user_identities table
- [ ] Add `identities` relationship to User model
- [ ] Typecheck passes
- [ ] Unit tests for model creation pass

**Technical Notes:**
- access_token and refresh_token are LargeBinary (encrypted bytes)
- Use CASCADE delete on user_id foreign key

---

### STORY-003: Migrate Existing T3K Data to UserIdentities

**As a** system
**I want to** migrate existing T3K authentication data
**So that** existing users continue working with the new model

**Acceptance Criteria:**
- [ ] Create data migration that copies T3K data from users table to user_identities
- [ ] Preserve user_id, tone3000_id as provider_id, tokens
- [ ] Set provider='t3k', email_verified=TRUE for all migrated records
- [ ] Migration is idempotent (can run multiple times safely)
- [ ] Verify no data loss with rollback capability
- [ ] Typecheck passes
- [ ] Integration test verifies migration correctness

**Technical Notes:**
- Do NOT drop columns from users table yet (Phase 5)
- Migration must handle NULL tone3000_id (skip those users)

---

### STORY-004: Implement Encrypted Token Storage

**As a** developer
**I want to** encrypt OAuth tokens at rest
**So that** tokens are protected if database is compromised

**Acceptance Criteria:**
- [ ] Create token encryption module using Fernet
- [ ] Encryption key from environment variable `TOKEN_ENCRYPTION_KEY`
- [ ] Functions: encrypt_token(plaintext) -> bytes, decrypt_token(ciphertext) -> str
- [ ] Handle key rotation (accept list of keys, try each for decryption)
- [ ] Typecheck passes
- [ ] Unit tests for encrypt/decrypt round-trip
- [ ] Unit tests for key rotation scenario

**Technical Notes:**
- Use `cryptography` library (already in requirements)
- Generate key with: `Fernet.generate_key()`

---

### STORY-005: Create OAuth State Management

**As a** developer
**I want to** securely manage OAuth state parameters
**So that** OAuth flows are protected against CSRF and replay attacks

**Acceptance Criteria:**
- [ ] Create `OAuthState` dataclass with: nonce, timestamp, user_id (optional), operation (login/link), code_verifier (PKCE)
- [ ] Create state encoder: encrypt and sign state to URL-safe string
- [ ] Create state decoder: validate signature, decrypt, check expiry (10 min)
- [ ] Generate PKCE code_verifier (64 bytes, URL-safe) and code_challenge (S256)
- [ ] State stored in Redis with TTL matching expiry
- [ ] Typecheck passes
- [ ] Unit tests for state encode/decode round-trip
- [ ] Unit tests for expiry validation
- [ ] Unit tests for PKCE challenge generation

**Technical Notes:**
- Use `secrets.token_urlsafe()` for nonce and code_verifier
- code_challenge = base64url(sha256(code_verifier))
- Redis key pattern: `oauth_state:{nonce}`

---

### STORY-006: Create IdentityService

**As a** developer
**I want to** have a service layer for identity management
**So that** business logic is separated from API endpoints

**Acceptance Criteria:**
- [ ] Create `IdentityService` in `backend/app/services/identity_service.py`
- [ ] Method: `get_user_by_identity(provider, provider_id) -> User | None`
- [ ] Method: `get_user_identities(user_id) -> list[UserIdentity]`
- [ ] Method: `create_identity(user_id, provider, provider_id, email, tokens) -> UserIdentity`
- [ ] Method: `link_identity(user_id, provider, provider_id, email, tokens) -> UserIdentity`
- [ ] Method: `unlink_identity(user_id, provider) -> bool` (with min 1 protection)
- [ ] Method: `find_by_verified_email(email) -> UserIdentity | None`
- [ ] All methods use async with proper transaction handling
- [ ] Typecheck passes
- [ ] Unit tests for each method
- [ ] Integration tests with real database

**Technical Notes:**
- Services own transactions: `async with session.begin()`
- Raise descriptive exceptions for error cases

---

### Phase 2: OAuth Providers

---

### STORY-007: Create Base OAuth Adapter Interface

**As a** developer
**I want to** have a common interface for OAuth providers
**So that** all providers can be used interchangeably

**Acceptance Criteria:**
- [ ] Create abstract base class `OAuthAdapter` in `backend/app/adapters/oauth/base.py`
- [ ] Abstract method: `get_authorization_url(state: str, code_challenge: str) -> str`
- [ ] Abstract method: `exchange_code(code: str, code_verifier: str) -> TokenResponse`
- [ ] Abstract method: `get_user_info(access_token: str) -> UserInfo`
- [ ] Abstract method: `refresh_token(refresh_token: str) -> TokenResponse`
- [ ] Create `TokenResponse` dataclass: access_token, refresh_token, expires_in
- [ ] Create `UserInfo` dataclass: provider_id, email, email_verified, name, avatar_url
- [ ] Create adapter factory: `get_oauth_adapter(provider: OAuthProvider) -> OAuthAdapter`
- [ ] Typecheck passes
- [ ] Unit tests for factory function

**Technical Notes:**
- Use `abc.ABC` and `abc.abstractmethod`
- Factory raises ValueError for unknown providers

---

### STORY-008: Implement Google OAuth Adapter

**As a** user
**I want to** login with my Google account
**So that** I can use GTS without creating a new account

**Acceptance Criteria:**
- [ ] Create `GoogleOAuthAdapter` implementing `OAuthAdapter`
- [ ] Use Google OAuth 2.0 endpoints with PKCE
- [ ] Request scopes: openid, email, profile
- [ ] Parse Google's userinfo response correctly
- [ ] Handle token refresh
- [ ] Register adapter in factory
- [ ] Typecheck passes
- [ ] Unit tests with mocked HTTP responses
- [ ] Integration test with real Google (marked skip in CI)

**Technical Notes:**
- Auth URL: https://accounts.google.com/o/oauth2/v2/auth
- Token URL: https://oauth2.googleapis.com/token
- UserInfo URL: https://www.googleapis.com/oauth2/v3/userinfo
- Google always returns email_verified in userinfo

---

### STORY-009: Implement GitHub OAuth Adapter

**As a** user
**I want to** login with my GitHub account
**So that** I can use GTS with my developer identity

**Acceptance Criteria:**
- [ ] Create `GitHubOAuthAdapter` implementing `OAuthAdapter`
- [ ] Use GitHub OAuth 2.0 endpoints with PKCE
- [ ] Request scopes: read:user, user:email
- [ ] Fetch primary verified email from /user/emails endpoint
- [ ] Handle token refresh (GitHub tokens don't expire, handle gracefully)
- [ ] Register adapter in factory
- [ ] Typecheck passes
- [ ] Unit tests with mocked HTTP responses

**Technical Notes:**
- Auth URL: https://github.com/login/oauth/authorize
- Token URL: https://github.com/login/oauth/access_token
- UserInfo URL: https://api.github.com/user
- Emails URL: https://api.github.com/user/emails (need separate call)

---

### STORY-010: Implement Facebook OAuth Adapter

**As a** user
**I want to** login with my Facebook account
**So that** I can use GTS with my social identity

**Acceptance Criteria:**
- [ ] Create `FacebookOAuthAdapter` implementing `OAuthAdapter`
- [ ] Use Facebook OAuth 2.0 endpoints
- [ ] Request scopes: email, public_profile
- [ ] Parse Facebook's graph API response correctly
- [ ] Handle token refresh via long-lived token exchange
- [ ] Register adapter in factory
- [ ] Typecheck passes
- [ ] Unit tests with mocked HTTP responses

**Technical Notes:**
- Auth URL: https://www.facebook.com/v18.0/dialog/oauth
- Token URL: https://graph.facebook.com/v18.0/oauth/access_token
- UserInfo URL: https://graph.facebook.com/me?fields=id,name,email,picture
- Facebook email may not be verified, check response

---

### STORY-011: Refactor T3K OAuth to Adapter Pattern

**As a** developer
**I want to** T3K authentication to use the adapter pattern
**So that** all providers have consistent implementation

**Acceptance Criteria:**
- [ ] Create `T3KOAuthAdapter` implementing `OAuthAdapter`
- [ ] Migrate existing T3K OAuth logic to adapter
- [ ] Maintain backwards compatibility with existing T3K auth flow
- [ ] Use UserIdentity model instead of User model for token storage
- [ ] Register adapter in factory
- [ ] Existing T3K login continues to work
- [ ] Typecheck passes
- [ ] Integration tests pass

**Technical Notes:**
- T3K uses magic link email, not password
- T3K has custom token exchange, adapt to interface
- This is refactor only, no new functionality

---

### STORY-012: Create Unified Auth Endpoints

**As a** developer
**I want to** unified auth endpoints for all providers
**So that** the API is consistent and maintainable

**Acceptance Criteria:**
- [ ] Create `GET /api/v1/auth/login/{provider}` - initiates OAuth flow
- [ ] Create `GET /api/v1/auth/callback/{provider}` - handles OAuth callback
- [ ] Login endpoint generates state, redirects to provider
- [ ] Callback endpoint validates state, exchanges code, creates session
- [ ] Session cookie set with httponly, secure (prod), samesite=lax
- [ ] Regenerate session ID after successful OAuth
- [ ] Typecheck passes
- [ ] Integration tests for full OAuth flow (mocked provider)

**Technical Notes:**
- Use adapter factory to get provider-specific adapter
- State includes code_verifier for PKCE
- On success, redirect to `?next=` param or home

---

### Phase 3: Account Linking

---

### STORY-013: Implement Account Linking Endpoints

**As a** user
**I want to** link additional OAuth providers to my account
**So that** I can login with any of my social accounts

**Acceptance Criteria:**
- [ ] Create `GET /api/v1/auth/link/{provider}` - requires authenticated session
- [ ] Store user_id in encrypted state parameter
- [ ] Callback detects linking operation from state
- [ ] Create new UserIdentity linked to current user
- [ ] Error if provider_id already linked to different user
- [ ] Success message if already linked to same user
- [ ] Redirect to account settings after linking
- [ ] Typecheck passes
- [ ] Integration tests for linking flow

**Technical Notes:**
- Linking flow uses same callback endpoint as login
- State.operation = "link" vs "login"
- State.user_id = current_user.id

---

### STORY-014: Implement Account Unlinking

**As a** user
**I want to** unlink OAuth providers from my account
**So that** I can manage my authentication options

**Acceptance Criteria:**
- [ ] Create `DELETE /api/v1/auth/unlink/{provider}` - requires auth
- [ ] Verify user has at least 2 linked providers before unlinking
- [ ] Return 400 error if attempting to unlink last provider
- [ ] Delete UserIdentity record for provider
- [ ] Return success with updated provider list
- [ ] Typecheck passes
- [ ] Unit tests for unlink protection
- [ ] Integration tests for unlink flow

**Technical Notes:**
- Count user's identities before delete
- Clear error message: "Cannot unlink your only authentication method"

---

### STORY-015: Implement Auto-Link by Verified Email

**As a** system
**I want to** automatically link accounts with matching verified emails
**So that** users don't create duplicate accounts

**Acceptance Criteria:**
- [ ] During OAuth callback (login, not link), check for existing identity
- [ ] If no identity exists, check for any UserIdentity with same verified email
- [ ] If found, auto-link new provider to existing user
- [ ] Only auto-link when BOTH emails are verified
- [ ] Log auto-link events for audit
- [ ] Typecheck passes
- [ ] Integration tests for auto-link scenarios

**Technical Notes:**
- Security: NEVER auto-link unverified emails
- Use IdentityService.find_by_verified_email()
- Log: "Auto-linked {provider} to user {id} via verified email {email}"

---

### STORY-016: Create Account Settings API

**As a** developer
**I want to** an API for account settings
**So that** the frontend can display linked providers

**Acceptance Criteria:**
- [ ] Update `GET /api/v1/auth/me` to include linked providers
- [ ] Response includes: user info + list of {provider, email, linked_at}
- [ ] Mask sensitive data (no tokens in response)
- [ ] Indicate which providers are available but not linked
- [ ] Typecheck passes
- [ ] Unit tests for response schema
- [ ] Integration tests

**Technical Notes:**
- Compare user's identities vs OAuthProvider enum
- Return both linked and available providers

---

### Phase 4: Login UI

---

### STORY-017: Update Login Page with All Providers

**As a** user
**I want to** see all login options on the login page
**So that** I can choose my preferred authentication method

**Acceptance Criteria:**
- [ ] Display 4 provider buttons: Facebook, GitHub, Google, Tone3000
- [ ] Buttons ordered alphabetically (equal weight)
- [ ] Each button has provider icon and "Continue with {Provider}" text
- [ ] Buttons link to `/api/v1/auth/login/{provider}`
- [ ] Preserve `?next=` parameter for post-login redirect
- [ ] Add "By continuing, you agree to our Terms and Privacy Policy" text
- [ ] Typecheck passes
- [ ] E2E test for login page rendering

**Technical Notes:**
- Use existing Astro login page at `astro/src/pages/login.astro`
- Icons: Font Awesome or inline SVG
- Run `just build-astro` after changes

---

### STORY-018: Create Account Settings Page UI

**As a** user
**I want to** manage my linked accounts in settings
**So that** I can add or remove authentication methods

**Acceptance Criteria:**
- [ ] Create account settings page at `/settings/account`
- [ ] Display all 4 providers with link status
- [ ] Linked providers show email and "Unlink" button
- [ ] Unlinked providers show "Link Account" button
- [ ] Disable unlink button if only one provider linked
- [ ] Show tooltip explaining why unlink is disabled
- [ ] Use HTMX for link/unlink actions
- [ ] Typecheck passes
- [ ] E2E test for settings page

**Technical Notes:**
- Create Jinja2 template at `astro/src/pages/pages/settings_account.html.ts`
- Use existing design tokens from Astro
- HTMX for seamless updates

---

### Phase 5: Security Hardening

---

### STORY-019: Add Rate Limiting on Auth Endpoints

**As a** system
**I want to** rate limit authentication endpoints
**So that** brute force attacks are prevented

**Acceptance Criteria:**
- [ ] Configure nginx rate limiting for `/api/v1/auth/*`
- [ ] Limit: 5 requests per minute per IP
- [ ] Burst: 10 requests with nodelay
- [ ] Return 429 Too Many Requests when exceeded
- [ ] Log rate limit events
- [ ] Typecheck passes
- [ ] Integration test for rate limiting

**Technical Notes:**
- Update `nginx.conf.template`
- Use `limit_req_zone` and `limit_req` directives
- Zone: auth:10m (10MB shared memory)

---

### STORY-020: Implement Session Fixation Protection

**As a** system
**I want to** regenerate session IDs after authentication
**So that** session fixation attacks are prevented

**Acceptance Criteria:**
- [ ] Regenerate session ID after successful OAuth callback
- [ ] Old session ID invalidated immediately
- [ ] New session cookie set with same security attributes
- [ ] Verify protection works across all providers
- [ ] Typecheck passes
- [ ] Integration test for session regeneration

**Technical Notes:**
- Use Starlette's session middleware regeneration
- Or delete old session from Redis, create new

---

### STORY-021: Add Audit Logging for Auth Events

**As a** system
**I want to** log all authentication events
**So that** security incidents can be investigated

**Acceptance Criteria:**
- [ ] Log: login attempts (success/failure)
- [ ] Log: account linking (success/failure)
- [ ] Log: account unlinking
- [ ] Log: auto-link events
- [ ] Log: rate limit triggers
- [ ] Include: timestamp, user_id (if known), provider, IP, user_agent
- [ ] Use structured logging (JSON format)
- [ ] Typecheck passes
- [ ] Unit tests for log format

**Technical Notes:**
- Use Python's logging with structlog or similar
- Log level: INFO for success, WARNING for failures
- Never log tokens or secrets

---

### STORY-022: Security Review and Final Validation

**As a** developer
**I want to** validate all security requirements are met
**So that** the feature is production-ready

**Acceptance Criteria:**
- [ ] PKCE enabled for all 4 providers
- [ ] State parameter signed with nonce + timestamp
- [ ] State expiry enforced (10 min)
- [ ] Cookies: Secure (prod), HttpOnly, SameSite=Lax
- [ ] Auto-link only for verified emails
- [ ] Tokens encrypted at rest
- [ ] Rate limiting active
- [ ] Unlink protection (min 1 provider)
- [ ] Auth events logged
- [ ] Session fixation protection verified
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] E2E tests pass
- [ ] Security checklist from issue #526 complete

**Technical Notes:**
- Use `/security-review` skill for thorough review
- Run `just check` for full validation
- Document any deviations from spec

---

## Out of Scope

- Password-based authentication (all providers use OAuth)
- Two-factor authentication (future enhancement)
- Social features (sharing, friends lists)
- Provider-specific API integrations beyond auth
- Mobile app deep linking
- Account deletion (separate feature)

## Open Questions

- None - comprehensive spec provided in GitHub issue #526
