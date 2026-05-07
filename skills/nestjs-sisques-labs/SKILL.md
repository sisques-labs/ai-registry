---
name: nestjs-sisques-labs
description: >
  NestJS project conventions for sisques-labs — DDD, CQRS, Hexagonal Architecture
  with GraphQL (Apollo Federation), MongoDB, Kafka, and pnpm workspaces.
  Trigger: When creating, writing, reviewing, or refactoring NestJS code in a sisques-labs project.
license: Apache-2.0
metadata:
  author: sisques-labs
  version: "1.0"
---

## When to Use

- Creating a new NestJS feature module (bounded context)
- Writing aggregates, value objects, or domain events
- Implementing CQRS command/query handlers
- Building GraphQL resolvers or REST controllers
- Configuring infrastructure (MongoDB, Kafka, Docker)
- Reviewing code for architecture compliance

## Critical Patterns

### 1. Project Structure

```
src/
├── main.ts                        # Bootstrap: ValidationPipe, Kafka, Winston
├── app.module.ts                  # Root module: FEATURES + SUPPORT constants
├── app.controller.ts              # REST health/root endpoint
├── app.service.ts
├── schema.gql                     # Auto-generated GraphQL schema
├── <feature>/                     # e.g. core, health, kafka
│   ├── <feature>.module.ts
│   └── <bounded-context>/         # e.g. prompt-context
│       ├── <bounded-context>.module.ts
│       ├── application/
│       │   ├── commands/<entity>/
│       │   │   ├── <action>-<entity>.command.ts
│       │   │   ├── <action>-<entity>.command-handler.ts
│       │   │   └── <action>-<entity>.command-handler.spec.ts
│       │   ├── queries/<entity>/
│       │   │   ├── <action>-<entity>.query.ts
│       │   │   ├── <action>-<entity>.query-handler.ts
│       │   │   └── <action>-<entity>.query-handler.spec.ts
│       │   ├── services/<entity>/
│       │   ├── dtos/commands/<entity>/
│       │   └── dtos/queries/<entity>/
│       ├── domain/
│       │   ├── aggregates/<entity>/
│       │   │   ├── <entity>.aggregate.ts
│       │   │   └── <entity>.aggregate.spec.ts
│       │   ├── value-objects/<entity>/
│       │   │   └── <field>/
│       │   │       ├── <field>.vo.ts
│       │   │       └── <field>.vo.spec.ts
│       │   ├── events/<entity>/
│       │   │   ├── <entity>-created/
│       │   │   ├── <entity>-updated/
│       │   │   ├── <entity>-deleted/
│       │   │   └── field-changed/
│       │   ├── repositories/<entity>/
│       │   │   ├── <entity>-read/
│       │   │   └── <entity>-write/
│       │   ├── builders/<entity>/
│       │   ├── primitives/<entity>/
│       │   ├── view-models/<entity>/
│       │   └── dtos/entities/<entity>/
│       ├── infrastructure/
│       │   └── database/
│       │       └── mongodb/
│       │           ├── mappers/<entity>/
│       │           └── repositories/<entity>/
│       └── transport/
│           ├── graphql/
│           │   ├── resolvers/<entity>/
│           │   ├── mappers/<entity>/
│           │   └── dtos/<entity>/
│           └── rest/
│               ├── controllers/<entity>/
│               ├── mappers/<entity>/
│               └── dtos/<entity>/
└── support/                        # Cross-cutting (logging, config)
    ├── support.module.ts
    └── <concern>/
```

### 2. Module Composition

```typescript
// app.module.ts — organize by role
const FEATURES = [CoreModule];
const SUPPORT = [SupportModule];

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    GraphQLModule.forRoot<ApolloDriverConfig>({ driver: ApolloDriver, autoSchemaFile: join(process.cwd(), 'src/schema.gql'), sortSchema: true }),
    HealthModule,
    KafkaModule,
    ...FEATURES,
    ...SUPPORT,
  ],
})
```

```typescript
// <bounded-context>.module.ts — group by layer
const RESOLVERS = [...];
const APPLICATION_SERVICES = [...];
const QUERY_HANDLERS = [...];
const COMMAND_HANDLERS = [...];
const BUILDERS = [...];
const MAPPERS = [...];
const REPOSITORIES = [{ provide: TOKEN, useClass: Impl }];

@Module({
  imports: [CqrsModule, MongoModule],
  controllers: [...],
  providers: [...RESOLVERS, ...APPLICATION_SERVICES, ...QUERY_HANDLERS, ...COMMAND_HANDLERS, ...REPOSITORIES, ...BUILDERS, ...MAPPERS],
})
```

### 3. CQRS — Command Handler Pattern

```typescript
@CommandHandler(CreateEntityCommand)
export class CreateEntityCommandHandler extends BaseCommandHandler<CreateEntityCommand, EntityAggregate> implements ICommandHandler<CreateEntityCommand> {
  constructor(
    @Inject(WRITE_REPOSITORY_TOKEN) private readonly repo: IWriteRepository,
    private readonly builder: EntityAggregateBuilder,
    private readonly validationService: AssertSomethingService,
    eventBus: EventBus,
  ) { super(eventBus); }

  async execute(command: CreateEntityCommand): Promise<string> {
    // 1. Validate business rules (use application services)
    // 2. Build aggregate via builder pattern
    // 3. repo.save(aggregate)
    // 4. this.publishEvents(aggregate)
    // 5. Return aggregate.id.value
  }
}
```

### 4. Aggregate Pattern

```typescript
export class EntityAggregate extends BaseAggregate {
  private readonly _id: EntityId;
  private _name: EntityName;

  constructor(props: IEntity) {
    super(props.createdAt, props.updatedAt);
    this._id = props.id;
    this._name = props.name;
    this.apply(new EntityCreatedEvent(metadata, { ...this.toPrimitives() }));
  }

  get id(): EntityId { return this._id; }

  public changeName(name: EntityName): void {
    const old = this._name.value;
    this._name = name;
    this.apply(new EntityNameChangedEvent(metadata, { id: this._id.value, oldValue: old, newValue: name.value }));
  }

  public toPrimitives(): EntityPrimitives { return { id: this._id.value, name: this._name.value, ... }; }
}
```

### 5. Value Objects

```typescript
export class EntityId extends UuidValueObject {}
export class EntityName extends StringValueObject {
  constructor(value: string) { super(value); /* validate */ }
}
```

Each value object in its own directory: `<field>/<field>.vo.ts`, extends a base from `@sisques-labs/nestjs-kit`.

### 6. Separate Read/Write Repositories

```typescript
// domain/repositories/<entity>-write/<entity>-write.repository.ts
export const WRITE_REPOSITORY_TOKEN = 'WRITE_REPOSITORY_TOKEN';
export interface IWriteRepository {
  save(aggregate: EntityAggregate): Promise<void>;
  findById(id: string): Promise<EntityAggregate | null>;
  delete(id: string): Promise<void>;
}
```

```typescript
// domain/repositories/<entity>-read/<entity>-read.repository.ts
export const READ_REPOSITORY_TOKEN = 'READ_REPOSITORY_TOKEN';
export interface IReadRepository {
  findById(id: string): Promise<EntityViewModel | null>;
  findByCriteria(criteria: Criteria): Promise<PaginatedResult<EntityViewModel>>;
}
```

### 7. Domain Events

- Events in `domain/events/<entity>/<event-name>/<event-name>.event.ts`
- Use metadata interface from `@sisques-labs/nestjs-kit`: `{ aggregateRootId, aggregateRootType, entityId, entityType, eventType }`
- Field-level events for aggregates (e.g. `EntityNameChangedEvent`)
- Publish via aggregate's `apply()` method, then `BaseCommandHandler.publishEvents()`

### 8. Transport Layer

**REST:**
```typescript
@Controller('entities')
export class EntityMutationsController {
  constructor(private readonly commandBus: CommandBus, private readonly queryBus: QueryBus, private readonly mapper: EntityRestMapper) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateEntityDto): Promise<{ id: string }> {
    const id = await this.commandBus.execute(new CreateEntityCommand(dto));
    return { id };
  }
}
```

**GraphQL:**
```typescript
@Resolver()
export class EntityQueriesResolver {
  @Query(() => EntityType, { name: 'entity' })
  async getEntity(@Args('id') id: string): Promise<EntityType> {
    return this.queryBus.execute(new FindEntityByIdQuery({ id }));
  }
}
```

### 9. Infrastructure — MongoDB

- Mappers convert domain ↔ persistence: `domainToPersistence(entity: EntityAggregate): EntityDocument` and `persistenceToDomain(document: EntityDocument): EntityAggregate`
- Repositories implement domain repository interfaces
- Register in module: `{ provide: TOKEN, useClass: Impl }`

### 10. Validation & Config

```typescript
// main.ts
app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER));
```

### 11. Kafka Integration

- `@nestjs/microservices` with `Transport.KAFKA`
- Schema Registry via `@sisques-labs/nestjs-kit` → `SchemaRegistryModule.forRootAsync()`
- Kafka producer service + event publisher in `kafka/` module

### 12. Docker Build

```dockerfile
# Multi-stage with pnpm
FROM node:20-alpine AS builder
RUN corepack enable && corepack prepare pnpm@latest --activate
# Install with NODE_AUTH_TOKEN secret for @sisques-labs private packages
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=secret,id=node_auth_token pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:20-alpine AS production
# Install only prod deps, copy dist from builder
```

### 13. TypeScript Config

```json
{
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] },
    "baseUrl": "./"
  }
}
```

## Conventions

- **File naming**: kebab-case — `create-prompt.command.ts`, `prompt-id.vo.ts`, `prompt-mutations.controller.ts`
- **Suffixes**: `.command.ts`, `.command-handler.ts`, `.query.ts`, `.query-handler.ts`, `.vo.ts`, `.aggregate.ts`, `.event.ts`, `.repository.ts`, `.mapper.ts`, `.dto.ts`
- **Spec files**: co-located next to source: `create-prompt.command-handler.spec.ts`
- **Path aliases**: Always use `@/` instead of relative `../../` imports
- **Module constant groups**: `RESOLVERS`, `COMMAND_HANDLERS`, `QUERY_HANDLERS`, `APPLICATION_SERVICES`, `BUILDERS`, `MAPPERS`, `REPOSITORIES` at top of module file
- **Logger**: Always `private readonly logger = new Logger(ClassName.name)`

## Commands

```bash
pnpm build              # Build with tsc-alias
pnpm dev                # Watch mode
pnpm test               # Jest unit tests
pnpm test:e2e           # E2E tests
pnpm lint               # ESLint + Prettier
pnpm format             # Prettier
```

## Resources

- **@sisques-labs/nestjs-kit**: Base classes for aggregates, value objects, command handlers, MongoDB module
- **Templates**: See [assets/](assets/) for scaffolding templates
