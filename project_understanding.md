# Project Understanding — DynamoMonday

## What This Project Does

This Terraform project provisions the **entire DynamoDB data layer** for a creator-fan social platform (FanSocial). Running `terraform apply` creates 6 DynamoDB tables in AWS Your region (`xx-region-1`) — a staging and production pair for each of three registries.

---

## The Three Registries

### 1. NetworkingRegistry
Stores the social graph: who follows whom, creator-fan relationships, and connection metadata.

- **PK / SK** — primary composite key for direct lookups (e.g. `USER#<id>` / `FOLLOW#<id>`)
- **GSI_AllKey** (`ALTPK` → `ALTSK`) — alternate key pattern for lookups that don't fit the main PK shape
- **creator_records_index** (`creator_id` → `PK`) — fetch all records belonging to a specific creator
- **fan_records_index** (`fan_id` → `PK`) — fetch all records belonging to a specific fan

### 2. TransactionRegistry
Stores every financial event: purchases, payouts, token transfers, order history.

Inherits the same three indexes as NetworkingRegistry, plus two more:

- **GSI_Payout** (`GSI_Payout_PK` → `transaction_date`) — query payout batches sorted by date; `GSI_Payout_PK` is a synthetic key (e.g. `PAYOUT#<creator_id>`) written at transaction time
- **GSI_order_id** (`order_id`) — point lookup by order ID (no range key — hash-only GSI for exact matches)

### 3. AggregatedDataRegistry
Stores pre-computed leaderboard snapshots and rollup statistics. Different primary key design:

- **PK** is `id` (the leaderboard partition, e.g. `LEADERBOARD#WEEKLY`)
- **SK** is `flag` (a status or category flag)
- Three GSIs share `id` as hash key but use different range keys (`GSISK_t_contributor`, `GSISK_t_orders`, `GSISK_t_tokens`) — this lets the app sort one leaderboard partition by contributor count, order count, or token count independently

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `PAY_PER_REQUEST` billing | No capacity planning needed; scales automatically with traffic; zero cost when idle (good for staging) |
| Composite PK + SK on all tables | Single-table-style flexibility — one table can hold many entity types distinguished by key prefixes |
| `ALTPK` / `ALTSK` as GSI keys | Allows a second, independent access pattern without restructuring the main table |
| `GSI_order_id` has no range key | Order IDs are globally unique — a hash-only GSI returns a single item, making a range key unnecessary |
| `deletion_protection_enabled` on prod | Prevents accidental `terraform destroy` from wiping live data; must be manually disabled first |
| PITR enabled on all tables | 35-day continuous backup window; restores to any second — required for any production data |
| SSE enabled on all tables | AES-256 encryption at rest using AWS-managed keys (aws/dynamodb KMS key) |

---

## Infrastructure Layout

```
xx-region-1 (Your region)
├── stagingNetworkingRegistry       [staging]
├── NetworkingRegistry              [production, deletion-protected]
├── stagingTransactionRegistry      [staging]
├── TransactionRegistry             [production, deletion-protected]
├── stagingAggregatedDataRegistry   [staging]
└── AggregatedDataRegistry          [production, deletion-protected]
```

All 6 tables share:
- Tags: `Environment` + `Project = DynamoMonday`
- PITR: enabled
- SSE: enabled

---

## How to Deploy

```bash
# 1. Authenticate to AWS (credentials must have DynamoDB + IAM permissions)
export AWS_PROFILE=your-profile   # or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

# 2. Initialize — downloads the AWS provider
terraform init

# 3. Preview what will be created (6 DynamoDB tables)
terraform plan

# 4. Apply
terraform apply
```

To tear down **staging only**, use targeted destroy:

```bash
terraform destroy \
  -target=aws_dynamodb_table.staging_networking_registry \
  -target=aws_dynamodb_table.staging_transaction_registry \
  -target=aws_dynamodb_table.staging_aggregated_data_registry
```

> Production tables have `deletion_protection_enabled = true`. To destroy them you must first set that flag to `false`, apply, then destroy.

---

## Cost Profile

- **Staging** — near-zero when idle (`PAY_PER_REQUEST` with no traffic = $0 table cost; only storage is billed)
- **Production** — scales linearly with writes; each GSI multiplies write cost (a write to TransactionRegistry touches 5 GSIs = 5× write units consumed)
- **PITR** — adds ~20% to storage cost per table; charged by GB stored

---

## Terraform Provider

| Setting | Value |
|---|---|
| AWS provider | `hashicorp/aws ~> 4.0` |
| Terraform version | `>= 1.0` |
| Region | `xx-region-1` (your region) |
