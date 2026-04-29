# Project # 19 - Dynamodb Registry Terraform

Terraform module that provisions six DynamoDB tables across three registries (Networking, Transaction, AggregatedData), each deployed as a staging and production pair, with purpose-built Global Secondary Indexes (GSIs) for the platform's core access patterns.

## Tables and Indexes

| Table | PK / SK | GSIs |
|---|---|---|
| NetworkingRegistry (+ `_staging`) | `creator_id` / `fan_id` | `GSI_AllKey`, `creator_records_index`, `fan_records_index` |
| TransactionRegistry (+ `_staging`) | `user_id` / `timestamp` | `GSI_Payout`, `GSI_order_id` |
| AggregatedDataRegistry (+ `_staging`) | `partition_key` / `sort_key` | `GSI_top_contributor`, `GSI_top_orders`, `GSI_top_tokens` |

**NetworkingRegistry** — models the creator/fan follow and subscribe graph. `creator_records_index` lists every fan a creator has; `fan_records_index` lists every creator a fan follows; `GSI_AllKey` provides a full cross-cut for admin tooling.

**TransactionRegistry** — payment ledger. `GSI_Payout` surfaces payout events per creator; `GSI_order_id` looks up a transaction by public order ID.

**AggregatedDataRegistry** — precomputed leaderboard data. Three GSIs rank top contributors, highest-order creators, and highest-token holders for feed ranking and dashboards.

## Architecture

```
Application (Lambda / ECS)
         |
         +---> NetworkingRegistry   (creator_id + fan_id, 3 GSIs)
         +---> TransactionRegistry  (user_id + timestamp, 2 GSIs)
         +---> AggregatedDataRegistry (partition_key + sort_key, 3 GSIs)

Each registry has a _staging counterpart for pre-production testing.
```

## Stack

Terraform 1.x · AWS DynamoDB (on-demand) · ap-northeast-1 (Tokyo)

## Repository Layout

```
dynamodb-registry-terraform/
├── main-1.tf       # Six aws_dynamodb_table resources with GSIs
├── .gitignore
└── README.md
```

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

Take a point-in-time backup or export to S3 before destroying. This operation is irreversible.

## Notes

- All tables use `PAY_PER_REQUEST` billing. If traffic patterns stabilise, switching to `PROVISIONED` with autoscaling reduces cost.
- Every write to a base table also writes to all its GSIs. Review GSI usage before adding new indexes.
- `_staging` suffix on table names keeps staging and production isolated within the same AWS account and Terraform apply.
