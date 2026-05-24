# 📘 Perl Developer Guide / Руководство разработчика / Perl 开发者指南

> Практическое руководство по интеграции `jsonmod` в Perl-проекты через штатный драйвер.  
> Формат: `RU | EN | ZH`. Только пользовательский слой. Без архитектуры драйвера, сборки и C-ABI.  
> Принцип: `шаблон → вызов → JSON → обработка`.

---

## 📥 Установка и подключение / Install & Import / 安装与引入

**RU:**  
Установите модуль через CPAN или локальную сборку. Подключайте одной строкой. Никаких глобальных настроек или инициализации не требуется.

**EN:**  
Install via CPAN or local build. Load with a single line. No global config or init needed.

**ZH:**  
通过 CPAN 或本地构建安装模块。单行加载。无需全局配置或初始化。

```bash
# Установка / Install / 安装
cpanm JSONmod          # из репозитория
# или
cd drivers/perl && make install  # из исходников
```

```perl
# Подключение в коде / Import in code / 代码中引入
use strict;
use warnings;
use JSONmod;           # экспорт основного интерфейса
use JSON::PP;          # для декодирования результата (опционально)
```

---

## 🚀 Базовое использование / Basic Usage / 基础用法

**RU:**  
Основная функция принимает строку шаблона `.jsonmod` и возвращает валидный JSON. Всё резолвинг-ядро работает внутри драйвера. Вам не нужно управлять файлами, дескрипторами или памятью.

**EN:**  
Main function accepts a `.jsonmod` template string and returns valid JSON. All resolve logic runs inside the driver. No file/descriptor/memory management required.

**ZH:**  
主函数接受 `.jsonmod` 模板字符串并返回有效 JSON。所有解析逻辑在驱动内部运行。无需管理文件、描述符或内存。

```perl
use JSONmod;

my $template = q{
    ENV = "production"
    {
        "db_host": @%{"database/host"} "file://configs/deep.json",
        "features": @%{"new_ui", "beta_api"} "file://flags/prod.json"
    }
};

# Вызов / Call / 调用
my $json_string = JSONmod::resolve($template);

# Результат / Result / 结果
print $json_string;
# {"db_host":"10.0.1.10","features":{"new_ui":true,"beta_api":false}}
```

---

## 🛡️ Обработка ошибок / Error Handling / 错误处理

**RU:**  
Драйвер бросает исключения (`die`) при любой ошибке валидации, резолва или чтения файлов. Всегда оборачивайте вызов в `eval`. Ошибка содержит код (`ERR_KEY_NOT_FOUND`, `ERR_TYPE_MISMATCH` и т.д.) и контекст.

**EN:**  
Driver throws exceptions (`die`) on any validation, resolve, or file-read error. Always wrap in `eval`. Error contains code (`ERR_KEY_NOT_FOUND`, etc.) and context.

**ZH:**  
驱动在验证、解析或文件读取错误时抛出异常（`die`）。始终使用 `eval` 包装。错误包含代码（`ERR_KEY_NOT_FOUND` 等）和上下文。

```perl
eval {
    my $result = JSONmod::resolve($template);
    # успех → парсим или передаём дальше
    my $data = decode_json($result);
    print "✅ DB host: ", $data->{db_host}, "\n";
};
if ($@) {
    # Ошибка → логируем или фоллбэк
    chomp(my $err = $@);
    warn " jsonmod failed: $err\n";
    
    # Пример реакции на конкретный код
    if ($err =~ /ERR_KEY_NOT_FOUND/) {
        die "Конфиг неполный. Проверьте доноров.\n";
    }
}
```

---

##  Практические примеры / Practical Examples / 实用示例

### 1. Загрузка шаблона из файла / Load template from file / 从文件加载模板
```perl
use JSONmod;
use Path::Tiny;

my $template = path("configs/service.jsonmod")->slurp_utf8;
my $json = JSONmod::resolve($template);
```

### 2. Динамические переменные через heredoc / Dynamic vars via heredoc / 通过 heredoc 动态变量
```perl
my $region = "eu-west";
my $template = <<END;
REGION = "$region"
{"upstream": @@ "file://backends/\${REGION}_*.json"}
END

my $json = JSONmod::resolve($template);
```

### 3. Интеграция в PSGI/Plack / PSGI integration / PSGI 集成
```perl
use JSONmod;
use JSON::PP;

sub handle_request {
    my ($env) = @_;
    my $tpl = $env->{'psgi.input'}->getline;
    
    eval {
        my $json = JSONmod::resolve($tpl);
        return [200, ['Content-Type' => 'application/json'], [$json]];
    };
    if ($@) {
        return [400, ['Content-Type' => 'application/json'], [encode_json({error => "$@"})]];
    }
}
```

---

## ⚡ Рекомендации / Best Practices / 最佳实践

| Правило / Rule / 规则 | Почему / Why / 原因 |
|----------------------|---------------------|
| **Не кешируйте результат резолва** | `jsonmod` детерминирован, но доноры могут меняться. Резолвите при каждом запросе конфигурации. |
| **Всегда используйте `eval`** | Драйвер строгий: отсутствующий файл или ключ → `die`. Без `eval` приложение упадёт. |
| **Разделяйте шаблоны и данные** | Храните `.jsonmod` в `conf/`, доноров в `data/`. Не генерируйте шаблоны на лету из пользовательского ввода. |
| **Проверяйте пути до вызова** | `ERR_FILE_NOT_FOUND` → частая ошибка в deploy. Валидируйте существование директорий через `-d`/`-f`. |
| **Используйте `@%{}` для полных объектов** | Если нужен весь донор без фильтрации → `@%{}`. Быстрее и чище, чем перечислять ключи. |

---

## 🔍 Частые вопросы / FAQ / 常见问题

**RU:** Можно ли передать JSON прямо в память, без файла?  
**EN:** Can I pass JSON directly in memory, without files?  
**ZH:** 能否不通过文件直接传递内存中的 JSON？  
> **RU:** Нет. Драйвер работает только с `file://` URI. Для ин-мемори используйте `tmpfile` или `open` в `/dev/shm`. Это гарантирует стабильность резолва.  
> **EN:** No. Driver only supports `file://` URI. For in-memory, use `tmpfile` or `/dev/shm`. Ensures resolve stability.  
> **ZH:** 不支持。驱动仅支持 `file://` URI。内存数据请使用 `tmpfile` 或 `/dev/shm`。保障解析稳定性。

**RU:** Как отключить строгие ошибки и получить `null` вместо `die`?  
**EN:** How to disable strict errors and get `null` instead of `die`?  
**ZH:** 如何关闭严格错误，返回 `null` 而非 `die`？  
> **RU:** Никак. Архитектура запрещает молчаливые пропуски. Используйте `eval` + fallback-логику в Perl.  
> **EN:** Impossible. Architecture forbids silent skips. Use `eval` + Perl fallback logic.  
> **ZH:** 不可行。架构禁止静默跳过。请使用 `eval` + Perl 回退逻辑。

**RU:** Работает ли драйвер в `mod_perl` / `FastCGI`?  
**EN:** Does it work in `mod_perl` / `FastCGI`?  
**ZH:** 是否支持 `mod_perl` / `FastCGI`？  
> **RU:** Да. Драйвер не хранит глобальное состояние между запросами. Каждый вызов изолирован.  
> **EN:** Yes. Driver holds no global state between requests. Each call is isolated.  
> **ZH:** 支持。驱动在请求间不保留全局状态。每次调用完全隔离。

---

> 💡 **Золотое правило:**  
> `JSONmod` для Perl — это чёрный ящик резолва.  
> Вы даёте шаблон → получаете JSON → ловите ошибки через `eval`.  
> Не лезьте внутрь. Не кешируйте. Валидируйте пути. Строгость = надёжность.
