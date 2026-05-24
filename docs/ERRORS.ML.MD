# 🚨 Error Reference / Справочник ошибок / 错误参考

> Строгая карта диагностических сообщений `jsonmod`. Формат: `RU | EN | ZH`.  
> Архитектура: любой сбой → `STDERR` + `exit 1`. Никаких тихих пропусков.  

---

## 📊 Quick Matrix / Быстрая матрица / 快速矩阵

| Код / Code / 代码 | Триггер / Trigger / 触发条件 | Фикс / Fix / 修复方案 | Контекст / Context / 上下文 |
|-------------------|-----------------------------|----------------------|----------------------------|
| `ERR_KEY_NOT_FOUND` | Селектор `@%{"key"}` или путь `@%{"a/b"}` отсутствует в доноре | Проверить имя ключа/пути. Убрать селектор `@%{}` для полного объекта | Строгая валидация. Нет тихих `null`. Путь `/` требует существования всех сегментов |
| `ERR_TYPE_MISMATCH` | Директива не соответствует типу донора (напр. `@%` получил массив, `@$` получил объект) | Сопоставить директиву с типом данных. `@@` → массив, `@$` → плоский список, `@%` → объект | Unwrap `[{}]` → `{}` применяется автоматически до проверки типа |
| `ERR_INVALID_SELECTOR` | Некорректный синтаксис: нечисловой индекс, битый диапазон, зарезервированные слова | Проверить формат. Индексы `int`, диапазоны `start..end`. Без кавычек в диапазонах | Пример: `@@{list}` → ошибка. `@@{0..2}` → OK. Валидация на этапе токенизации |
| `ERR_INDEX_OUT_OF_RANGE` | Запрошенный индекс или диапазон выходит за границы массива донора | Уменьшить диапазон. Проверить длину массива. Индексы `0-based` | Границы проверяются для каждого элемента диапазона. Отрицательные индексы запрещены |
| `ERR_EMPTY_DONOR` | Донор возвращает пустой массив `[]` или пустой контент при ожидании данных | Убедиться в наличии данных. Добавить fallback-логику в пайплайн | `@%` и `@@` требуют непустого источника. Glob без совпадений → ошибка |
| `ERR_FILE_NOT_FOUND` / `ERR_DIR_NOT_FOUND` | Файл/директория по пути `file://...` не существует после подстановки `${VAR}` | Проверить права, относительные пути, существование. Использовать `-f`/`-d` до вызова | Протокол `file` строгий. `~` и скрытые файлы обрабатываются ФС |
| `ERR_INVALID_URI` | Отсутствует схема `://` в URI директивы | Добавить протокол: `file://path.json` | Парсер ожидает `<scheme>://<resource>`. Проверка в `fetchByScheme` |
| `ERR_UNSUPPORTED_PROTOCOL` | Указана схема, не зарегистрированная в диспетчере протоколов | Использовать только `file://` (v0.2) или добавить драйвер | Реестр расширяемый. `default` ветка в `switch` ловит неизвестные схемы |

---

##  Detailed Diagnostics / Детальная диагностика / 详细诊断

### `ERR_KEY_NOT_FOUND` / Путь и Ключ / 路径与键
**RU:**  
Бросается, когда селектор `@%{"key"}` или путевой селектор `@%{"a/b/c"}` не найден в распарсенном доноре. Для путей проверяется каждый сегмент. Если путь обрывается → возврат `null` → ошибка. Имя ключа в выводе = последний сегмент пути.

**EN:**  
Thrown when selector `@%{"key"}` or path selector `@%{"a/b/c"}` is missing in parsed donor. For paths, each segment is validated. Broken path → `null` → error. Output key name = last path segment.

**ZH:**  
当选择器 `@%{"key"}` 或路径选择器 `@%{"a/b/c"}` 在解析后的捐赠者中缺失时抛出。路径需验证每个分段。路径中断 → 返回 `null` → 报错。输出键名 = 最后一段路径。

**Пример / Example / 示例:**
```text
ERR_KEY_NOT_FOUND: path 'db/port' not found in donor file://configs/full.json
ERR_KEY_NOT_FOUND: key 'vault' not found in donor file://secrets.jsonmo
```

---

### `ERR_TYPE_MISMATCH` / Типы данных / 数据类型
**RU:**  
Возникает при несовпадении директивы и типа донора. `@%` ожидает объект или одноэлементный массив `[{}]` (авто-unwrap). `@@` ожидает массив. `@$` ожидает чётный массив пар `[k,v,k,v]`. Если тип не совпадает → падение до парсинга структуры.

**EN:**  
Occurs on directive/donor type mismatch. `@%` expects object or single-element array `[{}]` (auto-unwrap). `@@` expects array. `@$` expects even-length `[k,v]` pairs. Type mismatch → halt before structure parsing.

**ZH:**  
指令与捐赠者类型不匹配时发生。`@%` 期望对象或单元素数组 `[{}]`（自动解包）。`@@` 期望数组。`@$` 期望偶数长度 `[k,v]` 对。类型不匹配 → 结构解析前终止。

**Пример / Example / 示例:**
```text
ERR_TYPE_MISMATCH: @% expects object or single-element array
ERR_TYPE_MISMATCH: @$ expects array [k, v, ...]
```

---

### `ERR_INVALID_SELECTOR` & `ERR_INDEX_OUT_OF_RANGE` / Селекторы массивов / 数组选择器
**RU:**  
`ERR_INVALID_SELECTOR` → синтаксис селектора нарушен: нечисловой индекс, диапазон без `..`, зарезервированные токены.  
`ERR_INDEX_OUT_OF_RANGE` → запрошенный индекс `>= length` или `< 0`. Для диапазонов `s..e` граница проверяется на каждой итерации.

**EN:**  
`ERR_INVALID_SELECTOR` → selector syntax broken: non-numeric index, range without `..`, reserved tokens.  
`ERR_INDEX_OUT_OF_RANGE` → requested index `>= length` or `< 0`. For `s..e` ranges, bounds checked on every iteration.

**ZH:**  
`ERR_INVALID_SELECTOR` → 选择器语法错误：非数字索引、无 `..` 的范围、保留标记。  
`ERR_INDEX_OUT_OF_RANGE` → 请求的索引 `>= length` 或 `< 0`。对于 `s..e` 范围，每次迭代检查边界。

**Пример / Example / 示例:**
```text
ERR_INVALID_SELECTOR: index 'list'
ERR_INVALID_SELECTOR: non-numeric range 'a..b'
ERR_INDEX_OUT_OF_RANGE: index 5 in file://data.json
```

---

### `ERR_EMPTY_DONOR` / Пустой источник / 空数据源
**RU:**  
Триггерится, когда `@%` или `@@` получает пустой массив `[]`, или glob-маска не находит файлов, или протокол возвращает пустой контент. Ядро не подставляет `null` или `{}`. Пайплайн обязан блокироваться.

**EN:**  
Triggered when `@%` or `@@` receives empty array `[]`, glob finds no files, or protocol returns empty content. Core does not inject `null` or `{}`. Pipeline must block.

**ZH:**  
当 `@%` 或 `@@` 接收空数组 `[]`、glob 未找到文件、或协议返回空内容时触发。核心不注入 `null` 或 `{}`。流水线必须阻断。

**Пример / Example / 示例:**
```text
ERR_EMPTY_DONOR: empty array cannot provide key '"parts"'
ERR_EMPTY_DONOR: @% cannot extract key from empty array
```

---

### `ERR_FILE_NOT_FOUND` / `ERR_DIR_NOT_FOUND` / Файлы и Директории / 文件与目录
**RU:**  
Возникает на уровне протокола `file://` при отсутствии ресурса после резолва `${VAR}`. Проверяется существование, права на чтение, валидность относительного пути. Директория без совпадений для `@@` → `ERR_DIR_NOT_FOUND` или `ERR_EMPTY_DONOR`.

**EN:**  
Occurs at `file://` protocol level when resource missing after `${VAR}` resolution. Checks existence, read permissions, relative path validity. Directory with no glob matches → `ERR_DIR_NOT_FOUND` or `ERR_EMPTY_DONOR`.

**ZH:**  
在 `${VAR}` 解析后，`file://` 协议层资源缺失时发生。检查存在性、读取权限、相对路径有效性。glob 无匹配的目录 → `ERR_DIR_NOT_FOUND` 或 `ERR_EMPTY_DONOR`。

**Пример / Example / 示例:**
```text
ERR_FILE_NOT_FOUND: /home/jsonmod/jsonmod/test/donors/phantom.json
ERR_DIR_NOT_FOUND: glob pattern matched zero files
```

---

### `ERR_INVALID_URI` / `ERR_UNSUPPORTED_PROTOCOL` / Протоколы / 协议
**RU:**  
`ERR_INVALID_URI` → отсутствует `://` в строке URI.  
`ERR_UNSUPPORTED_PROTOCOL` → схема не найдена в `fetchByScheme`. В v0.2 активен только `file://`. Остальные схемы отклоняются в `default` ветке `switch`.

**EN:**  
`ERR_INVALID_URI` → missing `://` in URI string.  
`ERR_UNSUPPORTED_PROTOCOL` → scheme not found in `fetchByScheme`. In v0.2 only `file://` is active. Other schemes rejected in `switch` default branch.

**ZH:**  
`ERR_INVALID_URI` → URI 字符串中缺少 `://`。  
`ERR_UNSUPPORTED_PROTOCOL` → 协议未在 `fetchByScheme` 中找到。v0.2 仅激活 `file://`。其他协议在 `switch` default 分支拒绝。

**Пример / Example / 示例:**
```text
ERR_INVALID_URI: missing scheme
ERR_UNSUPPORTED_PROTOCOL: s3
```

---

## 🛡️ Error Handling Patterns / Паттерны обработки / 错误处理模式

### 1. CI/CD Fail-Fast / Быстрый сбой в пайплайне
**RU:**  
Перехват `STDERR` и кода возврата `1`. Блокировка деплоя при любой диагностике.  
**EN:**  
Capture `STDERR` and exit code `1`. Block deploy on any diagnostic.  
**ZH:**  
捕获 `STDERR` 和退出码 `1`。任何诊断均阻断部署。

```bash
if ! cat template.jsonmod | ./jsonmod > out.json 2>err.log; then
  echo "❌ Build failed: $(cat err.log)"
  exit 1
fi
```

### 2. Perl / Mojolicious Integration / Интеграция в Perl
**RU:**  
Обёртка в `eval`. Классификация ошибок по HTTP-кодам. Возврат структурированного JSON вместо сырой 500-страницы.  
**EN:**  
Wrap in `eval`. Classify errors by HTTP codes. Return structured JSON instead of raw 500 page.  
**ZH:**  
使用 `eval` 包装。按 HTTP 状态码分类错误。返回结构化 JSON 而非原始 500 页面。

```perl
eval { $c->jsonmod->run('conf.tpl') };
if ($@) {
  my $code = $@ =~ /ERR_KEY_NOT_FOUND|ERR_FILE_NOT_FOUND/ ? 400 : 500;
  return $c->render(json => { error => "$@" }, status => $code);
}
```

### 3. Диагностика путей / Path Debugging / 路径调试
**RU:**  
При `ERR_KEY_NOT_FOUND: path 'a/b/c'` проверить: 1) существование `a`, 2) тип `b` (должен быть объект), 3) наличие `c`. Промежуточные узлы не объекты → `ERR_TYPE_MISMATCH`.  
**EN:**  
On `ERR_KEY_NOT_FOUND: path 'a/b/c'` check: 1) `a` exists, 2) `b` type (must be object), 3) `c` present. Intermediate non-objects → `ERR_TYPE_MISMATCH`.  
**ZH:**  
遇到 `ERR_KEY_NOT_FOUND: path 'a/b/c'` 时检查：1) `a` 存在，2) `b` 类型（必须为对象），3) `c` 存在。中间节点非对象 → `ERR_TYPE_MISMATCH`。

---

> 💡 **Золотое правило диагностики / Golden Diagnostic Rule / 诊断黄金法则**  
> `jsonmod` не угадывает и не кеширует. Каждый запуск — чистая трансформация.  
> Ошибка = фатальный сбой пайплайна. Нет fallback-значений. Нет `null` по умолчанию.  
> Валидируйте доноров до вызова, перехватывайте `STDERR`, блокируйте деплой на `exit 1`.  
> Строгость = надёжность инфраструктуры.