# MDLBEAST Ticketing Platform — Architecture

**Last Updated:** 2026-03-04

---

## System Overview

The MDLBEAST Ticketing Platform is a **polyglot microservices monorepo** where each service is an independent git repository cloned into a single parent directory. There is **no root-level build system** — every service builds, tests, and deploys independently.

**Repository root:** `/Users/paulo/Repositories/mdlbeasts/ticketing-platform/`

Each service directory contains its own `.git/`, its own CI/CD workflows (`.github/workflows/`), and its own deployment configuration. When you work on a service, you are inside a standalone git repo.

---

## Service Inventory

### Shared Libraries (.NET 8.0)

| Service Directory | Purpose |
|---|---|
| `ticketing-platform-tools` | NuGet packages (`TP.Tools.*`) published to GitHub Packages; consumed by every .NET service |
| `ticketing-platform-infrastructure` | Shared AWS CDK stacks: EventBridge event bus, SQS queues, monitoring, networking |

### API Gateway

| Service Directory | Purpose |
|---|---|
| `ticketing-platform-gateway` | YARP reverse proxy (.NET 8.0 + AWS Lambda); handles auth, routing, policy enforcement |

### Business Domain Services (.NET 8.0, AWS Lambda)

| Service Directory | Domain |
|---|---|
| `ticketing-platform-sales` | Orders, payments, customers, affiliates, marketplace |
| `ticketing-platform-catalogue` | Events, tickets, categories, timeslots, venues |
| `ticketing-platform-inventory` | Cart, reservations, stock management, seating |
| `ticketing-platform-pricing` | Cart pricing, discounts, coupon codes |
| `ticketing-platform-access-control` | Scannables, scan operations, scanner devices, access gates |
| `ticketing-platform-organizations` | Organizations, branches, channels, users, roles, permissions |
| `ticketing-platform-media` | PDF ticket generation, templates, media assets |
| `ticketing-platform-reporting-api` | Sales reporting, charts, aggregates |
| `ticketing-platform-transfer` | Ticket transfer flows |
| `ticketing-platform-loyalty` | Loyalty program data |
| `ticketing-platform-marketplace-service` | Secondary market listing management |
| `ticketing-platform-geidea` | Geidea payment gateway integration |
| `ticketing-platform-csv-generator` | Async CSV export generation |
| `ticketing-platform-pdf-generator` | PDF scannable ticket generation |
| `ticketing-platform-integration` | Third-party integration service (Peoplevine, etc.) |
| `ticketing-platform-distribution-portal` | Distribution partner backend |

### Extension System (.NET 8.0, AWS Lambda)

| Service Directory | Purpose |
|---|---|
| `ticketing-platform-extension-api` | REST API for managing custom extension code |
| `ticketing-platform-extension-executor` | Executes extension scripts in isolated Lambda environments |
| `ticketing-platform-extension-deployer` | Deploys extension code as Lambda functions |
| `ticketing-platform-extension-log-processor` | Processes execution logs from extension Lambdas |

### Frontend

| Service Directory | Stack |
|---|---|
| `ticketing-platform-dashboard` | Next.js 15, React 18, MUI 5, styled-components, @tanstack/react-query |
| `ticketing-platform-distribution-portal-frontend` | Next.js 13 — distribution partner portal |

### Mobile

| Service Directory | Stack |
|---|---|
| `ticketing-platform-mobile-scanner` | Expo 52 (React Native), Android only — handheld/fixed scanner app |
| `ticketing-platform-mobile-libraries` | Yarn workspace monorepo with shared native modules |

### Configuration & Infrastructure

| Service Directory | Purpose |
|---|---|
| `ticketing-platform-configmap-dev` | Kubernetes ConfigMaps for dev environment |
| `ticketing-platform-configmap-sandbox` | Kubernetes ConfigMaps for sandbox environment |
| `ticketing-platform-configmap-prod` | Kubernetes ConfigMaps for prod environment |
| `ticketing-platform-terraform-dev` | Terraform modules for dev infra |
| `ticketing-platform-terraform-prod` | Terraform modules for prod infra |
| `ticketing-platform-shared` | Shared assets/configs (not a deployable service) |

---

## .NET Service Architecture — Clean Architecture Pattern

Every business domain service follows **Clean Architecture** with a consistent project layout:

```
ticketing-platform-{service}/
├── src/
│   ├── TP.{Service}.API/              # ASP.NET Core + Lambda entry point
│   │   ├── Features/                  # Feature-based vertical slices
│   │   │   └── {Feature}/
│   │   │       ├── {Feature}Controller.cs
│   │   │       ├── {Action}/{Action}Command.cs or {Action}Query.cs
│   │   │       ├── {Action}/{Action}Handler.cs
│   │   │       ├── {Action}/{Action}Validator.cs
│   │   │       └── {Action}/{Action}RequestBody.cs
│   │   ├── LambdaEntry.cs             # AWS Lambda entry point
│   │   ├── DatabaseMigrationLambdaEntry.cs
│   │   ├── CommonStartup.cs           # Shared DI setup
│   │   └── LambdaStartup.cs
│   │
│   ├── TP.{Service}.Domain/           # Entities, aggregates, interfaces
│   │   └── Aggregates/
│   │       └── {Aggregate}/
│   │           ├── {Aggregate}.cs     # Aggregate root
│   │           └── HistoryEvents/
│   │
│   ├── TP.{Service}.Infrastructure/   # EF Core, repositories, external services
│   │   ├── DataContexts/
│   │   │   ├── PgSqlDataContext.cs
│   │   │   ├── ReadonlyPgSqlDataContext.cs
│   │   │   └── ReportingPgSqlDataContext.cs
│   │   ├── Repositories/
│   │   │   ├── IUnitOfWork.cs
│   │   │   ├── IReadonlyUnitOfWork.cs
│   │   │   ├── UnitOfWork.cs
│   │   │   └── ReadonlyUnitOfWork.cs
│   │   ├── Configurations/            # EF Core entity configs
│   │   ├── Migrations/                # EF Core migrations
│   │   ├── Services/                  # External service clients
│   │   └── Mapping/                   # AutoMapper profiles
│   │
│   ├── TP.{Service}.Consumers/        # SQS event consumer Lambda
│   │   ├── Function.cs                # Lambda handler (SQSEvent)
│   │   ├── ConsumersStartup.cs
│   │   └── Consumers/
│   │       └── {Domain}/
│   │           └── {Event}Handler.cs
│   │
│   ├── TP.{Service}.BackgroundJobs/   # AWS Scheduler background jobs
│   │   ├── Function.cs
│   │   └── BackgroundJobs/
│   │       └── {JobName}Job.cs
│   │
│   ├── TP.{Service}.Cdk/              # Per-service CDK stacks
│   │   ├── Program.cs
│   │   └── Stacks/
│   │       ├── ServerlessBackendStack.cs
│   │       ├── ConsumersStack.cs
│   │       ├── BackgroundJobsStack.cs
│   │       └── DbMigratorStack.cs
│   │
│   └── Tests/
│       ├── TP.{Service}.UnitTests/
│       ├── TP.{Service}.IntegrationTests/
│       ├── TP.{Service}.ConsumerTests/
│       └── TP.{Service}.BackgroundJobsTests/
```

### Example: Sales Service
- `ticketing-platform-sales/src/TP.Sales.API/` — API + Lambda entry
- `ticketing-platform-sales/src/TP.Sales.Domain/` — Order, Customer, Affiliate aggregates
- `ticketing-platform-sales/src/TP.Sales.Infrastructure/` — PostgreSQL via EF Core, service clients
- `ticketing-platform-sales/src/TP.Sales.Consumers/` — SQS event handlers
- `ticketing-platform-sales/src/TP.Sales.BackgroundJobs/` — Scheduled jobs (expire orders, check Tabby payments)
- `ticketing-platform-sales/src/TP.Sales.Cdk/` — CDK app deploying 4 stacks

---

## CQRS with MediatR

All .NET services implement CQRS using **MediatR**. Each feature is a vertical slice:

**Command (write):**
```
CreateOrderCommand.cs     → implements IRequest<Result<CreateOrderResponse>>
CreateOrderHandler.cs     → implements IRequestHandler<CreateOrderCommand, Result<CreateOrderResponse>>
CreateOrderValidator.cs   → FluentValidation rules
CreateOrderRequestBody.cs → HTTP request body DTO
```

**Query (read):**
```
GetOrderQuery.cs          → implements IRequest<Result<OrderDto>>
GetOrderHandler.cs        → implements IRequestHandler<GetOrderQuery, Result<OrderDto>>
GetOrderValidator.cs
GetOrderQueryParams.cs    → HTTP query params DTO
```

**Controller dispatches to MediatR:**
```csharp
// ticketing-platform-sales/src/TP.Sales.API/Features/Orders/OrdersController.cs
[HttpGet("{organization_id:guid}/{branch_id:guid}/orders/{id:guid}")]
public async Task<ActionResult> GetOrder(
    [FromRoute] GetOrderQuery request,
    CancellationToken cancellationToken)
{
    var result = await _mediator.Send(request, cancellationToken);
    return HandleResult(result);
}
```

**Handler with primary constructor injection:**
```csharp
// ticketing-platform-sales/src/TP.Sales.API/Features/Orders/CreateOrder/CreateOrderHandler.cs
public sealed class CreateOrderHandler(
    IUnitOfWork unitOfWork,
    ILogger<CreateOrderHandler> logger,
    IMessageSender messageSender,
    IInventoryService inventoryService,
    IPaymentService paymentService,
    ICurrentUserOrChannelAccessor currentUserOrChannelAccessor,
    IMapper mapper,
    IPricingService pricingService,
    ICatalogueService catalogueService,
    ICorrelationIdAccessor correlationIdAccessor,
    IHttpContextAccessor httpContextAccessor,
    IOrderSeatingBookAndReleaseService orderSeatingBookAndReleaseService,
    IMarketplaceService marketplaceService)
        : IRequestHandler<CreateOrderCommand, Result<CreateOrderResponse>>
```

**MediatR registration** (in `CommonStartup.cs`):
```csharp
services.AddMediatR(x => x.RegisterServicesFromAssemblies(
    ApiAssembly.Assembly(),
    InfrastructureAssembly.Type().Assembly,
    typeof(PaymentCapturedIntegrationEvent).Assembly,
    typeof(TicketCreatedIntegrationEvent).Assembly));
```

A **caching pipeline** is registered globally:
```csharp
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(MediatrCachingPipeline<,>));
```

A **FluentValidation pipeline** is wired in via `TP.Tools.Validator`.

---

## Lambda Entry Points

### API Lambda (`LambdaEntry.cs`)

Every API service has `LambdaEntry.cs` in the API project. It extends `Amazon.Lambda.AspNetCoreServer.APIGatewayProxyFunction`, bridging API Gateway REST API to ASP.NET Core.

On cold start, it:
1. Reads `TP_ENVIRONMENT` env var
2. Loads secrets from AWS Secrets Manager (`/{environment}/{service}`)
3. Loads SSM parameters (`/{environment}/tp/InternalServices`)
4. Boots ASP.NET Core via `LambdaStartup.cs`

```csharp
// ticketing-platform-sales/src/TP.Sales.API/LambdaEntry.cs
public class LambdaEntry : Amazon.Lambda.AspNetCoreServer.APIGatewayProxyFunction
{
    protected override void Init(IWebHostBuilder builder)
    {
        var environment = new TPEnvironmentDiscovery().Environment;
        AsyncHelper.RunSync(() => SecretManagerHelper.LoadSecretsToEnvironmentAsync($"/{environment}/sales"));
        AsyncHelper.RunSync(() => ParameterStoreHelper.LoadParametersToEnvironmentAsync($"/{environment}/tp/InternalServices"));
        builder.UseStartup<LambdaStartup>();
    }
}
```

X-Ray tracing is integrated at this level with subsegments and annotations.

### Consumer Lambda (`Function.cs` in `TP.{Service}.Consumers/`)

Handles `SQSEvent` — triggered when SQS queue receives messages from EventBridge.

```csharp
// ticketing-platform-sales/src/TP.Sales.Consumers/Function.cs
public async Task Handler(SQSEvent sqsEvent, ILambdaContext context)
{
    foreach (var message in sqsEvent.Records)
    {
        message = await new ExtendedMessageRetriever().RetrieveMessageAsync(message);
        var notificationEvent = LambdaUtilities.ParseNotificationEvent(message);
        await _mediator.Publish(notificationEvent);   // dispatches to INotificationHandler<T>
    }
}
```

The consumer builds its own DI container via `ConsumersStartup.Setup()`, which registers the same domain/infrastructure services as the API but substitutes fakes for HTTP-context-dependent services (e.g., `FakeCurrentUserOrChannelAccessor`).

### Background Jobs Lambda

Invoked by AWS EventBridge Scheduler (cron expressions defined in CDK). Entry via `BackgroundJobs/Function.cs`. Jobs are dispatched by class name using reflection:

```csharp
// ticketing-platform-sales/src/TP.Sales.BackgroundJobs/Function.cs
var inputEvent = JsonConvert.DeserializeObject<BackgroundJobInputEvent>(inputEventString);
await BackgroundJobsUtilities.InvokeBackgroundJobByClassName(inputEvent, _provider, correlationId, default);
```

### Database Migration Lambda

`DatabaseMigrationLambdaEntry.cs` — separate Lambda that runs EF Core migrations during deployment.

---

## Event-Driven Architecture

### Overview

```
Service A (publisher)
    │ IMessageSender.SendMessageAsync(integrationEvent)
    ▼
AWS EventBridge bus (event-bus-{env})
    │ Source = "TicketingPlatform"
    │ DetailType = event class name (e.g. "OrderCreatedIntegrationEvent")
    ▼
EventBridge rule (per consumer service, defined in ConsumerSubscriptionStack)
    ▼
SQS queue ({consumer}-queue-{env})
    │ Lambda event source mapping
    ▼
Consumer Lambda (TP.{Service}.Consumers / Function.cs)
    │ IMediator.Publish(parsedEvent)
    ▼
IntegrationEventHandlerBase<TEvent>.Handle()
    │ dedup check → HandleAsync(scope, event, ct)
    ▼
Concrete handler (e.g. PaymentCapturedHandler)
```

### Event Publication

Services publish via `IMessageSender` (from `TP.Tools.MessageBroker`):
```csharp
await messageSender.SendMessageAsync(
    new OrderCreatedIntegrationEvent { CorrelationId = correlationId, Data = ... },
    cancellationToken);
```

**Implementation:** `ticketing-platform-tools/TP.Tools.MessageBroker/Implementations/MessageProducer.cs`
- Serializes event to JSON
- Publishes to EventBridge bus `event-bus-{env}` with `Source = "TicketingPlatform"` and `DetailType = event class name`
- Skips publishing in test environments

### IntegrationEvent Base Class

```csharp
// ticketing-platform-tools/TP.Tools.MessageBroker/Entities/Events/IntegrationEvent.cs
public abstract record IntegrationEvent : INotification
{
    public string DerivedTypeName { get => this.GetType().AssemblyQualifiedName; }
    public DateTime CreateAt { get; } = DateTime.UtcNow;
    public string MessageBodyId { get; set; }
    public string CorrelationId { get; set; }
}
```

Events are defined in `ticketing-platform-tools/TP.Tools.MessageBroker/Entities/Events/` organized by domain:
```
Events/
├── Order/          OrderCreatedIntegrationEvent, OrderCompletedIntegrationEvent, etc.
├── Payment/        PaymentCapturedIntegrationEvent, PaymentRefundedIntegrationEvent, etc.
├── Ticket/         TicketCreatedIntegrationEvent
├── CatalogueEvent/ CatalogueEventBasicInfoChangedIntegrationEvent, etc.
├── Organizations/  OrganizationCreatedIntegrationEvent, etc.
├── Cart/           CreateOrderIntegrationEvent (cart → order flow)
├── CsvGenerator/   CsvDataRequested<T> (generic event for CSV export)
├── AccessControl/  ScannableBookableObjectChangedIntegrationEvent, etc.
├── Extension/      ExtensionExecuteEvent
├── Marketplace/    MarketplaceOrderImmediateTransfersCompletedIntegrationEvent
└── ...25+ domain categories
```

### Large Message Handling

Payloads too large for EventBridge/SQS (>256 KB) are stored in S3 bucket `ticketing-{env}-extended-message`. The `MessageProducer` detects oversized messages and uploads to S3. Consumers use `ExtendedMessageRetriever` to transparently download the full payload.

### Consumer Idempotency

`IntegrationEventHandlerBase<TEvent>` (in `ticketing-platform-tools/TP.Tools.MessageBroker/Consumers/IntegrationEventHandlerBase.cs`):

```csharp
public async Task Handle(TEvent notification, CancellationToken cancellationToken)
{
    using var scope = _serviceScopeFactory.CreateScope();
    var consumedMessageId = integrationEvent.MessageBodyId + GetType().AssemblyQualifiedName;

    if (await consumerMessageRepository.HasConsumedMessageAsync(consumedMessageId, cancellationToken))
    {
        // Skip — already processed
        return;
    }

    consumerMessageRepository.AddConsumedMessage(new ConsumedMessage(consumedMessageId));
    await consumerMessageRepository.SaveChangesAsync(cancellationToken);

    await HandleAsync(scope, notification, cancellationToken);
}
```

Each handler extends this base class:
```csharp
// ticketing-platform-sales/src/TP.Sales.Consumers/Consumers/Orders/OrderCompletedIntegrationEventHandler.cs
public class OrderCompletedIntegrationEventHandler(IServiceScopeFactory serviceScope)
    : IntegrationEventHandlerBase<OrderCompletedIntegrationEvent>(serviceScope)
{
    protected override async Task HandleAsync(
        IServiceScope scope,
        OrderCompletedIntegrationEvent @event,
        CancellationToken cancellationToken)
    {
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
        // business logic...
    }
}
```

---

## Event Subscription System

### SubscriptionsRegistry

`ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/SubscriptionsRegistry.cs`

Uses reflection to discover all classes in the assembly that implement `IEnumerable<ConsumerSubscription>`. Called at CDK synth time to generate EventBridge rules.

### ConsumersServices Enum

Lists every consumer service that has a dedicated SQS queue:
`Organization`, `Inventory`, `Pricing`, `Sales`, `Extensions`, `Integration`, `AccessControl`, `Media`, `Reporting`, `DistributionPortal`, `Transfer`, `Loyalty`, `PdfGenerator`, `CsvGenerator`, `Geidea`, `Catalogue`, `Marketplace`, `Customers`

### Subscription Files

One file per consumer service in:
`ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/Subscriptions/`

Example — `SalesSubscriptions.cs`:
```csharp
public class SalesSubscriptions : IEnumerable<ConsumerSubscription>
{
    private const ConsumersServices current = ConsumersServices.Sales;
    public IEnumerator<ConsumerSubscription> GetEnumerator()
    {
        yield return new ConsumerSubscription(current)
            .AddEvent(nameof(CreateOrderIntegrationEvent))
            .AddEvent<PaymentCapturedIntegrationEvent>()
            .AddEvent<OrderDeclinedIntegrationEvent>()
            .AddEventGeneric(typeof(CsvDataRequested<>));
            // ... 30+ events
    }
}
```

### Adding a New Event Subscription

To make a consumer receive a new event:
1. Define the event class in `ticketing-platform-tools/TP.Tools.MessageBroker/Entities/Events/{Domain}/`
2. Add `.AddEvent<MyNewEvent>()` to the relevant `*Subscriptions.cs` file in `ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/Subscriptions/`
3. Deploy `TP-ConsumerSubscriptionStack-{env}` via CDK
4. Implement `IntegrationEventHandlerBase<MyNewEvent>` in the consumer Lambda project

---

## Shared Infrastructure Stacks

`ticketing-platform-infrastructure/TP.Infrastructure.Cdk/Program.cs` deploys 11 CloudFormation stacks:

| Stack | Name Pattern | Purpose |
|---|---|---|
| EventBusStack | `TP-EventBusStack-{env}` | EventBridge bus `event-bus-{env}` |
| MonitoringStack | `TP-MonitoringStack-{env}` | CloudWatch log group, EventBridge monitoring rule, X-Ray Insights |
| ConsumersSqsStack | `TP-ConsumersSqsStack-{env}` | SQS queue + DLQ for every consumer service (18 total) |
| ConsumerSubscriptionStack | `TP-ConsumerSubscriptionStack-{env}` | EventBridge rules routing events to queues |
| ExtendedMessageS3BucketStack | `TP-ExtendedMessageS3BucketStack-{env}` | S3 for large message payloads |
| InternalHostedZoneStack | `TP-InternalHostedZoneStack-{env}` | Private Route53 zone |
| InternalCertificateStack | `TP-InternalCertificateStack-{env}` | ACM cert for internal services |
| SlackNotificationStack | `TP-SlackNotificationStack-{env}` | CloudWatch Logs to Slack Lambda |
| XRayInsightNotificationStack | `TP-XRayInsightNotificationStack-{env}` | X-Ray to Slack + DynamoDB dedup |
| ApiGatewayVpcEndpointStack | `TP-ApiGatewayVpcEndpointStack` | VPC endpoint for API Gateway |
| RdsProxyStack | `TP-RdsProxyStack` | RDS Proxy for Aurora PostgreSQL |

### SQS Queue Configuration

Most queues: 120s visibility timeout, 1 DLQ retry. Exceptions:

| Service | Timeout | DLQ Retries |
|---------|---------|-------------|
| PdfGenerator | 900s (15m) | 5 |
| CsvGenerator | 300s (5m) | 1 |
| Sales | 300s (5m) | 1 |

### Per-Service CDK Stacks

Each .NET service also has its own `TP.{Service}.Cdk/` project deploying:
- **ServerlessBackendStack** — Lambda function + API Gateway + VPC + CloudWatch
- **ConsumersStack** — Consumer Lambda + event source mapping from the SQS queue
- **BackgroundJobsStack** — AWS Scheduler rules + Lambda for background jobs
- **DbMigratorStack** — Lambda for EF Core database migrations

```csharp
// ticketing-platform-sales/src/TP.Sales.Cdk/Program.cs
new ConsumersStack(app, $"TP-{nameof(ConsumersStack)}-sales-{envName}", envName, stackProps, isXrayEnabled).Setup();
new BackgroundJobsStack(app, envName, stackProps, timeoutDurationInMinutes: 10, memorySize: 2048, enableTracing: isXrayEnabled)
    .Setup(BackgroundJobsAssembly.Assembly());
new ServerlessBackendStack(app, envName, stackProps, isXrayEnabled).Setup();
new DbMigratorStack(app, envName, stackProps, isXrayEnabled).Setup();
```

---

## API Gateway Architecture

**Service:** `ticketing-platform-gateway/`
**Technology:** .NET 8.0 + YARP (Yet Another Reverse Proxy) v2.3.0 + AWS Lambda

### Routing

Routes are defined as code in `ticketing-platform-gateway/src/Gateway/ReverseProxy/Routes/`:

```
Routes/
├── Sales/           OrderRoutes.cs, CustomerRoutes.cs, PaymentRoutes.cs, etc.
├── Catalogue/       ...
├── Inventory/       ...
├── Organizations/   ...
├── AccessControl/   ...
├── Pricing/         ...
├── Media/           ...
├── Reporting/       ...
├── Transfer/        ...
├── Extensions/      ...
├── Marketplace/     ...
├── Customers/       ...
└── DistributionPortal/ ...
```

Each route specifies a `ClusterId` (destination service) and an `AuthorizationPolicy`:

```csharp
// ticketing-platform-gateway/src/Gateway/ReverseProxy/Routes/Sales/OrderRoutes.cs
new RouteConfig
{
    RouteId = "Sales.Commands.CreateOrder",
    ClusterId = Clusters.SalesCluster,
    AuthorizationPolicy = OrderPolicies.CreateOrder.GetScope(),
    Match = new RouteMatch
    {
        Path = "/sales/{organization_id}/{branch_id}/orders",
        Methods = Utils.POST,
        Headers = Utils.ApiVersion3
    }
}
```

### Clusters

`ticketing-platform-gateway/src/Gateway/ReverseProxy/Clusters.cs`

Each cluster resolves its destination address from environment variables (via `TicketingPlatformClient.GetBaseAddress()`). 14 clusters: Organizations, Sales, Inventory, Catalogue, Integration, AccessControl, Pricing, Media, Extensions, Reporting, DistributionPortal, Transfer, Customers, Marketplace.

### Authorization

The gateway validates **Auth0 JWT tokens** and enforces policy-based authorization:
- `ticketing-platform-gateway/src/Gateway/Authorization/PermissionRequirementHandler.cs`
- Authorization policies are defined in `TP.Tools.SharedEntities.Contracts.Authorization.Policies` (shared NuGet)

### Additional Gateway Features

- Own endpoints: `ticketing-platform-gateway/src/Gateway/Features/` — Health checks, timezones, currencies
- Swagger aggregation: `ticketing-platform-gateway/src/Gateway/Controllers/SwaggerController.cs`
- Request transforms: `ticketing-platform-gateway/src/Gateway/ReverseProxy/Transforms/`

---

## Service-to-Service Communication

Services call each other via **HTTP** using `TicketingPlatformClient` from `TP.Tools.Helpers/HttpClient/`. Base addresses are resolved from SSM Parameter Store (`/{env}/tp/InternalServices`).

Example: Services that `ticketing-platform-sales` calls synchronously:
- **Inventory** (`IInventoryService`) — cart details, inventory booking
- **Pricing** (`IPricingService`) — cart price calculation
- **Catalogue** (`ICatalogueService`) — ticket lookup
- **Organizations** — org/branch validation
- **Payment** (`IPaymentService`) — Checkout.com / Tabby payment links
- **Marketplace** (`IMarketplaceService`) — marketplace transactions

These interfaces are defined in the Domain layer (e.g., `ticketing-platform-sales/src/TP.Sales.Domain/Interfaces/ICatalogueService.cs`) and implemented in the Infrastructure layer.

---

## Data Storage

### Per-Service Databases (Isolated)

Each .NET service owns its own **PostgreSQL** database (Aurora). Services **do not share databases**. Cross-service data sharing happens through:
1. **Events** (eventual consistency via EventBridge to SQS)
2. **HTTP calls** (synchronous, via `TicketingPlatformClient`)

### EF Core Configuration

- **Base class:** `PgSqlDbClient` from `TP.Tools.DataAccessLayer`
- **Auto-configuration:** `DbAutoConfigureHelper.AutoConfigureDbs()` registers DbContexts based on connection strings
- **Entity configurations:** Fluent API via `IEntityTypeConfiguration<T>` in `Configurations/` directory

### Three DbContexts Per Service

```csharp
// ticketing-platform-sales/src/TP.Sales.Infrastructure/DataContexts/PgSqlDataContext.cs
public class PgSqlDataContext : PgSqlDbClient
{
    public DbSet<Order> Orders { get; set; }
    public DbSet<Customer> Customers { get; set; }
    public DbSet<LineItem> LineItems { get; set; }
    // ... 15+ DbSets

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfiguration(new OrderEntityTypeConfiguration());
        modelBuilder.ApplyConfiguration(new LineItemEntityTypeConfiguration());
        // ...
    }
}
```

- `PgSqlDataContext` — primary read/write
- `ReadonlyPgSqlDataContext` — read replica
- `ReportingPgSqlDataContext` — reporting queries

### UnitOfWork Pattern

```csharp
// ticketing-platform-sales/src/TP.Sales.Infrastructure/Repositories/UnitOfWork.cs
public class UnitOfWork : IUnitOfWork
{
    private readonly PgSqlDataContext _pgSqlDataContext;
    private readonly IResilienceRetryService _resilienceRetryService;

    public DbSet<Order> Orders => _pgSqlDataContext.Orders;
    public DbSet<Customer> Customers => _pgSqlDataContext.Customers;
    // ...

    public async Task<bool> SaveChangesAsync(string correlationId, CancellationToken ct)
    {
        return await _resilienceRetryService.ExecuteAsync(
            (ct) => _pgSqlDataContext.SaveChangesAsync(ct),
            correlationId: correlationId,
            cancellationToken: ct) > 0;
    }
}
```

Handles PostgreSQL-specific exceptions (unique constraint, foreign key violations) and consumed message deduplication.

### Cross-Service Denormalization

Services maintain **local denormalized copies** of data from other services, updated via events. Example: Sales service keeps local `CatalogueEvent`, `Organization`, `Branch` entities updated by consuming `CatalogueEventBasicInfoChangedIntegrationEvent`, `OrganizationCreatedIntegrationEvent`, `BranchCreatedIntegrationEvent`.

### Domain Entities

Aggregate roots extend `VersioningDomainAggregateEntity` and implement `IAggregateRoot`:

```csharp
// ticketing-platform-sales/src/TP.Sales.Domain/Aggregates/OrderAggregate/Order.cs
public class Order : VersioningDomainAggregateEntity, IAggregateRoot
{
    public Guid OrganizationId { get; protected set; }
    public Guid EventId { get; protected set; }
    public Guid BranchId { get; protected set; }
    public OrderState State { get; protected set; }
    public Money TotalPrice { get; protected set; }
    public virtual Customer Customer { get; protected set; }
    public virtual ICollection<LineItem> Items { get; protected set; }
    // ... rich domain behavior methods
}
```

---

## TP.Tools.* NuGet Libraries

All .NET services consume packages from `ticketing-platform-tools/`, published to `nuget.pkg.github.com/mdlbeasts`.

| Package | Location | Purpose |
|---|---|---|
| `TP.Tools.SharedEntities` | `TP.Tools.SharedEntities/` | Domain entities, contracts, enums, DTOs (Money, LocalizedString, PagedList, authorization policies) |
| `TP.Tools.DataAccessLayer` | `TP.Tools.DataAccessLayer/` | EF Core + Dapper, PostgreSQL clients, `PgSqlDbClient` base, `DbAutoConfigureHelper` |
| `TP.Tools.Helpers` | `TP.Tools.Helpers/` | Email (SendGrid), caching (DynamoDB/Redis/memory), health checks, MediatR caching pipeline, resilience (Polly) |
| `TP.Tools.Logger` | `TP.Tools.Logger/` | Serilog structured logging, `CorrelationIdMiddleware`, custom enrichers, `LogOperationalError`/`LogSuspiciousOrderError` |
| `TP.Tools.MessageBroker` | `TP.Tools.MessageBroker/` | EventBridge/SQS publish & consume, `IntegrationEvent` base, all event type definitions, `IntegrationEventHandlerBase` |
| `TP.Tools.Infrastructure` | `TP.Tools.Infrastructure/` | CDK constructs, `SecretManagerHelper`, `ParameterStoreHelper`, Lambda utilities |
| `TP.Tools.BackgroundJobs` | `TP.Tools.BackgroundJobs/` | CDK Scheduler constructs, `BackgroundJobsUtilities`, `InvocableServerlessBackgroundJobBase` |
| `TP.Tools.Validator` | `TP.Tools.Validator/` | FluentValidation MediatR pipeline behavior |
| `TP.Tools.RestVersioning` | `TP.Tools.RestVersioning/` | API versioning via `x-api-version` header |
| `TP.Tools.Swagger` | `TP.Tools.Swagger/` | OpenAPI setup helpers |
| `TP.Tools.PhoneNumbers` | `TP.Tools.PhoneNumbers/` | Phone number parsing and validation |
| `TP.Tools.Resilience` | `TP.Tools.Resilience/` | Polly-based retry and circuit breaker policies |

**Dependency tree:**
```
TP.Tools.Libs.Entities (base)
    ├── TP.Tools.SharedEntities
    ├── TP.Tools.Logger
    │       └── TP.Tools.Helpers
    └── TP.Tools.Infrastructure
            └── TP.Tools.BackgroundJobs

TP.Tools.SharedEntities
    ├── TP.Tools.DataAccessLayer
    └── TP.Tools.MessageBroker
```

---

## Dashboard Architecture

**Service:** `ticketing-platform-dashboard/`
**Stack:** Next.js 15, React 18, Material UI v5, styled-components, @tanstack/react-query, TypeScript strict

### Source Structure

```
ticketing-platform-dashboard/
├── src/
│   ├── pages/           # Next.js file-based routing (Pages Router)
│   │   ├── [organizationId]/
│   │   │   ├── events/        # Catalogue events management
│   │   │   ├── sales/         # Orders, customers, refunds
│   │   │   ├── access-control/ # Scanners, gates, scannables
│   │   │   ├── access-management/ # Users, roles, permissions
│   │   │   ├── reporting/     # Charts and reports
│   │   │   ├── reservations/  # Cart inventories
│   │   │   └── extension-flows/ # Extension management
│   │   ├── api/             # API routes
│   │   └── login/           # Login flow
│   ├── components/       # React components (domain + common)
│   ├── hooks/            # Custom React hooks
│   ├── services/api/     # HTTP client wrappers
│   │   ├── ticketingClient.ts  # Fetch wrapper for backend API
│   │   └── mediaClient.ts     # Fetch wrapper for media API
│   ├── queries/TicketingPlatform/  # React Query hooks (35+ domain directories)
│   ├── types/            # TypeScript type definitions
│   ├── utils/            # Utility functions
│   ├── theme/            # MUI theme configuration
│   ├── constants/        # App-wide constants
│   ├── hue/              # Design system (separate linting: npm run lint:hue)
│   │   ├── components/
│   │   ├── layout/
│   │   ├── styles/
│   │   └── utils/
│   ├── assets/           # Icons (SVGs auto-generated via @svgr/cli)
│   └── openapi/          # Generated TypeScript types from Orval
│       └── ticketing-platform/
```

### Path Aliases (tsconfig.json)

`@assets/*`, `@components/*`, `@hooks/*`, `@pages/*`, `@services/*`, `@theme/*`, `@utils/*`, `@hue/*`, `@queries/*`

### API Proxying

`ticketing-platform-dashboard/next.config.js` configures Next.js rewrites:

```javascript
async rewrites() {
    return [
        { source: "/tp/:path*", destination: `${process.env.TP_HOST}/:path*` },     // → API Gateway
        { source: "/api/media/:path*", destination: `${process.env.MEDIA_HOST}/media/:path*` },  // → Media service
    ];
}
```

The `ticketingClient.ts` prepends `/tp` to all API paths:
```typescript
const url = path.startsWith("/") ? `/tp${path}` : `/tp/${path}`;
```

### Authentication

Auth0 via `@auth0/auth0-react`. Bearer token is attached to all API requests.

### API Type Generation

`npm run generate-api` uses **Orval** (`orval.config.ts`) to generate TypeScript types and React Query hooks from OpenAPI specs. Output goes to `src/openapi/ticketing-platform/`.

### React Query Hooks

`src/queries/TicketingPlatform/` contains 35+ domain directories with query/mutation hooks:
`orders`, `events`, `tickets`, `customers`, `branches`, `channels`, `permissions`, `roles`, `users`, `pricing`, `inventory-cart`, `extensions`, `transfers`, `reporting`, `seating-plans`, etc.

### Error Tracking

Sentry via `@sentry/nextjs`:
- `ticketing-platform-dashboard/sentry.client.config.ts`
- `ticketing-platform-dashboard/sentry.server.config.ts`
- `ticketing-platform-dashboard/sentry.edge.config.ts`

---

## Mobile Scanner Architecture

**Service:** `ticketing-platform-mobile-scanner/`
**Stack:** Expo 52 (React Native), Android only, EAS Build

### Source Structure

```
ticketing-platform-mobile-scanner/src/
├── app/           # App screens (Expo Router)
├── components/    # Reusable UI components
├── hooks/         # Custom React hooks
├── queries/       # API query hooks
├── data/          # Local data management
├── types/         # TypeScript types
├── utils/         # Utilities
├── constants/     # App constants
└── styles/        # Style definitions
```

### Key Capabilities

- QR code scanning via camera
- RFID scanning (hardware integration)
- Honeywell handheld scanner integration
- **Offline mode**: downloads scannables, queues scan operations locally, syncs when connected

### Shared Native Libraries

`ticketing-platform-mobile-libraries/` is a Yarn workspaces monorepo (Yarn 3.8.0):
- `packages/acs-smc-sdk/` — Access control scanner SDK
- `packages/expo-serial-usb/` — Expo module for USB serial communication

---

## Extension System

Four services implement the extension system for custom business logic:

1. **Extension API** (`ticketing-platform-extension-api/`) — Clean Architecture service managing extensions, code, flows, and executions. Features: `ExtensionCode/`, `ExtensionExecution/`, `Extensions/`, `Flow/`, `Lookups/`

2. **Extension Executor** (`ticketing-platform-extension-executor/`) — Lambda triggered by SQS queue:
   ```csharp
   // TP.Extensions.Executor.Lambda/Functions.cs
   var @event = JsonConvert.DeserializeObject<ExtensionExecuteEvent>(message.Body);
   await _executorService.Execute(@event, default);
   ```
   The `ExecutorService` validates the event, invokes extension Lambda functions, handles on-failure extensions, reports results back to Extension API, and sends logs for collection.

3. **Extension Deployer** (`ticketing-platform-extension-deployer/`) — Deploys extension code as isolated Lambda functions

4. **Extension Log Processor** (`ticketing-platform-extension-log-processor/`) — Collects and processes extension execution logs

### Extension Execution Flow

```
Platform Event (e.g., OrderCreatedIntegrationEvent)
  → Extension API (consumer) matches event to registered flows
  → Publishes ExtensionExecuteEvent to executor SQS queue
  → Extension Executor Lambda
    → Validates event
    → Invokes extension's isolated Lambda function
    → On failure: optionally invokes on-failure extension Lambda
    → Reports execution results back to Extension API
    → Sends logs to Log Processor
```

---

## Data Flow: Typical Order Creation

```
1. Dashboard (browser)
   POST /tp/sales/{org_id}/{branch_id}/orders  [x-api-version: 3]
   Bearer token with org/channel claims

2. ticketing-platform-gateway (Lambda)
   → Validates JWT (Auth0)
   → Checks OrderPolicies.CreateOrder authorization
   → Proxies to SalesCluster

3. ticketing-platform-sales API Lambda
   → LambdaEntry → ASP.NET Core → OrdersController → MediatR → CreateOrderHandler
   → Calls Inventory service: GetCartDetails (HTTP)
   → Calls Pricing service: CalculateCartPrices (HTTP)
   → Calls Catalogue service: SearchTicketsByIdV4 (HTTP)
   → Creates Order aggregate (domain logic)
   → Saves to PostgreSQL via UnitOfWork
   → Calls Inventory service: BookInventory (HTTP)
   → Calls Payment service: RequestPaymentLink (Checkout.com / TabbyPay)
   → Saves order state update
   → Publishes OrderCreatedIntegrationEvent → EventBridge
   → Publishes OrderPaymentSucceededIntegrationEvent (if applicable)

4. EventBridge (event-bus-{env})
   → Routes to all subscribed consumers' SQS queues

5. Each consumer Lambda processes independently:
   → access-control-consumers: generate scannables
   → pdf-generator-consumers: generate PDF tickets
   → integration-consumers: notify third-party systems
   → loyalty-consumers: award loyalty points
   → reporting-consumers: update sales data
   → etc.
```

---

## Cross-Cutting Concerns

### Logging

- **Framework:** Serilog (structured logging) via `TP.Tools.Logger`
- **Middleware:** `CorrelationIdMiddleware` — extracts or generates correlation ID per request
- **Special categories:** `LogOperationalError`, `LogSuspiciousOrderError` — route to specific Slack channels

### Error Handling

- **API layer:** `ExceptionMiddleware` catches and maps exceptions to structured responses
- **Domain:** `TicketingPlatformException` (HTTP status + error code + message)
- **Consumers:** `IntegrationException` with types: `DLQ` (dead letter queue), `Forgiving` (log and skip)

### API Versioning

Header-based via `x-api-version`. Current versions: v1 (deprecated), v3, v4. Gateway routes include version matching in `Headers = Utils.ApiVersion3`.

### Resilience

`TP.Tools.Resilience` — Polly-based retry and circuit breaker. UnitOfWork wraps `SaveChangesAsync` with resilience retry. Inter-service HTTP clients also use resilience policies.

---

## Secrets and Configuration

### Lambda Cold Start Secret Loading

```csharp
AsyncHelper.RunSync(() => SecretManagerHelper.LoadSecretsToEnvironmentAsync($"/{env}/sales"));
AsyncHelper.RunSync(() => ParameterStoreHelper.LoadParametersToEnvironmentAsync($"/{env}/tp/InternalServices"));
```

- **Secrets Manager**: `/{env}/{service}` — database passwords, API keys
- **SSM Parameter Store**: `/{env}/tp/InternalServices` — service URLs for inter-service HTTP calls

### Environments

| Environment | Branch | Secrets Path |
|-------------|--------|-------------|
| dev | `development` | `/dev/{service}` |
| sandbox | `sandbox` | `/sandbox/{service}` |
| demo | `demo` | `/demo/{service}` |
| prod | `master` | `/prod/{service}` |

### Kubernetes ConfigMaps

Non-sensitive config injected via ConfigMaps from `ticketing-platform-configmap-{env}/manifests/`.

---

## CI/CD Pattern

Each service has GitHub Actions workflows in `.github/workflows/`:

- **`ci-cd.yml`** — builds, tests, and deploys on branch push (`development`, `sandbox`, `demo`, `master`)
- **`tests.yml`** — runs tests on PRs
- **`nuget.yml`** (tools repo only) — publishes NuGet packages

Deployment for .NET Lambda services:
1. `dotnet test` — run all tests
2. `dotnet lambda package` — package Lambda zip
3. `cdk deploy TP-{StackName}-{env} --require-approval never` — deploy via CDK

---

## Key Architectural Patterns Summary

1. **Clean Architecture**: API → Domain → Infrastructure, with no upward dependencies
2. **CQRS via MediatR**: All operations are Commands or Queries dispatched via `IMediator`
3. **Vertical slices**: Features are self-contained directories with Command/Query/Handler/Validator
4. **Event-driven eventual consistency**: Services publish to EventBridge; consumers react asynchronously
5. **Idempotent consumers**: `IntegrationEventHandlerBase` deduplicates re-delivered messages via `consumed_messages` table
6. **Isolated databases**: No shared databases; cross-service data via events or HTTP
7. **Local denormalization**: Services maintain cached copies of foreign data updated via events
8. **Infrastructure as code**: Every service's infra is in its own CDK project; shared infra in `ticketing-platform-infrastructure`
9. **Secrets at cold start**: Lambdas load secrets from Secrets Manager and SSM synchronously on first invocation
10. **Three DbContexts**: Write, read-only, and reporting contexts per service
