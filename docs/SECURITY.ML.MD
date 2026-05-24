#  Security & Compliance Guide / Руководство по безопасности / 安全与合规指南

> Формат: `RU | EN | ZH`. Архитектура: pipe-only, stateless, strict validation.  
> Назначение: Практические рекомендации по безопасной эксплуатации `jsonmod` в production.  
> Конвенция: `UPPERCASE.ML.MD` → готово к коммиту в GitHub.

---

## 🛡️ Core Security Principles / Основные принципы безопасности / 核心安全原则

| Принцип / Principle / 原则 | Описание / Description / 说明 |
|--------------------------|-------------------------------|
| **Stateless Execution**<br>Без состояния | Каждый запуск — чистая трансформация. `g_state` сбрасывается, кэш отсутствует. Нет утечки данных между запросами. |
| **Fail-Fast Validation**<br>Строгая валидация | Любое несоответствие структуры, типа или пути → `STDERR` + `exit 1`. Никаких тихих `null`, `undefined` или fallback-значений. |
| **URI Scheme Restriction**<br>Ограничение протоколов | В v0.2 активен только `file://`. `http://`, `vault://`, `s3://` отклоняются на уровне диспетчера. Нет сетевого взаимодействия. |
| **Deterministic Output**<br>Детерминизм | При одинаковых входных данных и донорах вывод всегда идентичен. Хеш конфига стабилен. Предсказуемо в CI/CD и аудите. |

---

## 🔍 Threat Model & Mitigations / Модель угроз и защита / 威胁模型与防护

### 1. Path Traversal / Обход путей / 路径遍历
**RU:** `${VAR}` подставляется в URI до вызова `file://`. Если переменная содержит `../`, файловая система разрешит переход.  
**EN:** `${VAR}` is injected into URI before `file://` call. If variable contains `../`, filesystem allows traversal.  
**ZH:** `${VAR}` 在 `file://` 调用前注入 URI。若变量包含 `../`，文件系统允许遍历。  
**✅ Митигация / Mitigation / 防护:**  
- Валидируйте источники переменных до пайпа: `[[ "$VAR" == *../* ]] && exit 1`  
- Ограничивайте рабочую директорию через `chroot` или `systemd` `ReadWritePaths=`  
- Используйте относительные пути только из доверенных директорий

### 2. Variable Injection / Инъекция переменных / 变量注入
**RU:** `${VAR}` резолвится до парсинга JSON. Специальные символы `$$` и `\@` экранируются на этапе `escapeSpecials`.  
**EN:** `${VAR}` resolves before JSON parsing. Special chars `$$` and `\@` are escaped at `escapeSpecials` stage.  
**ZH:** `${VAR}` 在 JSON 解析前解析。特殊字符 `$$` 和 `\@` 在 `escapeSpecials` 阶段转义。  
**✅ Митигация:**  
- Не передавайте пользовательский ввод напрямую в `${VAR}`  
- Для литеральных `$` используйте `$$`, для `@` → `\@`  
- Проверяйте длину и формат переменных перед подстановкой

### 3. Memory & FD Leaks / Утечки памяти и дескрипторов / 内存与描述符泄漏
**RU:** `libjson-c` управляет памятью автоматически. D GC не вмешивается. Дескрипторы ввода/вывода управляются вызывающим процессом.  
**EN:** `libjson-c` manages memory automatically. D GC untouched. I/O file descriptors managed by caller process.  
**ZH:** `libjson-c` 自动管理内存。D GC 不干预。I/O 文件描述符由调用进程管理。  
**✅ Митигация:**  
- В Perl/FFI всегда закрывайте `in_fd`/`out_fd` после вызова  
- В long-running процессах используйте `fork` или `IPC::Run` для изоляции  
- Мониторьте `ulimit -n` и `RSS` в production

### 4. Secret Exposure / Утечка секретов / 密钥泄露
**RU:** `.jsonmo` включает рекурсивную подстановку переменных в контент донора.Resolved секреты попадают в `STDOUT`.  
**EN:** `.jsonmo` enables recursive variable substitution in donor content. Resolved secrets go to `STDOUT`.  
**ZH:** `.jsonmo` 启用捐赠者内容中的递归变量替换。解析后的密钥输出至 `STDOUT`。  
**✅ Митигация:**  
- Никогда не логируйте `STDOUT` в production  
- Храните секреты в отдельных `.jsonmo` с ограниченным доступом (`0600`)  
- Используйте внешние vault-системы для инжекции, а не плоские файлы

---

## ⚙️ Deployment & Hardening / Развёртывание и защита / 部署与加固

| Практика / Practice / 实践 | Почему / Why / 原因 |
|---------------------------|---------------------|
| **Isolated Process**<br>Изолированный процесс | Запускайте `jsonmod` в отдельном контейнере или через `systemd` service. Не встраивайте в shared memory. |
| **CI Validation**<br>Валидация в CI | `cat template.jsonmod \| ./jsonmod > /dev/null` в pre-commit/pre-deploy hook. Блокирует битые конфиги до production. |
| **Error Interception**<br>Перехват ошибок | Всегда проверяйте `exit 1` и читайте `STDERR`. Не игнорируйте `ERR_*` коды. |
| **Resource Limits**<br>Лимиты ресурсов | `ulimit -v 512M -n 64` для предотвращения OOM и FD exhaustion при glob-масках. |
| **No Network Protocols**<br>Без сетевых протоколов | v0.2 не поддерживает `http://`/`ftp://`. Нет атаки на external endpoints. Будущие протоколы потребуют TLS/auth. |

---

## 📜 Audit & Compliance / Аудит и соответствие / 审计与合规

### ✅ Детерминизм и трассируемость
- Каждый запуск генерирует идентичный вывод при одинаковых входах
- Ошибки стандартизированы: `ERR_KEY_NOT_FOUND`, `ERR_TYPE_MISMATCH`, `ERR_FILE_NOT_FOUND` и т.д.
- Нет скрытых состояний, кэша или фоновых процессов
- Хеш выходного JSON стабилен → подходит для GitOps и compliance-отчётов

### 📊 Логирование для SIEM/Аудита
```bash
# RU: Стандартизированный перехват для аудита
# EN: Standardized capture for audit
# ZH: 标准化审计捕获
cat template.jsonmod | ./jsonmod > config.json 2> jsonmod.err
RC=$?
if [ $RC -ne 0 ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] jsonmod_failed exit=$RC err=$(cat jsonmod.err)" >> /var/log/jsonmod-audit.log
  exit 1
fi
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] jsonmod_success config_sha=$(sha256sum config.json)" >> /var/log/jsonmod-audit.log
```

---

## ✅ Production Checklist / Чеклист для продакшена / 生产环境检查清单

| Статус | Проверка / Check / 检查项 |
|:------:|---------------------------|
| ☐ | Шаблоны `.jsonmod` проходят валидацию в CI/CD до деплоя |
| ☐ | Переменные `${VAR}` санитайзятся перед подстановкой в URI |
| ☐ | Пути `file://` ограничены доверенными директориями |
| ☐ | Секреты хранятся в `.jsonmo` с правами `0600` или во внешнем vault |
| ☐ | `STDOUT` не логируется; `STDERR` перехватывается и анализируется |
| ☐ | `exit 1` обрабатывается как фатальная ошибка, пайплайн блокируется |
| ☐ | Файловые дескрипторы закрываются после каждого вызова |
| ☐ | Нет shared state между запусками; каждый вызов изолирован |
| ☐ | Ресурсы ограничены (`ulimit`, cgroups, container limits) |
| ☐ | Выходной JSON верифицируется по схеме перед использованием downstream |

---

> 💡 **Золотое правило безопасности / Golden Security Rule / 安全黄金法则**  
> `jsonmod` не угадывает, не кэширует и не прощает.  
> Структура не совпадает → `STDERR` + `exit 1`. Путь битый → падение. Секрет отсутствует → блокировка.  
> В production: изолируйте процесс, валидируйте в CI, перехватывайте ошибки, не логируйте вывод.  
> Детерминизм + строгость = нулевая поверхность атаки через конфигурацию.

---