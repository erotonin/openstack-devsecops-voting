# PostgreSQL Logical Replication Runbook

## Goal

Replicate voting data from AWS RDS PostgreSQL primary to Azure PostgreSQL Flexible Server warm standby using native PostgreSQL logical replication.

This path is opt-in because it creates an Azure PostgreSQL server and enables extra WAL retention on AWS RDS.

## Architecture

- AWS RDS PostgreSQL is the publisher.
- Azure PostgreSQL Flexible Server is the subscriber.
- Replication traffic goes through the existing AWS-Azure IPSec/BGP VPN.
- The replicated table is `public.votes`.

Logical replication sends WAL deltas, not full database copies. It does not replicate DDL automatically, so the subscriber schema must exist before the subscription is created.

## Provisioning

Bring the stack up with the DR database options enabled:

```powershell
.\scripts\infra-up.ps1 `
  -AutoApprove `
  -EnableAzurePostgresStandby `
  -EnablePostgresLogicalReplication
```

Important:

- `EnableAzurePostgresStandby` creates Azure PostgreSQL Flexible Server, private DNS, delegated subnet, and Key Vault runtime values.
- `EnablePostgresLogicalReplication` enables RDS parameter group values needed for logical replication.
- RDS `rds.logical_replication` is static. If Terraform changes it on an existing RDS instance, reboot the DB before creating the publication/subscription.

## Configure Publication And Subscription

After AWS RDS and Azure PostgreSQL are reachable:

```powershell
.\scripts\setup-postgres-logical-replication.ps1
```

The script:

1. Reads Terraform outputs from AWS and Azure.
2. Reads DB credentials from AWS Secrets Manager and Azure Key Vault.
3. Creates or repairs the `votes` table with `id` as primary key.
4. Creates the AWS replication user and grants table read privileges.
5. Creates publication `voting_pub` on AWS.
6. Creates subscription `voting_aws_sub` on Azure.

If you need to recreate the subscription:

```powershell
.\scripts\setup-postgres-logical-replication.ps1 -DropExistingSubscription
```

## Verify

Cast a vote on AWS, then query Azure:

```sql
select vote, count(*) from votes group by vote;
```

On AWS publisher:

```sql
select slot_name, active from pg_replication_slots;
select * from pg_publication_tables where pubname = 'voting_pub';
```

On Azure subscriber:

```sql
select subname, subenabled from pg_subscription;
```

## Operational Notes

- Do not leave unused replication slots behind. Unconsumed slots retain WAL and can fill storage.
- Logical replication does not copy schema migrations. Apply DDL on both sides before adding replicated tables.
- If Azure standby is down for a long time, monitor RDS storage because WAL can accumulate.
- This project replicates only `votes`, which is enough for the demo data path.
