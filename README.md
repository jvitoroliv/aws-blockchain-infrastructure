# Blockchain Fintech — Cloud Infrastructure & Deployment

I joined a blockchain fintech startup as the first DevOps engineer. No IaC, no CI/CD worth calling that, and three AWS accounts with zero automation. I built the Terraform foundation, set up pipelines, and got their blockchain workloads (R3 Corda) running on EKS.

## Platform context

The company builds financial technology products on R3 Corda, a blockchain framework designed for regulated industries. Their notary nodes validate and finalize transactions on the Corda network. The workloads are Java-based, running on specialized Docker images, and they need reliable deployment pipelines because downtime on a notary node means the network stops processing transactions.

## What I found when I started

Three AWS accounts, all configured by hand through the console. No Terraform, no CloudFormation, nothing automated. Deployments were someone SSH'ing into a server, pulling the latest JAR, restarting the process. Azure DevOps had a few pipelines but they were basic and didn't cover infrastructure.

## What I built

### Terraform from scratch

I imported all three AWS accounts into Terraform. Every VPC, subnet, security group, IAM role, ECS cluster, RDS instance. Starting from `terraform import` on existing resources, then writing the `.tf` files to match what was already running. Nothing got recreated, nothing had downtime. The target: `terraform plan` showing zero changes against what's live.

### CI/CD pipelines (Azure DevOps)

The main pipeline (`build-container-deploy-k8s-prd.yml`) handles the full deployment flow:

1. Triggers on merge to `master`
2. Builds the Docker image
3. Pushes to ECR (account `333333333333.dkr.ecr.us-east-2.amazonaws.com`)
4. Uploads Kubernetes manifests as pipeline artifacts
5. Deploys to the EKS cluster

The pipeline uses Azure DevOps's `ECRPushImage` task with dedicated `ECR-REGISTRY-PROD` service connections. Separate credentials per environment, no shared keys.

### Docker setup for Corda

The Corda notary Dockerfile is minimal but specific:

```dockerfile
FROM azul/zulu-openjdk-alpine:8u242
COPY clients-0.1.jar /app/clients.jar
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh
ENTRYPOINT ["/app/run.sh"]
```

Zulu OpenJDK because Corda 4.5.2 needs Java 8, and Azul's builds are tested with Corda specifically. The `clients.jar` is the notary application, and `run.sh` handles JVM flags and Corda-specific startup parameters.

### Cloud integration (.NET)

The platform also has .NET components for AWS service integration. The SNS notification service shows the pattern:

```csharp
public class AWSSNS : IPushNotification
{
    public async Task<bool> SendTargetedNotification(string endpointArn, string message)
    {
        // Push to specific device via platform endpoint ARN
    }

    public async Task<bool> SendBroadcastNotification(string topicArn, string message)
    {
        // Publish to SNS topic for all subscribers
    }
}
```

Two notification paths: targeted (specific device by ARN) and broadcast (SNS topic). Error handling catches `EndpointDisabledException`. When a mobile device has disabled push notifications, the endpoint goes dead and AWS throws this specific exception. The code catches it and moves on instead of failing the whole notification batch.

## Architecture

```
Azure DevOps Pipeline
    → Docker build (Corda notary on Zulu JDK 8)
    → Push to ECR (per-environment registry)
    → Deploy to EKS
    → Corda notary nodes validate blockchain transactions

AWS Infrastructure (3 accounts, Terraform-managed):
    ├── VPCs, subnets, security groups
    ├── EKS clusters (Corda workloads)
    ├── ECR registries (per-environment)
    ├── RDS instances (Corda node databases)
    ├── IAM roles and policies
    └── SNS/SES for notifications (.NET integration)
```

## Tech stack

| Layer | Tools |
|---|---|
| Cloud | AWS (EKS, ECR, RDS, SNS, SES, VPC, IAM) |
| IaC | Terraform |
| CI/CD | Azure DevOps Pipelines |
| Containers | Docker, EKS |
| Blockchain | R3 Corda Enterprise 4.5.2 |
| Runtime | Azul Zulu OpenJDK 8u242 |
| Application | .NET (C#) for AWS integrations, Java for Corda |

## Repository structure

```
blockchain-fintech-aws/
├── pipelines/
│   └── build-container-deploy-k8s-prd.yml   # Main deployment pipeline
├── docker/
│   └── api.dockerFile                        # Corda notary container
├── dotnet-cdk/
│   └── orders-infra-aws/
│       └── AWSSNS.cs                         # SNS notification service
└── terraform/                                # AWS infrastructure
```

## What happened next

After I stabilized the AWS infrastructure and got proper CI/CD in place, the company won GCP credits through a partnership. I started planning the GCP migration before my contract ended. The Terraform work made that feasible. When your infra is already code, switching providers is still a lot of work, but you're rewriting modules, not starting from the console clicking around. They went ahead with the migration after I left.
