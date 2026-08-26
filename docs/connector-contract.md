# Moodle connector contract 1.0

XPBuilder is Moodle-version independent. The Moodle connector owns Moodle
session, capability, role, mapping, and UI concerns; XPBuilder owns the
Superset REST and embedded runtime.

## Connector responsibilities

- Resolve site-specific internal and public XPBuilder URLs.
- Authenticate to `/api/v1/security/login`.
- Create and manage datasets, charts, dashboards, and embedded records.
- Request guest tokens with Moodle-derived user and RLS claims.
- Store Moodle-to-Superset IDs and UUIDs in Moodle tables.
- Enforce Moodle capabilities before every create, edit, embed, or SSO action.
- Fall back to native dashboards without deleting mappings when XPBuilder is
  unavailable.

## Runtime responsibilities

- Preserve the Superset API behavior required by connector service classes.
- Validate guest-token signatures and audiences.
- Run web, worker, beat, metadata DB, Redis, and the reporting replica.
- Expose `/health` and immutable branding assets.
- Execute reporting queries only through the read-only replica.
- Preserve persistent metadata across image recreations.

## Required API surface

- `POST /api/v1/security/login`
- `POST /api/v1/security/guest_token/`
- Dashboard collection/item and embedded-record endpoints
- Chart collection/item/data endpoints
- Dataset collection/item endpoints
- `GET /health`

The runtime contract test verifies authentication, guest tokens, collection
responses, health, and the XPBuilder branding asset. Moodle CI must separately
exercise conversion, SSO, capabilities, mappings, and browser embedding on both
the 1.x and 2.x connector lines.
