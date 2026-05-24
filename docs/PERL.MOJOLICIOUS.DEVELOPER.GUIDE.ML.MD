#  Mojolicious Integration Guide / Руководство по интеграции с Mojolicious / Mojolicious 集成指南

> Формат: `RU | EN | ZH`. Только пользовательский слой. Без архитектуры драйвера, сборки и C-ABI.  
> Драйвер: `drivers/perl/` (XS-модуль `JSONmod`).  
> Фреймворк: Mojolicious (PSGI, контроллеры, хелперы, плагины).

---

## 📥 Подключение модуля / Module Import / 模块引入

**RU:**  
Драйвер компилируется из `drivers/perl/`. После `make install` или локальной сборки модуль доступен через `use JSONmod`. Точное имя функции (`run`, `resolve`, `process`) зависит от экспорта в `JSONmod.xs`. В примерах используется `JSONmod::run($template)`.

**EN:**  
Driver builds from `drivers/perl/`. After `make install` or local build, module available via `use JSONmod`. Exact function name (`run`, `resolve`, `process`) depends on export in `JSONmod.xs`. Examples use `JSONmod::run($template)`.

**ZH:**  
驱动从 `drivers/perl/` 编译。`make install` 或本地构建后，通过 `use JSONmod` 可用模块。确切函数名（`run`、`resolve`、`process`）取决于 `JSONmod.xs` 中的导出。示例使用 `JSONmod::run($template)`。

```perl
package MyApp;
use Mojolicious::Lite;
use JSONmod;  # XS-драйвер / XS driver / XS 驱动
```

---

## 🎛️ Базовый контроллер / Basic Controller / 基础控制器

**RU:**  
Стандартный роут читает шаблон, вызывает ядро, отдаёт JSON. Ошибки перехватываются через `eval` → HTTP 400/500.

**EN:**  
Standard route reads template, calls core, returns JSON. Errors caught via `eval` → HTTP 400/500.

**ZH:**  
标准路由读取模板，调用核心，返回 JSON。通过 `eval` 捕获错误 → HTTP 400/500。

```perl
get '/api/config' => sub {
    my $c = shift;

    # 1. Шаблон (из файла, кэша или запроса)
    my $tpl = $c->app->home->rel_file('conf/service.jsonmod')->slurp;

    # 2. Вызов ядра
    my $json;
    eval {
        $json = JSONmod::run($tpl);
    };
    if ($@) {
        # RU: Валидация/резолв не прошли
        # EN: Validation/resolve failed
        # ZH: 验证/解析失败
        return $c->render(json => { error => 'Template resolution failed', details => "$@" }, status => 400);
    }

    # 3. Успешный ответ
    $c->render(json => decode_json($json), status => 200);
};
```

---

## 🧩 Хелпер для переиспользования / Reusable Helper / 可复用辅助方法

**RU:**  
Оберните вызов в `$c->helper` чтобы не дублировать `eval` и логику путей в каждом роуте.

**EN:**  
Wrap call in `$c->helper` to avoid duplicating `eval` and path logic in every route.

**ZH:**  
将调用封装到 `$c->helper` 中，避免在每个路由中重复 `eval` 和路径逻辑。

```perl
# Регистрация хелпера в startup()
$app->helper(jsonmod => sub {
    my ($c, $template_path, $vars) = @_;
    
    # Подстановка переменных (опционально)
    my $tpl = $c->app->home->rel_file($template_path)->slurp;
    if ($vars) {
        $tpl =~ s/\$\{(\w+)\}/$vars->{$1} // "\${$1}"/ge;
    }

    my $result;
    eval { $result = JSONmod::run($tpl); };
    return $@ ? undef : decode_json($result);
});

# Использование в роуте
get '/api/env/:region' => sub {
    my $c = shift;
    my $region = $c->param('region') // 'eu-west';
    
    my $config = $c->jsonmod('conf/upstream.jsonmod', { REGION => $region });
    return $c->render(json => $config // { error => 'Invalid template' }, status => $config ? 200 : 400);
};
```

---

## 🛡️ Обработка ошибок в Mojolicious / Error Handling in Mojolicious / Mojolicious 错误处理

**RU:**  
XS-модуль бросает `die` при `ERR_KEY_NOT_FOUND`, `ERR_TYPE_MISMATCH` и т.д. В Mojolicious это должно превращаться в структурированный JSON-ответ, а не в 500-страницу отладки.

**EN:**  
XS module throws `die` on `ERR_KEY_NOT_FOUND`, `ERR_TYPE_MISMATCH`, etc. In Mojolicious, this must become a structured JSON response, not a debug 500 page.

**ZH:**  
XS 模块在 `ERR_KEY_NOT_FOUND`、`ERR_TYPE_MISMATCH` 等情况下抛出 `die`。在 Mojolicious 中，这应转换为结构化 JSON 响应，而非调试 500 页面。

```perl
sub safe_jsonmod {
    my ($c, $tpl) = @_;
    eval { JSONmod::run($tpl) };
    
    if ($@) {
        chomp(my $err = $@);
        
        # RU: Классификация ошибок для разных HTTP-кодов
        # EN: Classify errors for different HTTP codes
        # ZH: 分类错误以对应不同 HTTP 状态码
        my $status = 400;
        $status = 500 if $err =~ /ERR_INTERNAL|ERR_MEMORY|ERR_C_API/;
        
        $c->res->code($status);
        return $c->render(json => {
            error   => 'jsonmod_resolution_failed',
            code    => $1 if $err =~ /(ERR_\w+)/,
            message => $err
        });
    }
    return decode_json($@ ? undef : $@); # Упрощённо
}
```

---

## 📦 Плагин для централизации / Plugin for Centralization / 集中化插件

**RU:**  
Для крупных приложений вынесите инициализацию в `Mojolicious::Plugin::JSONmod`. Это позволит задавать базовые пути, перехватчики ошибок и режим валидации в одном месте.

**EN:**  
For large apps, move initialization to `Mojolicious::Plugin::JSONmod`. This allows setting base paths, error interceptors, and validation mode in one place.

**ZH:**  
对于大型应用，将初始化移至 `Mojolicious::Plugin::JSONmod`。这允许在一个位置设置基础路径、错误拦截器和验证模式。

```perl
package Mojolicious::Plugin::JSONmod;
use Mojo::Base 'Mojolicious::Plugin';
use JSONmod;

sub register {
    my ($self, $app, $conf) = @_;
    
    $app->helper('jsonmod.run' => sub {
        my ($c, $path, $ctx) = @_;
        my $full_path = $conf->{base_dir} ? "$conf->{base_dir}/$path" : $path;
        
        my $tpl = -f $full_path ? Mojo::File->new($full_path)->slurp : $path;
        $tpl =~ s/\$\{(\w+)\}/$ctx->{$1} // "\${$1}"/ge if $ctx;
        
        eval { JSONmod::run($tpl) };
        return $@ ? undef : decode_json($@ ? undef : $@);
    });
}
1;
```

**Подключение в `MyApp.pm`:**
```perl
sub startup {
    my $app = shift;
    $app->plugin('JSONmod' => { base_dir => $app->home->rel_dir('conf') });
    # Использование: $c->jsonmod->run('service.jsonmod', { ENV => 'prod' })
}
```

---

## ⚡ Рекомендации для Mojolicious / Mojolicious Best Practices / Mojolicious 最佳实践

| Правило / Rule / 规则 | Почему / Why / 原因 |
|----------------------|---------------------|
| **Не блокируйте event loop** | `jsonmod` работает синхронно. Для тяжёлых шаблонов используйте `$c->delay` или выносите в воркер. |
| **Всегда используйте `eval`** | XS-ошибки → `die`. Без перехвата Mojolicious вернёт сырую 500-страницу. |
| **Храните шаблоны в `conf/`** | Отделите `.jsonmod` от `templates/`. Mojolicious рендерит шаблоны отдельно от конфигов. |
| **Не кешируйте результат резолва** | `jsonmod` детерминирован, но доноры могут меняться. Резолвите при каждом запросе или используйте `Mojo::Cache` с TTL. |
| **Валидируйте пути до вызова** | `ERR_FILE_NOT_FOUND` → частая ошибка. Проверяйте `-f` перед вызовом `JSONmod::run`. |

---

## 🔍 Частые вопросы / FAQ / 常见问题

**RU:** Можно ли вызывать `jsonmod` асинхронно в Mojolicious?  
**EN:** Can `jsonmod` be called asynchronously in Mojolicious?  
**ZH:** 能否在 Mojolicious 中异步调用 `jsonmod`？  
> **RU:** Нет, XS-драйвер синхронен. Используйте `$c->delay->begin` или `Mojo::IOLoop->subprocess` для выноса в отдельный процесс, не блокируя loop.  
> **EN:** No, XS driver is synchronous. Use `$c->delay->begin` or `Mojo::IOLoop->subprocess` to offload to a child process without blocking the loop.  
> **ZH:** 不支持，XS 驱动是同步的。使用 `$c->delay->begin` 或 `Mojo::IOLoop->subprocess` 卸载到子进程，不阻塞事件循环。

**RU:** Как передать контекст из Mojolicious в шаблон?  
**EN:** How to pass context from Mojolicious to the template?  
**ZH:** 如何将上下文从 Mojolicious 传递到模板？  
> **RU:** Через heredoc-подстановку перед вызовом: `$tpl =~ s/\$\{VAR\}/$value/ge;`. Или храните `${VAR}` в шаблоне и подставляйте на уровне Perl до `JSONmod::run`.  
> **EN:** Via heredoc substitution before call: `$tpl =~ s/\$\{VAR\}/$value/ge;`. Or keep `${VAR}` in template and substitute at Perl level before `JSONmod::run`.  
> **ZH:** 调用前通过 heredoc 替换：`$tpl =~ s/\$\{VAR\}/$value/ge;`。或在模板中保留 `${VAR}`，在调用 `JSONmod::run` 前于 Perl 层替换。

---

> 💡 **Золотое правило:**  
> `jsonmod` в Mojolicious — это синхронный трансформер конфигов.  
> `Шаблон → eval { JSONmod::run } → JSON → $c->render`.  
> Ошибки → `400/500` с телом. Никаких `die` в production.  
> Храните `.jsonmod` в `conf/`, используйте хелперы, не кешируйте сырые результаты.

