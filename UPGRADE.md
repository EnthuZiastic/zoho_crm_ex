# Upgrading from `pre_jan_2026_refactoring` to `master_latest_single_commit`

## Summary of Major Changes

This is a **full library rewrite**. The library was previously `zoho_crm` (CRM-only, India-region only). It is now `zoho_api` — a multi-service, multi-region client covering CRM, Desk, WorkDrive, Recruit, Bookings, and Projects.

---

## 1. Dependency / App Name Change

**Old:**
```elixir
# mix.exs
{:zoho_crm, ...}
```

**New:**
```elixir
# mix.exs
{:zoho_api, "~> 0.2.0"}
```

The OTP app atom changes from `:zoho_crm` to `:zoho_api`.

---

## 2. Config Key Change

**Old:**
```elixir
config :zoho_crm, :zoho,
  client_id: "...",
  client_secret: "..."
```

**New (per-service keys under `:zoho_api`):**
```elixir
config :zoho_api, :crm,
  client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}

# Desk also requires org_id
config :zoho_api, :desk,
  client_id: {:system, "ZOHO_DESK_CLIENT_ID"},
  client_secret: {:system, "ZOHO_DESK_CLIENT_SECRET"},
  org_id: {:system, "ZOHO_DESK_ORG_ID"}
```

> The old `:zoho_crm, :zoho` key is **not read at all** in the new library. Config will silently not load and calls will raise at runtime.

---

## 3. All Module Namespaces Renamed

Every `ZohoCrm.*` reference must become `ZohoAPI.*`:

| Old | New |
|-----|-----|
| `ZohoCrm.InputRequest` | `ZohoAPI.InputRequest` |
| `ZohoCrm.Config` | `ZohoAPI.Config` |
| `ZohoCrm.Request` | `ZohoAPI.Request` |
| `ZohoCrm.Modules.Records` | `ZohoAPI.Modules.CRM.Records` |
| `ZohoCrm.Modules.Token` | `ZohoAPI.Modules.Token` |
| `ZohoCrm.Modules.Bookings` | `ZohoAPI.Modules.Bookings` |
| `ZohoCrm.Modules.Projects` | `ZohoAPI.Modules.Projects` |
| `ZohoCrm.Modules.Recruit.Records` | `ZohoAPI.Modules.Recruit.Records` |

A deprecated shim `ZohoAPI.Modules.Records` exists but will be removed — migrate to `ZohoAPI.Modules.CRM.Records`.

---

## 4. `InputRequest` — New Fields

The struct gained new optional fields. Existing `InputRequest.new/1-4` calls keep working, but you can now use:

```elixir
# Multi-region (default was hardcoded :in / India)
InputRequest.new(token) |> InputRequest.with_region(:eu)

# Desk API — org_id is now on the InputRequest (was not supported before)
InputRequest.new(token) |> InputRequest.with_org_id("org_123")

# Automatic token refresh on 401
InputRequest.new(token)
|> InputRequest.with_refresh_token(refresh_token)
|> InputRequest.with_on_token_refresh(fn new_token -> MyApp.store(new_token) end)
```

---

## 5. Region — Was Hardcoded India, Now Configurable

**Old:** all URLs were hardcoded to `zohoapis.in` / `recruit.zoho.in` / `accounts.zoho.in`.

**New:** region is a first-class parameter, defaulting to `:in`. Pass `:com`, `:eu`, `:au`, `:jp`, `:uk`, `:ca`, `:sa` as needed.

If your Zoho account is in a region other than India, you **must** set the region or all API calls will fail silently (wrong domain).

```elixir
InputRequest.new(token) |> InputRequest.with_region(:com)   # US account
```

---

## 6. `Token.refresh_access_token/1` Signature Changed

**Old:**
```elixir
ZohoCrm.Modules.Token.refresh_access_token(refresh_token)
# Always used CRM creds, always hit India endpoint
```

**New:**
```elixir
ZohoAPI.Modules.Token.refresh_access_token(refresh_token, region: :in, service: :crm)
# service selects which config block to use; region selects data center
```

---

## 7. Recruit Module — Function Names Changed

**Old:** functions had `_recruit_` in the name.

| Old | New |
|-----|-----|
| `get_recruit_records/1` | `get_records/1` |
| `insert_recruit_records/1` | `insert_records/1` |
| `update_recruit_records/1` | `update_records/1` |
| `search_recruit_records/1` | `search_records/1` |

---

## 8. New Capabilities (Additive — No Action Required Unless You Want Them)

| Feature | Module |
|---------|--------|
| Zoho Desk tickets | `ZohoAPI.Modules.Desk.Tickets` |
| WorkDrive files | `ZohoAPI.Modules.WorkDrive.Files` |
| WorkDrive folders | `ZohoAPI.Modules.WorkDrive.Folders` |
| CRM Bulk Read (up to 200k records) | `ZohoAPI.Modules.CRM.BulkRead` |
| CRM Bulk Write (up to 25k records) | `ZohoAPI.Modules.CRM.BulkWrite` |
| CRM Composite API (5 requests in 1 call) | `ZohoAPI.Modules.CRM.Composite` |
| Pagination helpers (stream / eager) | `ZohoAPI.Pagination` |
| Automatic retry with exponential backoff | `ZohoAPI.Retry` (opt-in via config or `InputRequest.with_retry_opts/2`) |
| Token refresh storm protection | `ZohoAPI.TokenCache` GenServer |
| Rate limiting (PostgreSQL-backed, optional) | `ZohoAPI.RateLimiter` |

---

## Minimum Migration Checklist

- [ ] Change `{:zoho_crm, ...}` to `{:zoho_api, "~> 0.2.0"}` in `mix.exs`
- [ ] Change `config :zoho_crm, :zoho` → `config :zoho_api, :crm` in all config files
- [ ] Global search-replace `ZohoCrm.` → `ZohoAPI.` across `lib/` and `config/`
- [ ] Move `ZohoAPI.Modules.Records` usages to `ZohoAPI.Modules.CRM.Records`
- [ ] Update Recruit function calls (`get_recruit_records` → `get_records`, etc.)
- [ ] If not on India region, add `InputRequest.with_region(:com/:eu/...)` calls
- [ ] If using Desk API, add `InputRequest.with_org_id/2` and a `config :zoho_api, :desk` block
- [ ] Run `mix deps.get` and `mix compile` to verify
