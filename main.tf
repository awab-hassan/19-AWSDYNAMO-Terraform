terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "xx-region-1"
}

locals {
  envs = {
    staging    = { name_prefix = "staging", deletion_protection = false }
    production = { name_prefix = "",        deletion_protection = true  }
  }
}

# Networking Registry
resource "aws_dynamodb_table" "networking_registry" {
  for_each = local.envs

  name         = "${each.value.name_prefix}NetworkingRegistry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute { name = "PK";         type = "S" }
  attribute { name = "SK";         type = "S" }
  attribute { name = "ALTPK";      type = "S" }
  attribute { name = "ALTSK";      type = "S" }
  attribute { name = "creator_id"; type = "S" }
  attribute { name = "user_id";     type = "S" }

  global_secondary_index {
    name            = "GSI_AllKey"
    hash_key        = "ALTPK"
    range_key       = "ALTSK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "creator_records_index"
    hash_key        = "creator_id"
    range_key       = "PK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "user_records_index"
    hash_key        = "user_id"
    range_key       = "PK"
    projection_type = "ALL"
  }

  deletion_protection_enabled = each.value.deletion_protection
  point_in_time_recovery { enabled = true }
  server_side_encryption  { enabled = true }

  tags = {
    Environment = each.key
    Project     = "DynamoMonday"
  }
}

# Transaction Registry
resource "aws_dynamodb_table" "transaction_registry" {
  for_each = local.envs

  name         = "${each.value.name_prefix}TransactionRegistry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute { name = "PK";              type = "S" }
  attribute { name = "SK";              type = "S" }
  attribute { name = "ALTPK";           type = "S" }
  attribute { name = "ALTSK";           type = "S" }
  attribute { name = "creator_id";      type = "S" }
  attribute { name = "user_id";          type = "S" }
  attribute { name = "GSI_Payout_PK";   type = "S" }
  attribute { name = "transaction_date"; type = "S" }
  attribute { name = "order_id";        type = "S" }

  global_secondary_index {
    name            = "GSI_AllKey"
    hash_key        = "ALTPK"
    range_key       = "ALTSK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "creator_records_index"
    hash_key        = "creator_id"
    range_key       = "PK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "user_records_index"
    hash_key        = "user_id"
    range_key       = "PK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_Payout"
    hash_key        = "GSI_Payout_PK"
    range_key       = "transaction_date"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_order_id"
    hash_key        = "order_id"
    projection_type = "ALL"
  }

  deletion_protection_enabled = each.value.deletion_protection
  point_in_time_recovery { enabled = true }
  server_side_encryption  { enabled = true }

  tags = {
    Environment = each.key
    Project     = "DynamoMonday"
  }
}

# Aggregated Data Registry
resource "aws_dynamodb_table" "aggregated_data_registry" {
  for_each = local.envs

  name         = "${each.value.name_prefix}AggregatedDataRegistry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "flag"

  attribute { name = "id";                  type = "S" }
  attribute { name = "flag";                type = "S" }
  attribute { name = "GSISK_t_contributor"; type = "S" }
  attribute { name = "GSISK_t_orders";      type = "S" }
  attribute { name = "GSISK_t_tokens";      type = "S" }

  global_secondary_index {
    name            = "GSI_top_contributor"
    hash_key        = "id"
    range_key       = "GSISK_t_contributor"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_top_orders"
    hash_key        = "id"
    range_key       = "GSISK_t_orders"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_top_tokens"
    hash_key        = "id"
    range_key       = "GSISK_t_tokens"
    projection_type = "ALL"
  }

  deletion_protection_enabled = each.value.deletion_protection
  point_in_time_recovery { enabled = true }
  server_side_encryption  { enabled = true }

  tags = {
    Environment = each.key
    Project     = "DynamoMonday"
  }
}
