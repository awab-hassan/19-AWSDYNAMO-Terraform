# DynamoDB Registry Tables — NetworkingRegistry / TransactionRegistry / AggregatedDataRegistry

Terraform module that provisions the **six DynamoDB tables** behind FanSocial's core platform — three registries (Networking, Transaction, AggregatedData), each shipped as a **staging** + **production** pair — with a carefully designed set of **Global Secondary Indexes (GSIs)** that back the platform's access patterns (follower graph, payout ledger, top-contributor leaderboards, order lookups, etc.).

## Highlights

- **Six tables in one apply** — three registries × two environments (staging + prod) all defined in a single `main-1.tf`; environment prefix + `_staging` suffix keeps them cleanly namespaced.
- **Composite key design** — every table uses a `PK` (hash) + `SK` (range) pattern so a single partition can hold multiple entity types (e.g. a creator's followers list + their payout history).
- **Purpose-built GSIs** — each registry carries the exact set of secondary indexes needed for its workload (see table below); no catch-all scans.
- **On-demand billing (`PAY_PER_REQUEST`)** — no capacity planning; costs track real traffic.
- **Single-region Tokyo** — paired with the global `@PEERING` edge-Lambda pattern, reads land on a regional Lambda that queries back into Tokyo.

## Tables & indexes

| Table | PK / SK | GSIs |
|---|---|---|
| **NetworkingRegistry** (+ `_staging`) | `creator_id` / `fan_id` | `GSI_AllKey`, `creator_records_index`, `fan_records_index` |
| **TransactionRegistry** (+ `_staging`) | `user_id` / `timestamp` | `GSI_Payout`, `GSI_order_id` |
| **AggregatedDataRegistry** (+ `_staging`) | `partition_key` / `sort_key` | `GSI_top_contributor`, `GSI_top_orders`, `GSI_top_tokens` |

- **NetworkingRegistry** — models the creator ↔ fan follow/subscribe graph. `creator_records_index` lists every fan a creator has; `fan_records_index` lists every creator a fan follows; `GSI_AllKey` provides a cross-cut for admin tooling.
- **TransactionRegistry** — payment ledger. `GSI_Payout` surfaces payout events for creators; `GSI_order_id` looks up a transaction by the public order ID issued at checkout.
- **AggregatedDataRegistry** — precomputed leaderboards. Three GSIs rank top contributors, highest-order creators, and highest-token holders for dashboard and "for you" ranking.

## Architecture

```
                    Application (Lambda / ECS / Edge-region Lambdas)
                                       │
   ┌───────────────────────────────────┼────────────────────────────────┐
   ▼                                   ▼                                ▼
 NetworkingRegistry          TransactionRegistry             AggregatedDataRegistry
 (creator_id, fan_id)        (user_id, timestamp)            (partition_key, sort_key)
  + 3 GSIs                    + 2 GSIs                         + 3 GSIs
```

Each registry is mirrored with a `_staging` counterpart for pre-prod testing.

## Tech stack

- **Terraform** >= 1.x, AWS provider
- **AWS services:** DynamoDB (on-demand, GSIs)
- **Region:** `ap-northeast-1` (Tokyo)

## Repository layout

```
@DYNAMO-MONDAY/
├── README.md
├── .gitignore
└── main-1.tf       # six aws_dynamodb_table resources + GSIs
```

## How it works

1. Each `aws_dynamodb_table` declares `billing_mode = "PAY_PER_REQUEST"` plus its PK/SK and the string/number type of every indexed attribute.
2. `global_secondary_index` blocks project the attributes that each access pattern needs (typically `ALL`).
3. Tables are named with an environment suffix (`..._staging` / `...`) so Terraform's single apply produces both copies.

## Prerequisites

- Terraform >= 1.x
- AWS CLI with permissions for `dynamodb:*`

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

## Teardown

```bash
terraform destroy
```

> ⚠️ This destroys data. Take a point-in-time backup or export to S3 first.

## Notes

- On-demand billing is the right default for bursty social traffic; if traffic flattens out, switch specific tables to `PROVISIONED` + autoscaling for cost.
- GSIs multiply write cost — every write to the base table also writes to every matching GSI. Review which GSIs are actually queried before adding more.
- Demonstrates: DynamoDB single-table / registry modelling, composite PK+SK design, GSI-per-access-pattern, staging/production parity via Terraform.
