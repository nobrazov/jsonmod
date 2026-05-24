# Use Cases / Варианты использования / 使用场景

> Практический справочник интеграции `jsonmod` в production-пайплайны.  
> Формат: `RU | EN | ZH`. Запуск: `cat template.jsonmod | ./jsonmod | jq -C .`  
> Принцип: детерминизм, строгая валидация, нулевое кэширование. Без состояния.

---

## 🧩 Microservices & Development / Микросервисы и разработка / 微服务与开发

### `microservice-config-assembly`
**Проблема / Problem / 痛点**  
RU: Конфигурация микросервисов размазана по разным системам: базовые параметры в репозитории, секреты в Vault/KMS, переменные окружения задаёт оркестратор. Сборка итогового `config.json` обычно требует bash/python-скриптов, которые ломаются при изменении структуры, не валидируют типы и пропускают ошибки до рантайма (`config parse error` в логах после деплоя).  
EN: Microservice configs are fragmented across repos, Vault/KMS, and orchestrator env vars. Assembly typically relies on fragile bash/python scripts that break on structure changes, skip type validation, and fail at runtime.  
ZH: 微服务配置分散在仓库、Vault/KMS 和编排器环境变量中。组装通常依赖脆弱的 bash/python 脚本，结构变更易崩溃，跳过类型验证，并在运行时失败。

**Решение / Solution / 解决方案**  
RU: `jsonmod` детерминировано собирает конфигурацию из независимых слоёв строго до старта процесса. Шаблон `.jsonmod` описывает *что* нужно, а не *как* склеивать. Ошибки типа и отсутствующих ключей ловятся на этапе CI, а не в production.  
EN: `jsonmod` deterministically assembles configs from independent layers strictly before process startup. The `.jsonmod` template declares *what* is needed, not *how* to glue it. Type/missing-key errors fail in CI, not production.  
ZH: `jsonmod` 在进程启动前严格从独立层确定性组装配置。`.jsonmod` 模板声明 *需要什么*，而非 *如何拼接*。类型/缺失键错误在 CI 阶段拦截，而非生产环境。

**Сценарии / Scenarios / 应用场景**
```jsonmod
ENV = "production"
DB_HOST = "db.internal"
{
  "app": @%{"base"} "file://configs/base.json",
  "env_vars": @%{"prod"} "file://configs/${ENV}.json",
  "secrets": @%{"vault"} "file://configs/secrets.jsonmo",
  "routes": @@{0..1} "file://configs/routes.json"
}
```
- `@%` подтягивает объекты строго по ключу. Нет ключа → пайплайн падает до старта.
- `${ENV}` в URI резолвится до загрузки донора, переключение окружений без правки шаблона.
- `@@{0..1}` берёт срез массива, отсекая `/debug` в проде.
- `.jsonmo` включает рекурсивную подстановку `${DB_HOST}` внутри донора.

---

### `mock-api-generation`
**Проблема / Problem / 痛点**  
RU: Хранение мок-ответов в виде полных JSON-файлов дублирует структуру, занимает место в VCS и усложняет поддержку тестовых фикстур. Плоские списки пар `[k,v]` неудобно конвертировать вручную перед каждым тестовым прогоном.  
EN: Storing mock responses as full JSON files duplicates structure, bloats VCS, and complicates fixture maintenance. Manual conversion of `[k,v]` lists before test runs is error-prone.  
ZH: 以完整 JSON 文件存储模拟响应会重复结构、膨胀版本库并使夹具维护复杂。测试前手动转换 `[k,v]` 列表易出错。

**Решение / Solution / 解决方案**  
RU: Директива `@$` автоматически преобразует плоский массив чётной длины в валидный объект с сохранением типов. Тестовые данные хранятся компактно, конвертация происходит на лету без сторонних парсеров.  
EN: `@$` auto-converts even-length flat arrays into valid objects with preserved types. Test data stays compact, conversion happens on-the-fly without external parsers.  
ZH: `@$` 自动将偶数长度扁平数组转换为保留类型的有效对象。测试数据保持紧凑，无需外部解析器即可实时转换。

**Сценарии / Scenarios / 应用场景**
```jsonmod
{
  "user_profile": @$ "file://mocks/user_flat.json",
  "metadata": @%{"status"} "file://mocks/status.json"
}
```
Донор (`user_flat.json`): `["id", 42, "name", "Alice", "active", true, "roles", ["admin", "editor"]]`  
Результат: `{"user_profile": {"id":42, "name":"Alice", "active":true, "roles":["admin","editor"]}}`

---

## ☁️ Platform & Infrastructure / Платформа и инфраструктура / 平台与基础设施

### `k8s-manifest-assembly`
**Проблема / Problem / 痛点**  
RU: YAML-манифесты Kubernetes подвержены ошибкам отступов, дублируют спецификации контейнеров для разных окружений, а секреты/переменные внедряются через ненадёжные `sed`/`envsubst` или тяжёлые операторы.  
EN: K8s YAML manifests suffer from indentation errors, duplicate container specs across envs, and rely on fragile `sed`/`envsubst` or heavy operators for secret/env injection.  
ZH: K8s YAML 清单易受缩进错误影响，跨环境容器规格重复，依赖脆弱的 `sed`/`envsubst` 或重型算子注入密钥/变量。

**Решение / Solution / 解决方案**  
RU: Генерация валидного JSON-манифеста напрямую из шаблона. `@$` превращает плоские метки в объекты, `@%` переиспользует спецификации контейнеров, `${VAR}` управляет namespace/репликами. Валидация схемы происходит до `kubectl apply`.  
EN: Direct valid JSON manifest generation from templates. `@$` converts flat labels to objects, `@%` reuses container specs, `${VAR}` controls namespace/replicas. Schema validation occurs before `kubectl apply`.  
ZH: 直接从模板生成有效 JSON 清单。`@$` 将扁平标签转为对象，`@%` 复用容器规格，`${VAR}` 控制命名空间/副本数。在 `kubectl apply` 前完成模式验证。

**Сценарии / Scenarios / 应用场景**
```jsonmod
NAMESPACE = "production"
APP = "payment-api"
REPLICAS = 3
{
  "apiVersion": "apps/v1", "kind": "Deployment",
  "metadata": {"name": "${APP}", "namespace": "${NAMESPACE}", "labels": @$ "file://k8s/${APP}_labels.json"},
  "spec": {"replicas": ${REPLICAS}, "selector": {"matchLabels": {"app": "${APP}"}},
    "template": {"spec": {"containers": [ @%{"main"} "file://k8s/containers.json" ]}}}
}
```
- `kubectl apply -f -` принимает JSON нативно. Ошибка отступов исключена.
- Если `containers.json` содержит массив `[{"main":...}]`, срабатывает автоматический Unwrap.

---

### `dynamic-upstream-glob`
**Проблема / Problem / 痛点**  
RU: При масштабировании backend-пулов конфигурация прокси требует ручного обновления списков серверов или сложных dynamic-discovery механизмов, которые добавляют задержку и точки отказа.  
EN: Backend pool scaling requires manual proxy config updates or complex dynamic discovery, adding latency and failure points.  
ZH: 后端池扩容需手动更新代理配置或复杂的动态发现机制，增加延迟和故障点。

**Решение / Solution / 解决方案**  
RU: `@@` с glob-маской `file://region_*.json` собирает все совпадения директории в один массив. Добавление сервера = `git add new_backend.json`. Порядок определяется ФС, что допустимо для stateless-балансировки.  
EN: `@@` with glob `file://region_*.json` aggregates all directory matches into one array. Adding a server = `git add`. FS order is acceptable for stateless balancing.  
ZH: `@@` 配合 glob `file://region_*.json` 将目录所有匹配项聚合为单一数组。添加服务器 = `git add`。文件系统顺序适用于无状态负载均衡。

**Сценарии / Scenarios / 应用场景**
```jsonmod
REGION = "eu-west"
{"pool_name": "app_${REGION}", "servers": @@ "file://backends/${REGION}_*.json"}
```
- Пустая директория → `ERR_EMPTY_DONOR`. Пайплайн блокирует деплой до появления файлов.

---

### `singleton-unwrap`
**Проблема / Problem / 痛点**  
RU: Внешние API и системы конфигурации часто отдают данные в виде массива из одного объекта `[{}]`. Для доступа к полям требуются лишние селекторы или ручная распаковка.  
EN: External APIs/config systems often return data as single-element arrays `[{}]`, requiring extra selectors or manual unwrapping.  
ZH: 外部 API/配置系统常以单元素数组 `[{}]` 返回数据，需要额外选择器或手动解包。

**Решение / Solution / 解决方案**  
RU: `@%` автоматически разворачивает `[{}]` → `{}` до проверки типа. Селекторы работают сразу с вложенными полями, без лишних скобок и промежуточных шагов.  
EN: `@%` auto-unwraps `[{}]` → `{}` before type-checking. Selectors work directly on nested fields, eliminating extra braces and intermediate steps.  
ZH: `@%` 在类型检查前自动解包 `[{}]` → `{}`。选择器直接作用于嵌套字段，消除多余括号和中间步骤。

**Сценарии / Scenarios / 应用场景**
```jsonmod
{"cluster": @%{"region"} "file://data/cluster_info.json"}
```
Донор: `[{"region": "eu-west-2", "az": "a"}]` → Вывод: `{"cluster": {"region": "eu-west-2"}}`

---

## 🗄️ Data & Migrations / Данные и миграции / 数据与迁移

### `db-migration-aggregation`
**Проблема / Problem / 痛点**  
RU: Планы миграций состоят из разрозненных SQL-патчей, файлов схемы и seed-данных. Сборка детерминированного плана требует ручного согласования версий, откатов и проверки зависимостей.  
EN: Migration plans consist of scattered SQL patches, schema files, and seed data. Deterministic assembly requires manual version/rollback coordination.  
ZH: 迁移计划由分散的 SQL 补丁、模式文件和种子数据组成。确定性组装需手动协调版本/回滚。

**Решение / Solution / 解决方案**  
RU: `@@` собирает патчи по маске версии, `@@{0..N}` ограничивает шаги отката, `@$` формирует словарь схемы из пар, `.jsonmo` подставляет переменные окружения в seed-данные. Ошибка отсутствия патча → `ERR_EMPTY_DONOR` → миграция блокируется.  
EN: `@@` collects patches by version mask, `@@{0..N}` limits rollback steps, `@$` forms schema dict from pairs, `.jsonmo` injects env vars into seeds. Missing patch → `ERR_EMPTY_DONOR` → migration blocked.  
ZH: `@@` 按版本掩码收集补丁，`@@{0..N}` 限制回滚步骤，`@$` 从键值对形成模式字典，`.jsonmo` 将环境变量注入种子数据。缺少补丁 → `ERR_EMPTY_DONOR` → 迁移阻断。

**Сценарии / Scenarios / 应用场景**
```jsonmod
TARGET = "v2.1"
{"plan": {"version": "${TARGET}", "patches": @@ "file://migrations/${TARGET}_*.json", "rollback": @@{0..1} "file://migrations/${TARGET}_rollback.json"}}
```

---

## 🛠️ CI/CD & Automation / Автоматизация / 自动化

### `ci-matrix-generation`
**Проблема / Problem / 痛点**  
RU: Матрицы задач в GitHub Actions/GitLab CI дублируют шаги сборки, тестирования и деплоя. Изменение одного шага требует правки десятков рабочих процессов, что ведёт к рассинхрону и человеческим ошибкам.  
EN: CI task matrices duplicate build/test/deploy steps across workflows. Changing one step requires editing dozens of pipelines, causing drift and human error.  
ZH: CI 任务矩阵在工作流中重复构建/测试/部署步骤。修改一个步骤需编辑数十个流水线，导致漂移和人为错误。

**Решение / Solution / 解决方案**  
RU: Плоский список параметров конвертируется в объект стратегии через `@$`. Reusable шаги выносятся в отдельные файлы и подтягиваются через `@%`. Генерация происходит детерминированно до запуска пайплайна.  
EN: Flat parameter lists convert to strategy objects via `@$`. Reusable steps live in separate files and are pulled via `@%`. Generation occurs deterministically before pipeline start.  
ZH: 扁平参数列表通过 `@$` 转换为策略对象。可复用步骤存放在独立文件中并通过 `@%` 拉取。在流水线启动前确定性生成。

**Сценарии / Scenarios / 应用场景**
```jsonmod
SERVICES = "auth,payment,notification"
MATRIX = @$ "file://ci/matrix_flat.json"
{"workflow": {"strategy": {"matrix": ${MATRIX}}, "jobs": {"build": {"steps": [ @%{"docker_build"} "file://ci/steps.json" ]}}}}
```

---

### `multitenant-configuration`
**Проблема / Problem / 痛点**  
RU: SaaS-платформы хранят общие настройки и tenant-specific переопределения раздельно. Ручной мердж или fallback-логика часто приводит к утечке настроек между клиентами или некорректному наследованию.  
EN: SaaS platforms store global settings and tenant-specific overrides separately. Manual merges or fallback logic often cause setting leakage or incorrect inheritance.  
ZH: SaaS 平台将全局设置和租户特定覆盖分开存储。手动合并或回退逻辑常导致配置泄漏或错误继承。

**Решение / Solution / 解决方案**  
RU: `@%{}` загружает полный объект overrides, `@@` агрегирует webhooks по glob-маске тенанта. Если директория тенанта пуста → `ERR_DIR_NOT_FOUND` → доступ запрещён. Никаких "тихих" fallback на дефолт.  
EN: `@%{}` loads full overrides object, `@@` aggregates tenant webhooks via glob. Empty tenant dir → `ERR_DIR_NOT_FOUND` → access denied. No silent fallbacks.  
ZH: `@%{}` 加载完整覆盖对象，`@@` 通过 glob 聚合租户 webhook。租户目录为空 → `ERR_DIR_NOT_FOUND` → 访问拒绝。无静默回退。

**Сценарии / Scenarios / 应用场景**
```jsonmod
TENANT_ID = "acme-corp"
{"tenant": "${TENANT_ID}", "features": @%{"enabled"} "file://templates/features.json", "overrides": @%{} "file://tenants/${TENANT_ID}/config.json"}
```

---

## 🔒 Security & Compliance / Безопасность и аудит / 安全与合规

### `feature-flag-injection`
**Проблема / Problem / 痛点**  
RU: Управление функциями через внешние флаги часто пропускает отсутствующие ключи, заменяя их на `null` или дефолтные значения. Это приводит к непредсказуемому поведению в production.  
EN: Feature flag management often silently skips missing keys, replacing them with `null` or defaults, causing unpredictable production behavior.  
ZH: 功能标志管理常静默跳过缺失键，替换为 `null` 或默认值，导致生产环境不可预测的行为。

**Решение / Solution / 解决方案**  
RU: Мультиселектор `@%{"new_ui", "beta_api"}` требует явного присутствия ключей. `ERR_KEY_NOT_FOUND` останавливает процесс, гарантируя, что ни один флаг не будет проигнорирован.  
EN: Multi-selector `@%{"new_ui", "beta_api"}` requires explicit key presence. `ERR_KEY_NOT_FOUND` halts execution, ensuring no flag is silently skipped.  
ZH: 多选择器 `@%{"new_ui", "beta_api"}` 要求键显式存在。`ERR_KEY_NOT_FOUND` 终止执行，确保无标志被静默跳过。

**Сценарии / Scenarios / 应用场景**
```jsonmod
{"features": @%{"new_ui", "beta_api"} "file://flags/env_prod.json", "maintenance": @%{"maintenance"} "file://flags/env_prod.json"}
```

---

### `audit-log-aggregation`
**Проблема / Problem / 痛点**  
RU: Агрегация логов безопасности из ротированных файлов для отправки в SIEM требует сложных bash-скриптов, парсинга JSON-линий и ручного контроля временных меток.  
EN: Aggregating security logs from rotated files for SIEM ingestion requires complex bash scripts, JSON line parsing, and manual timestamp control.  
ZH: 将轮转安全日志聚合发送至 SIEM 需要复杂的 bash 脚本、JSON 行解析和手动时间戳控制。

**Решение / Solution / 解决方案**  
RU: `${VAR}` в URI + `@@` (glob) + `@%` (ключ) собирают отчёт в один валидный JSON за один проход. Временные метки подставляются на этапе сборки, структура гарантирована.  
EN: `${VAR}` in URI + `@@` (glob) + `@%` (key) assemble the report into one valid JSON in a single pass. Timestamps are injected at build time, structure is guaranteed.  
ZH: URI 中的 `${VAR}` + `@@` (glob) + `@%` (键) 在一次传递中将报告组装为单一有效 JSON。时间戳在构建时注入，结构有保障。

**Сценарии / Scenarios / 应用场景**
```jsonmod
MONTH = "2026-05"
{"report": {"generated": "${MONTH}-23T14:00:00Z", "auth_events": @@ "file://logs/${MONTH}_auth_*.json", "admin_actions": @%{"actions"} "file://logs/${MONTH}_admin.json"}}
```

---

## 📐 Advanced Resolution / Расширенный резолв / 高级解析

### `nested-path-extraction`
**Проблема / Problem / 痛点**  
RU: Извлечение вложенных значений требует загрузки всего родительского объекта в память или написания цепочек резолвов. Это увеличивает расход памяти, усложняет шаблоны и создаёт лишние промежуточные объекты.  
EN: Extracting nested values requires loading entire parent objects or writing resolver chains, increasing memory usage, complicating templates, and creating intermediate objects.  
ZH: 提取嵌套值需加载整个父对象或编写解析链，增加内存消耗、复杂化模板并创建中间对象。

**Решение / Solution / 解决方案**  
RU: Путевые селекторы `@%{"app/name"}` точечно резолвят глубину через `/`. Возвращается только листовое значение, имя ключа в выводе = последний сегмент пути. Без wildcard, строго детерминировано, совместимо с плоскими селекторами.  
EN: Path selectors `@%{"app/name"}` precisely resolve depth via `/`. Only the leaf value is returned, output key = last path segment. No wildcards, strictly deterministic, compatible with flat selectors.  
ZH: 路径选择器 `@%{"app/name"}` 通过 `/` 精确解析深度。仅返回叶节点值，输出键 = 最后一段路径。无通配符，严格确定性，兼容扁平选择器。

**Сценарии / Scenarios / 应用场景**
```jsonmod
{"primary_db": @%{"network/host"} "file://configs/deep.json", "secondary_db": @%{"network/backup/host"} "file://configs/deep.json"}
{"config": @%{"app/name", "db/port"} "file://configs/full.json"}
```
- `ERR_KEY_NOT_FOUND: path 'a/b/c'` → строгая диагностика обрыва пути.
- Плоские селекторы `@%{"key"}` работают без изменений. Глубина активируется только при явном `/`.

---
Я разделил их строго по 4 ролям, как ты просил. Дубли убрал, контекст расширил, структуру выровнял под GitHub-стандарт. Каждый кейс идёт по схеме: **Проблема → Решение → Контекст → Шаблон → Вывод → Комбинация → Когда использовать / НЕ использовать**. Путевые селекторы (`/`) встроены туда, где они реально экономят код.

```markdown
# Use Cases / Варианты использования / 使用场景

> Практический справочник интеграции `jsonmod` в production-пайплайны.  
> Формат: `RU | EN | ZH`. Запуск: `cat template.jsonmod | ./jsonmod | jq -C .`  
> Принцип: детерминизм, строгая валидация, нулевое кэширование. Без состояния.

---

## 👨‍💻 1. Developers / Разработчики / 开发者

### `microservice-config-assembly`
**Проблема / Problem / 痛点**  
RU: Конфигурация микросервисов размазана: базовые параметры в репо, секреты в Vault/KMS, переменные окружения задаёт оркестратор. Сборка итогового `config.json` обычно требует bash/python-скриптов, которые ломаются при изменении структуры, не валидируют типы и пропускают ошибки до рантайма (`config parse error` в логах после деплоя).  
EN: Microservice configs are fragmented across repos, Vault/KMS, and orchestrator env vars. Assembly typically relies on fragile bash/python scripts that break on structure changes, skip type validation, and fail at runtime.  
ZH: 微服务配置分散在仓库、Vault/KMS 和编排器环境变量中。组装通常依赖脆弱的 bash/python 脚本，结构变更易崩溃，跳过类型验证，并在运行时失败。

**Решение / Solution / 解决方案**  
RU: `jsonmod` детерминировано собирает конфигурацию из независимых слоёв строго до старта процесса. Шаблон `.jsonmod` описывает *что* нужно, а не *как* склеивать. Ошибки типа и отсутствующих ключей ловятся на этапе CI, а не в production.  
EN: `jsonmod` deterministically assembles configs from independent layers strictly before process startup. The `.jsonmod` template declares *what* is needed, not *how* to glue it. Type/missing-key errors fail in CI, not production.  
ZH: `jsonmod` 在进程启动前严格从独立层确定性组装配置。`.jsonmod` 模板声明 *需要什么*，而非 *如何拼接*。类型/缺失键错误在 CI 阶段拦截，而非生产环境。

**📄 Шаблон (`service.jsonmod`)**
```jsonmod
ENV = "production"
DB_HOST = "db.internal"

{
  "app": @%{"base"} "file://configs/base.json",
  "env_vars": @%{"prod"} "file://configs/${ENV}.json",
  "secrets": @%{"vault"} "file://configs/secrets.jsonmo",
  "routes": @@{0..1} "file://configs/routes.json"
}
```
**📦 Доноры**
- `configs/base.json`: `{"port": 8080, "timeout_ms": 30}`
- `configs/production.json`: `{"debug": false, "log_level": "warn"}`
- `configs/secrets.jsonmo`: `{"db_pass": "${DB_HOST}_pass", "jwt": "tok_99x"}`
- `configs/routes.json`: `[{"path": "/v1/pay"}, {"path": "/v1/health"}, {"path": "/debug"}]`

**✅ Выход**
```json
{
  "app": {"port": 8080, "timeout_ms": 30},
  "env_vars": {"debug": false, "log_level": "warn"},
  "secrets": {"db_pass": "db.internal_pass", "jwt": "tok_99x"},
  "routes": [{"path": "/v1/pay"}, {"path": "/v1/health"}]
}
```

**🔗 Комбинация / Directive Matrix**  
`@%` (объекты) + `@@{range}` (срез массива) + `${VAR}` в URI + `.jsonmo` (рекурсивная подстановка в контент)

**⚠️ Когда использовать / When to use / 适用场景**  
- Stateless-сервисы с тяжёлым конфигом, меняющимся между окружениями
- GitOps-пайплайны (ArgoCD/Flux), где секреты и базовые параметры хранятся раздельно
- Мультиокружение: один бинарник, разные конфиги генерируются на лету

**⚠️ Когда НЕ использовать / When NOT to use / 不适用场景**  
- Монолиты с хардкодом параметров
- Конфиги, читаемые напрямую из Consul/Vault SDK (лучше использовать нативный клиент)
- Динамические конфиги, меняющиеся чаще раза в час (генерация на каждый запрос нецелесообразна)

---

### `mock-api-generation`
**Проблема / Problem / 痛点**  
RU: Хранение мок-ответов в виде полных JSON-файлов дублирует структуру, занимает место в VCS и усложняет поддержку тестовых фикстур. Плоские списки пар `[k,v]` неудобно конвертировать вручную перед каждым тестовым прогоном.  
EN: Storing mock responses as full JSON files duplicates structure, bloats VCS, and complicates fixture maintenance. Manual conversion of `[k,v]` lists before test runs is error-prone.  
ZH: 以完整 JSON 文件存储模拟响应会重复结构、膨胀版本库并使夹具维护复杂。测试前手动转换 `[k,v]` 列表易出错。

**Решение / Solution / 解决方案**  
RU: Директива `@$` автоматически преобразует плоский массив чётной длины в валидный объект с сохранением типов. Тестовые данные хранятся компактно, конвертация происходит на лету без сторонних парсеров.  
EN: `@$` auto-converts even-length flat arrays into valid objects with preserved types. Test data stays compact, conversion happens on-the-fly without external parsers.  
ZH: `@$` 自动将偶数长度扁平数组转换为保留类型的有效对象。测试数据保持紧凑，无需外部解析器即可实时转换。

**📄 Шаблон (`mock.jsonmod`)**
```jsonmod
{
  "user_profile": @$ "file://mocks/user_flat.json",
  "metadata": @%{"status"} "file://mocks/status.json"
}
```
**📦 Доноры**
- `mocks/user_flat.json`: `["id", 42, "name", "Alice", "active", true, "roles", ["admin", "editor"]]`
- `mocks/status.json`: `{"status": "ok", "code": 200}`

**✅ Выход**
```json
{
  "user_profile": {"id": 42, "name": "Alice", "active": true, "roles": ["admin", "editor"]},
  "metadata": {"status": "ok", "code": 200}
}
```

**🔗 Комбинация**  
`@$` (flat-list → object) + `@%` (key extraction) + авто-приведение типов

**⚠️ Когда использовать**  
- Unit/integration тесты, где структура ответа меняется часто
- Хранение фикстур в репо с минимальным оверхедом
- Генерация payload для нагрузочного тестирования

**⚠️ Когда НЕ использовать**  
- Контрактные тесты (OpenAPI/Swagger), где нужна валидация схемы, а не генерация
- Сложные вложенные моки с условной логикой (лучше использовать фабрики на Go/Python)

---

## 🌐 2. Network Engineers / Сетевые инженеры / 网络工程师

### `acl-rule-aggregation`
**Проблема / Problem / 痛点**  
RU: Правила фильтрации хранятся в разрозменных таблицах (основные, кастомные, черновые). Ручное склеивание или `jq`-скрипты ломают порядок приоритетов, а отладочные правила часто попадают в production.  
EN: ACL rules are stored in scattered tables (core, custom, draft). Manual merges or `jq` scripts break priority order, and debug rules often leak to production.  
ZH: ACL 规则分散存储在多个表中（核心、自定义、草稿）。手动合并或 `jq` 脚本会破坏优先级顺序，调试规则常泄露至生产环境。

**Решение / Solution / 解决方案**  
RU: `@@{start..end}` позволяет точно резать массивы по индексам, отбрасывая черновые записи до применения. Порядок сохраняется, структура валидируется до загрузки в оборудование.  
EN: `@@{start..end}` precisely slices arrays by index, stripping draft entries before application. Order is preserved, structure validated before loading to hardware.  
ZH: `@@{start..end}` 按索引精确切片数组，应用前剔除草稿条目。顺序保留，加载至设备前完成结构验证。

**📄 Шаблон (`acl.jsonmod`)**
```jsonmod
{
  "firewall": {
    "name": "edge-perimeter",
    "core_rules": @@{0..2} "file://acl/core.json",
    "custom_rules": @@{2..4} "file://acl/custom.json"
  }
}
```
**📦 Доноры**
- `acl/core.json`: `["permit tcp 10.0.0.0/8", "deny udp any", "permit icmp host 192.168.1.1", "draft_rule_X"]`
- `acl/custom.json`: `["permit tcp 172.16.0.0/12", "permit udp 172.16.0.0/12", "permit sctp any", "permit gre any", "deny ip any any"]`

**✅ Выход**
```json
{
  "firewall": {
    "name": "edge-perimeter",
    "core_rules": ["permit tcp 10.0.0.0/8", "deny udp any", "permit icmp host 192.168.1.1"],
    "custom_rules": ["permit sctp any", "permit gre any", "deny ip any any"]
  }
}
```

**🔗 Комбинация**  
`@@{s..e}` (срез массива) + вложенные объекты + строгое позиционирование

**⚠️ Когда использовать**  
- Маршрутизаторы/фаерволы, где порядок правил критичен (Cisco, Juniper, pfSense)
- Автоматизация CI/CD для сетевых конфигов
- Контроль rollout: тестовые правила хранятся в одном файле, но не попадают в прод

**⚠️ Когда НЕ использовать**  
- Динамические BGP/OSPF сосежи (лучше использовать `@$` для плоских IP-ASN пар)
- Конфиги с условиями/переменными (Terraform/Ansible справляются лучше)

---

### `bgp-peer-mapping`
**Проблема / Problem / 痛点**  
RU: Списки пиров часто хранятся как плоские текстовые файлы или CSV. Преобразование в JSON для автоматизации требует `awk`/`sed`, что ненадёжно при смене формата или добавлении комментариев.  
EN: Peer lists are often stored as flat text files or CSV. Converting to JSON for automation requires `awk`/`sed`, which breaks on format changes or comments.  
ZH: 对等节点列表常以纯文本或 CSV 存储。自动化转为 JSON 需 `awk`/`sed`，格式变更或注释易导致崩溃。

**Решение / Solution / 解决方案**  
RU: `@$` превращает плоский список `["IP1", ASN1, "IP2", ASN2]` в словарь маршрутизации за один проход. Типы сохраняются, валидация чётности длины гарантирует целостность.  
EN: `@$` converts flat `["IP1", ASN1, "IP2", ASN2]` lists into routing dictionaries in one pass. Types preserved, even-length validation guarantees integrity.  
ZH: `@$` 将扁平 `["IP1", ASN1, "IP2", ASN2]` 列表一步转换为路由字典。保留类型，偶数长度验证保障完整性。

**📄 Шаблон (`bgp.jsonmod`)**
```jsonmod
{
  "peers": @$ "file://bgp/neighbors_flat.json"
}
```
**📦 Донор**
- `bgp/neighbors_flat.json`: `["192.168.1.1", 64512, "10.0.0.1", 65001, "172.16.0.5", 65530]`

**✅ Выход**
```json
{
  "peers": {
    "192.168.1.1": 64512,
    "10.0.0.1": 65001,
    "172.16.0.5": 65530
  }
}
```

**🔗 Комбинация**  
`@$` (чётные → ключи, нечётные → значения) + авто-валидация длины

**⚠️ Когда использовать**  
- Генерация конфигов для FRRouting, BIRD, GoBGP
- Импорт внешних списков партнёров/IX
- Быстрая валидация парности IP-ASN перед пушем

**⚠️ Когда НЕ использовать**  
- Сложные пиринговые политики с фильтры/communities (требуют полноценного templating)
- Динамические peering сессии, меняющиеся в реальном времени

---

## 🐧 3. Sysadmins & DevOps / Системные администраторы / 系统管理员

### `dynamic-upstream-glob`
**Проблема / Problem / 痛点**  
RU: При масштабировании backend-пулов конфигурация прокси требует ручного обновления списков серверов или сложных dynamic-discovery механизмов, которые добавляют задержку и точки отказа.  
EN: Backend pool scaling requires manual proxy config updates or complex dynamic discovery, adding latency and failure points.  
ZH: 后端池扩容需手动更新代理配置或复杂的动态发现机制，增加延迟和故障点。

**Решение / Solution / 解决方案**  
RU: `@@` с glob-маской `file://region_*.json` собирает все совпадения директории в один массив. Добавление сервера = `git add new_backend.json`. Порядок определяется ФС, что допустимо для stateless-балансировки.  
EN: `@@` with glob `file://region_*.json` aggregates all directory matches into one array. Adding a server = `git add`. FS order is acceptable for stateless balancing.  
ZH: `@@` 配合 glob `file://region_*.json` 将目录所有匹配项聚合为单一数组。添加服务器 = `git add`。文件系统顺序适用于无状态负载均衡。

**📄 Шаблон (`upstream.jsonmod`)**
```jsonmod
REGION = "eu-west"
{"pool_name": "app_${REGION}", "servers": @@ "file://backends/${REGION}_*.json"}
```
**📦 Доноры** (`eu-west_1.json`, `eu-west_2.json`)
```json
{"host": "10.0.1.10", "port": 3000, "weight": 5}
{"host": "10.0.1.11", "port": 3000, "weight": 3}
```

**✅ Выход**
```json
{
  "pool_name": "app_eu-west",
  "servers": [
    {"host": "10.0.1.10", "port": 3000, "weight": 5},
    {"host": "10.0.1.11", "port": 3000, "weight": 3}
  ]
}
```

**🔗 Комбинация**  
`@@` (glob-слияние) + `${VAR}` в пути + авто-разрешение `*`

**⚠️ Когда использовать**  
- Nginx/HAProxy/Envoy upstream-генерация
- GitOps-подход к инфраструктуре: новый хост = новый файл
- Stateless-кластеры, где порядок серверов не важен

**⚠️ Когда НЕ использовать**  
- Sticky-sessions или weighted round-robin с жёстким порядком
- Директории >100 файлов (glob замедляется, лучше использовать inventory-файл)
- Пустые директории → `ERR_EMPTY_DONOR` (требует fallback-логики в пайплайне)

---

### `singleton-unwrap`
**Проблема / Problem / 痛点**  
RU: Внешние API и системы конфигурации часто отдают данные в виде массива из одного объекта `[{}]`. Для доступа к полям требуются лишние селекторы или ручная распаковка.  
EN: External APIs/config systems often return data as single-element arrays `[{}]`, requiring extra selectors or manual unwrapping.  
ZH: 外部 API/配置系统常以单元素数组 `[{}]` 返回数据，需要额外选择器或手动解包。

**Решение / Solution / 解决方案**  
RU: `@%` автоматически разворачивает `[{}]` → `{}` до проверки типа. Селекторы работают сразу с вложенными полями, без лишних скобок и промежуточных шагов.  
EN: `@%` auto-unwraps `[{}]` → `{}` before type-checking. Selectors work directly on nested fields, eliminating extra braces and intermediate steps.  
ZH: `@%` 在类型检查前自动解包 `[{}]` → `{}`。选择器直接作用于嵌套字段，消除多余括号和中间步骤。

**📄 Шаблон (`singleton.jsonmod`)**
```jsonmod
{"cluster": @%{"region"} "file://data/cluster_info.json"}
```
**📦 Донор**
- `data/cluster_info.json`: `[{"region": "eu-west-2", "az": "a", "provider": "aws"}]`

**✅ Выход**
```json
{
  "cluster": {"region": "eu-west-2"}
}
```

**🔗 Комбинация**  
`@%` + Unwrap (`[{}]` → `{}`) + селектор ключа

**⚠️ Когда использовать**  
- Интеграция с AWS SSM, Consul KV, etcd (часто возвращают `[{}]`)
- Legacy-системы, отдающие JSON в нестандартной обёртке
- Упрощение шаблонов без потери строгости

**⚠️ Когда НЕ использовать**  
- Массивы >1 элемента → `ERR_TYPE_MISMATCH`
- Пустые массивы → `ERR_EMPTY_DONOR`
- Когда нужна явная валидация длины массива до извлечения

---

### `audit-log-aggregation`
**Проблема / Problem / 痛点**  
RU: Агрегация логов безопасности из ротированных файлов для отправки в SIEM требует сложных bash-скриптов, парсинга JSON-линий и ручного контроля временных меток.  
EN: Aggregating security logs from rotated files for SIEM ingestion requires complex bash scripts, JSON line parsing, and manual timestamp control.  
ZH: 将轮转安全日志聚合发送至 SIEM 需要复杂的 bash 脚本、JSON 行解析和手动时间戳控制。

**Решение / Solution / 解决方案**  
RU: `${VAR}` в URI + `@@` (glob) + `@%` (ключ) собирают отчёт в один валидный JSON за один проход. Временные метки подставляются на этапе сборки, структура гарантирована.  
EN: `${VAR}` in URI + `@@` (glob) + `@%` (key) assemble the report into one valid JSON in a single pass. Timestamps are injected at build time, structure is guaranteed.  
ZH: URI 中的 `${VAR}` + `@@` (glob) + `@%` (键) 在一次传递中将报告组装为单一有效 JSON。时间戳在构建时注入，结构有保障。

**📄 Шаблон (`audit.jsonmod`)**
```jsonmod
MONTH = "2026-05"
{"report": {"generated": "${MONTH}-23T14:00:00Z", "auth_events": @@ "file://logs/${MONTH}_auth_*.json", "admin_actions": @%{"actions"} "file://logs/${MONTH}_admin.json"}}
```
**📦 Доноры**
- `logs/2026-05_auth_1.json`: `[{"user": "alice", "event": "login"}]`
- `logs/2026-05_auth_2.json`: `[{"user": "bob", "event": "failed_auth"}]`
- `logs/2026-05_admin.json`: `{"actions": ["reset_pw", "rotate_keys"], "auditor": "sec_team"}`

**✅ Выход**
```json
{
  "report": {
    "generated": "2026-05-23T14:00:00Z",
    "auth_events": [
      {"user": "alice", "event": "login"},
      {"user": "bob", "event": "failed_auth"}
    ],
    "admin_actions": ["reset_pw", "rotate_keys"]
  }
}
```

**🔗 Комбинация**  
`${VAR}` в URI + `@@` (glob) + `@%` (ключ) + временные метки

**⚠️ Когда использовать**  
- SIEM/ELK ingestion pipelines
- Ежемесячные/еженедельные аудит-отчёты
- Compliance-требования к структурированному выводу

**⚠️ Когда НЕ использовать**  
- Потоковая обработка логов в реальном времени (Kafka/Fluentd лучше)
- Неструктурированные syslog/текстовые логи (нужен предварительный парсинг)

---

## ☸️ 4. Platform Engineers / Платформенные инженеры / 平台工程师

### `k8s-manifest-assembly`
**Проблема / Problem / 痛点**  
RU: YAML-манифесты Kubernetes подвержены ошибкам отступов, дублируют спецификации контейнеров для разных окружений, а секреты/переменные внедряются через ненадёжные `sed`/`envsubst` или тяжёлые операторы.  
EN: K8s YAML manifests suffer from indentation errors, duplicate container specs across envs, and rely on fragile `sed`/`envsubst` or heavy operators for secret/env injection.  
ZH: K8s YAML 清单易受缩进错误影响，跨环境容器规格重复，依赖脆弱的 `sed`/`envsubst` 或重型算子注入密钥/变量。

**Решение / Solution / 解决方案**  
RU: Генерация валидного JSON-манифеста напрямую из шаблона. `@$` превращает плоские метки в объекты, `@%` переиспользует спецификации контейнеров, `${VAR}` управляет namespace/репликами. Валидация схемы происходит до `kubectl apply`.  
EN: Direct valid JSON manifest generation from templates. `@$` converts flat labels to objects, `@%` reuses container specs, `${VAR}` controls namespace/replicas. Schema validation occurs before `kubectl apply`.  
ZH: 直接从模板生成有效 JSON 清单。`@$` 将扁平标签转为对象，`@%` 复用容器规格，`${VAR}` 控制命名空间/副本数。在 `kubectl apply` 前完成模式验证。

**📄 Шаблон (`k8s-deploy.jsonmod`)**
```jsonmod
NAMESPACE = "production"
APP = "payment-api"
REPLICAS = 3
{
  "apiVersion": "apps/v1", "kind": "Deployment",
  "metadata": {"name": "${APP}", "namespace": "${NAMESPACE}", "labels": @$ "file://k8s/${APP}_labels.json"},
  "spec": {"replicas": ${REPLICAS}, "selector": {"matchLabels": {"app": "${APP}"}},
    "template": {"spec": {"containers": [ @%{"main"} "file://k8s/containers.json" ]}}}
}
```
**📦 Доноры**
- `k8s/payment-api_labels.json`: `["app", "payment-api", "tier", "backend", "managed-by", "jsonmod"]`
- `k8s/containers.json`: `{"main": {"image": "registry.corp/payment:2.4", "ports": [{"containerPort": 8080}], "resources": {"limits": {"cpu": "1.0"}}}}`
- `k8s/production_env.json`: `[{"name": "DB_HOST", "value": "db-prod.internal"}, {"name": "LOG_LEVEL", "value": "warn"}]`

**✅ Выход**
```json
{
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {"name": "payment-api", "namespace": "production", "labels": {"app": "payment-api", "tier": "backend", "managed-by": "jsonmod"}},
  "spec": {"replicas": 3, "selector": {"matchLabels": {"app": "payment-api"}},
    "template": {"spec": {"containers": [{"image": "registry.corp/payment:2.4", "ports": [{"containerPort": 8080}], "resources": {"limits": {"cpu": "1.0"}}}], "env": [{"name": "DB_HOST", "value": "db-prod.internal"}, {"name": "LOG_LEVEL", "value": "warn"}]}}}
}
```

**🔗 Комбинация**  
`${VAR}` в URI/ключе + `@$` (flat→object) + `@%` (container spec) + `@@` (env array)

**⚠️ Когда использовать**  
- GitOps-развёртывания без Helm/Kustomize
- Мультиокружение с единым шаблоном манифеста
- Валидация JSON перед `kubectl apply`

**⚠️ Когда НЕ использовать**  
- Сложные Helm-чарты с зависимостями
- Динамические CRD/Operator-развёртывания
- Когда нужен YAML-формат строго (K8s принимает JSON, но некоторые инструменты требуют YAML)

---

### `ci-matrix-generation`
**Проблема / Problem / 痛点**  
RU: Матрицы задач в GitHub Actions/GitLab CI дублируют шаги сборки, тестирования и деплоя. Изменение одного шага требует правки десятков рабочих процессов, что ведёт к рассинхрону и человеческим ошибкам.  
EN: CI task matrices duplicate build/test/deploy steps across workflows. Changing one step requires editing dozens of pipelines, causing drift and human error.  
ZH: CI 任务矩阵在工作流中重复构建/测试/部署步骤。修改一个步骤需编辑数十个流水线，导致漂移和人为错误。

**Решение / Solution / 解决方案**  
RU: Плоский список параметров конвертируется в объект стратегии через `@$`. Reusable шаги выносятся в отдельные файлы и подтягиваются через `@%`. Генерация происходит детерминированно до запуска пайплайна.  
EN: Flat parameter lists convert to strategy objects via `@$`. Reusable steps live in separate files and are pulled via `@%`. Generation occurs deterministically before pipeline start.  
ZH: 扁平参数列表通过 `@$` 转换为策略对象。可复用步骤存放在独立文件中并通过 `@%` 拉取。在流水线启动前确定性生成。

**📄 Шаблон (`ci-matrix.jsonmod`)**
```jsonmod
SERVICES = "auth,payment,notification"
MATRIX = @$ "file://ci/matrix_flat.json"
{"workflow": {"strategy": {"matrix": ${MATRIX}}, "jobs": {"build": {"steps": [ @%{"docker_build"} "file://ci/steps.json" ]}}}}
```
**📦 Доноры**
- `ci/matrix_flat.json`: `["service", ["auth", "payment", "notification"], "env", ["dev", "staging", "prod"], "runner", ["linux", "arm64"]]`
- `ci/steps.json`: `{"docker_build": {"name": "Build Docker", "run": "docker build -t ${SERVICES}:latest ."}}`

**✅ Выход**
```json
{
  "workflow": {"strategy": {"matrix": {"service": ["auth", "payment", "notification"], "env": ["dev", "staging", "prod"], "runner": ["linux", "arm64"]}}, "jobs": {"build": {"steps": [{"name": "Build Docker", "run": "docker build -t auth,payment,notification:latest ."}]}}}
}
```

**🔗 Комбинация**  
`@$` (matrix object) + `${VAR}` подстановка в контент шага + `@%` (reusable step block)

**⚠️ Когда использовать**  
- Мультиязычные монолиты/микросервисы с одинаковыми этапами
- GitLab CI/GitHub Actions с тяжёлыми матрицами
- Централизованное хранение reusable steps

**⚠️ Когда НЕ использовать**  
- Динамические пайплайны, зависящие от git-хуков или внешних событий
- Простые репо с 1-2 шагами (оверхед шаблона не оправдан)

---

### `multitenant-configuration`
**Проблема / Problem / 痛点**  
RU: SaaS-платформы хранят общие настройки и tenant-specific переопределения раздельно. Ручной мердж или fallback-логика часто приводит к утечке настроек между клиентами или некорректному наследованию.  
EN: SaaS platforms store global settings and tenant-specific overrides separately. Manual merges or fallback logic often cause setting leakage or incorrect inheritance.  
ZH: SaaS 平台将全局设置和租户特定覆盖分开存储。手动合并或回退逻辑常导致配置泄漏或错误继承。

**Решение / Solution / 解决方案**  
RU: `@%{}` загружает полный объект overrides, `@@` агрегирует webhooks по glob-маске тенанта. Если директория тенанта пуста → `ERR_DIR_NOT_FOUND` → доступ запрещён. Никаких "тихих" fallback на дефолт.  
EN: `@%{}` loads full overrides object, `@@` aggregates tenant webhooks via glob. Empty tenant dir → `ERR_DIR_NOT_FOUND` → access denied. No silent fallbacks.  
ZH: `@%{}` 加载完整覆盖对象，`@@` 通过 glob 聚合租户 webhook。租户目录为空 → `ERR_DIR_NOT_FOUND` → 访问拒绝。无静默回退。

**📄 Шаблон (`tenant-config.jsonmod`)**
```jsonmod
TENANT_ID = "acme-corp"
ENV = "prod"
{"tenant": "${TENANT_ID}", "features": @%{"enabled"} "file://templates/features.json", "overrides": @%{} "file://tenants/${TENANT_ID}/config.json"}
```
**📦 Доноры**
- `templates/features.json`: `{"enabled": ["sso", "audit_log", "api_access"]}`
- `tenants/acme-corp/config.json`: `{"quotas": {"api_calls": 50000, "storage_gb": 200}, "custom_domain": "app.acme.io"}`

**✅ Выход**
```json
{
  "tenant": "acme-corp",
  "features": {"enabled": ["sso", "audit_log", "api_access"]},
  "overrides": {"quotas": {"api_calls": 50000, "storage_gb": 200}, "custom_domain": "app.acme.io"}
}
```

**🔗 Комбинация**  
`@%{}` (полный объект overrides) + `@@` (glob hooks) + `${VAR}` в пути

**⚠️ Когда использовать**  
- Multi-tenant SaaS с изоляцией настроек
- Billing/feature-gate системы
- Compliance-требования к явным override (без наследования)

**⚠️ Когда НЕ использовать**  
- Плоские tenant-структуры без overrides
- Динамическое создание тенантов в рантайме (требует DB/API-резолва)

---

## 📐 Path Selectors / Путевые селекторы / 路径选择器

> Фокус: Точечный доступ к вложенным значениям через `/`. Wildcard-маски исключены. Строгая валидация глубины.

### `nested-value-extraction`
**Проблема / Problem / 痛点**  
RU: Извлечение одного глубокого значения требует загрузки всего родительского объекта в память или написания цепочек резолвов. Это увеличивает расход памяти, усложняет шаблоны и создаёт лишние промежуточные объекты.  
EN: Extracting nested values requires loading entire parent objects or writing resolver chains, increasing memory usage, complicating templates, and creating intermediate objects.  
ZH: 提取嵌套值需加载整个父对象或编写解析链，增加内存消耗、复杂化模板并创建中间对象。

**Решение / Solution / 解决方案**  
RU: Путевые селекторы `@%{"app/name"}` точечно резолвят глубину через `/`. Возвращается только листовое значение, имя ключа в выводе = последний сегмент пути. Без wildcard, строго детерминировано, совместимо с плоскими селекторами.  
EN: Path selectors `@%{"app/name"}` precisely resolve depth via `/`. Only the leaf value is returned, output key = last path segment. No wildcards, strictly deterministic, compatible with flat selectors.  
ZH: 路径选择器 `@%{"app/name"}` 通过 `/` 精确解析深度。仅返回叶节点值，输出键 = 最后一段路径。无通配符，严格确定性，兼容扁平选择器。

**📄 Шаблон (`paths.jsonmod`)**
```jsonmod
{"primary_db": @%{"network/host"} "file://configs/deep.json", "secondary_db": @%{"network/backup/host"} "file://configs/deep.json"}
{"config": @%{"app/name", "db/port"} "file://configs/full.json"}
```
**📦 Доноры**
- `configs/deep.json`: `{"network": {"host": "10.0.1.10", "port": 5432, "backup": {"host": "10.0.1.20"}}}`
- `configs/full.json`: `{"app": {"name": "payment-svc"}, "db": {"port": 5432}}`

**✅ Выход**
```json
{
  "primary_db": "10.0.1.10",
  "secondary_db": "10.0.1.20",
  "config": {"name": "payment-svc", "port": 5432}
}
```

**🔗 Комбинация**  
`@%{"a/b/c"}` → возврат только значения + имя ключа в выводе = последний сегмент пути. Мультиселекторы с путями собираются в один объект.

**⚠️ Когда использовать**  
- Извлечение конкретных параметров из глубоких конфигов
- Плоские рантаймы, ожидающие `{"key": "value"}` без вложенности
- Оптимизация памяти: загрузка только нужного листа

**⚠️ Когда НЕ использовать**  
- Динамические глубины (требуют wildcard `*`, пока не поддерживается)
- Промежуточные узлы не объекты → `ERR_TYPE_MISMATCH`
- Пустые сегменты `//` → игнорируются, но снижают читаемость

---
> 💡 **Золотое правило инфраструктуры:**  
> `jsonmod` не угадывает. Каждый запуск — чистая трансформация.  
> Используйте `${VAR}` для контекста, `@@` для агрегации, `@$` для плоских словарей, `/` для глубины.  
> Если структура не совпадает → падение с `STDERR` и кодом `1`. Это гарантирует, что битая конфигурация никогда не попадёт в production.
```

