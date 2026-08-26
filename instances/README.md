# Site configurations

Create one subdirectory per site and keep exactly one protected file named
`.env` inside it. `.env` files are ignored by git.

The local deployment launcher recognizes these paths:

- `instances/moodle-5.1/.env`
- `instances/moodle-5.2/.env`

Do not create either file for an existing site until the metadata backup,
secret-key preservation, volume adoption, and rollback preflight in
`docs/migration.md` has been completed.
