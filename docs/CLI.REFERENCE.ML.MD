---

# CLI Reference / Справочник командной строки / 命令行参考

> Строгое руководство по эксплуатации `jsonmod`. Без вымышленных флагов. Без обязательных зависимостей.  
> Формат: `RU | EN | ZH`. Архитектура: `STDIN → jsonmod → STDOUT`. Ошибки: `STDERR + exit 1`.

---

## 🔹 Базовое поведение / Base behavior / 基础行为
**RU:** `jsonmod` читает `.jsonmod`-шаблон из `STDIN`, резолвит доноров и переменные, отдаёт валидный JSON в `STDOUT`. Внешние утилиты (`jq`, `python`, `awk`) не требуются.  
**EN:** `jsonmod` reads a `.jsonmod` template from `STDIN`, resolves donors and variables, and outputs valid JSON to `STDOUT`. External tools (`jq`, `python`, `awk`) are optional.  
**ZH:** `jsonmod` 从 `STDIN` 读取 `.jsonmod` 模板，解析捐赠者和变量，并将有效 JSON 输出至 `STDOUT`。外部工具（`jq`、`python`、`awk`）为可选。

---

## 🔹 Синтаксис запуска / Launch syntax / 启动语法
```bash
cat template.jsonmod | ./jsonmod > output.json
```
**RU:** Без флагов. Без аргументов. Только пайп.  
**EN:** No flags. No arguments. Pipe only.  
**ZH:** 无标志。无参数。仅管道。

---

## 🔹 Вывод и диагностика / Output & diagnostics / 输出与诊断
| Поток / Stream / 流 | Содержимое / Content / 内容 | Код возврата / Exit code / 退出码 |
|---------------------|---------------------------|----------------------------------|
| `STDOUT` | Валидный JSON (всегда) | `0` (успех) |
| `STDERR` | `ERR_*` сообщения (только при ошибке) | `1` (фатальная ошибка) |

**Пример захвата ошибок / Error capture example / 错误捕获示例**
```bash
# RU: Проверить успех без jq
# EN: Check success without jq
# ZH: 无需 jq 检查成功状态
if cat template.jsonmod | ./jsonmod > out.json 2>err.log; then
  echo "✅ OK"
else
  cat err.log >&2  # Выводим причину
  exit 1
fi
```

---

## 🔹 Пайпы и интеграция / Pipes & integration / 管道与集成
### 1. Сохранение в файл / Save to file / 保存至文件
```bash
# RU: Без форматирования (сырой JSON)
# EN: Without formatting (raw JSON)
# ZH: 无格式化（原始 JSON）
cat service.jsonmod | ./jsonmod > config.json

# RU: С pretty-print (опционально, требует jq)
# EN: With pretty-print (optional, requires jq)
# ZH: 带美化输出（可选，需 jq）
cat service.jsonmod | ./jsonmod | jq . > config.json
```

### 2. Передача в другую команду / Pass to next command / 传递至下一命令
```bash
# RU: Прямая подача в kubectl (JSON принимается нативно)
# EN: Direct pipe to kubectl (JSON accepted natively)
# ZH: 直接管道至 kubectl（原生支持 JSON）
cat k8s-deploy.jsonmod | ./jsonmod | kubectl apply -f -

# RU: Чтение в переменную shell
# EN: Read into shell variable
# ZH: 读取至 shell 变量
JSON_PAYLOAD=$(cat tenant.jsonmod | ./jsonmod)
echo "${JSON_PAYLOAD}" | curl -X POST -H "Content-Type: application/json" -d @- https://api.corp/config
```

### 3. CI/CD-валидация / CI/CD validation / CI/CD 验证
```bash
# RU: Fail-fast при битом шаблоне
# EN: Fail-fast on broken template
# ZH: 模板损坏时快速失败
cat pipeline.jsonmod | ./jsonmod > /dev/null || { echo "❌ Template broken"; exit 1; }
```

---

## 🔹 Переменные и контекст / Variables & context / 变量与上下文
**RU:** Переменные объявляются **внутри** `.jsonmod`-файла. Передача из окружения происходит до запуска через `cat` или heredoc. `jsonmod` не читает `ENV` напрямую.  
**EN:** Variables are declared **inside** the `.jsonmod` file. Environment injection happens before launch via `cat` or heredoc. `jsonmod` does not read `ENV` directly.  
**ZH:** 变量在 `.jsonmod` 文件**内部**声明。环境变量通过 `cat` 或 heredoc 在启动前注入。`jsonmod` 不直接读取 `ENV`。

**Пример / Example / 示例**
```bash
# RU: Динамическая подстановка до пайпа
# EN: Dynamic injection before pipe
# ZH: 管道前动态注入
sed "s|TARGET_ENV|${TARGET_ENV}|g" template.jsonmod.tmpl | ./jsonmod > out.json

# RU: Heredoc для inline-шаблона
# EN: Heredoc for inline template
# ZH: 用于内联模板的 Heredoc
cat <<'EOF' | ./jsonmod
REGION = "eu-west"
{"pool": @@ "file://backends/${REGION}_*.json"}
EOF
```

---

## 🔹 Типичные сценарии CLI / Typical CLI patterns / 典型命令行场景
| Задача / Task / 任务 | Команда / Command / 命令 |
|----------------------|--------------------------|
| Проверить синтаксис / Validate syntax / 验证语法 | `cat t.jsonmod \| ./jsonmod > /dev/null` |
| Отладить путь / Debug path / 调试路径 | `cat t.jsonmod \| ./jsonmod 2>&1 \| grep ERR` |
| Сравнить донор / Diff donor / 对比捐赠者 | `diff <(cat a.jsonmod \| ./jsonmod \| sort) <(cat b.jsonmod \| ./jsonmod \| sort)` |
| Запуск в cron / Cron execution / Cron 执行 | `*/5 * * * * cat sync.jsonmod \| /opt/jsonmod > /data/sync.json 2>> /var/log/jsonmod.err` |

---

## 🔹 Ограничения ядра / Core constraints / 核心限制
| Ограничение / Constraint / 限制 | Причина / Reason / 原因 |
|-------------------------------|--------------------------|
| Нет CLI-флагов / No CLI flags / 无命令行标志 | Архитектура pipe-only. Форматирование/валидация делегируется внешним утилитам |
| Нет чтения `ENV` / No `ENV` read / 不读取环境变量 | Детерминизм. Контекст задаётся строго внутри `.jsonmod` или перед пайпом |
| Только `file://` / Only `file://` / 仅支持 `file://` | Версия 0.2. `http://`, `postgres://` в реестре протоколов, но не активны |

> 💡 **Правило эксплуатации:**  
> `jsonmod` — это фильтр. Он не хранит состояние, не кэширует, не читает флаги.  
> `STDIN` → валидный `.jsonmod` → `STDOUT` JSON → `STDERR` ошибка → `exit 0/1`.  
> Всё остальное (pretty-print, env-substitution, валидация схемы) делается до или после пайпа.

