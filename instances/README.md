# Site configurations

Create one subdirectory per site (named after the site, not the Moodle
version) and keep exactly one protected file named `.env` inside it. `.env`
files are ignored by git.

The local deployment launcher recognizes these paths:

- `instances/xp521/.env`   (Moodle 5.2 — site xp521.openxpertz.com)
- `instances/xprompt/.env` (Moodle 5.1 — site xprompt.openxpertz.com)

Do not create either file for an existing site until the metadata backup,
secret-key preservation, volume adoption, and rollback preflight in
`docs/migration.md` has been completed.

## Per-site runtime ports

Each site binds one browser-facing host port (mapped to the container's
internal 8088). Keep ports unique per site and identical on local and the
production VM:

| Site | `XPBUILDER_INSTANCE` | Host port | Internal port |
| --- | --- | --- | --- |
| xp521  (Moodle 5.2) | `xprompt52` | `8089` | `8088` |
| xprompt (Moodle 5.1) | `xprompt`   | `8088` | `8088` |

On the VM, nginx terminates TLS for `xp521superset.openxpertz.com` and proxies
to the site's host port (`/etc/nginx/sites-available/xp521superset.openxpertz.com`
→ `localhost:8089`). Create the equivalent site file for the 5.1 public domain
when the 5.1 cutover happens.
