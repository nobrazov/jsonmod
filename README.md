![jsonmod logo](logo.png)

# jsonmod / Модульный JSON-движок / 模块化 JSON 引擎

Детерминированная сборка валидных JSON-конфигураций через STDIN/STDOUT. Без состояния. Строгая композиция модулей. C-ABI.
Deterministic assembly of valid JSON configurations via STDIN/STDOUT. Stateless. Strict module composition. C-ABI.
通过 STDIN/STDOUT 确定性组装有效 JSON 配置。无状态。严格的模块组合。C-ABI。

##📖 Обзор / Overview / 概述

RU:`jsonmod` — это модульная система композиции JSON. Шаблоны и файловые источники выступают независимыми модулями, которые собираются в единую, строго типизированную структуру до старта процесса. Ядро читает поток из STDIN, резолвит связи и переменные, и отдаёт готовый валидный JSON в STDOUT.

EN:`jsonmod` is a modular JSON composition system. Templates and file sources act as independent modules, assembled into a single, strictly typed structure before process startup. The core reads the stream from STDIN, resolves links and variables, and outputs ready, valid JSON to STDOUT. Each run is a clean data transformation with no state retention or caching.

ZH:`jsonmod` 是一个模块化 JSON 组合系统。模板和文件源作为独立模块，在进程启动前组装为单一、严格类型的结构。核心从 STDIN 读取流，解析链接和变量，并将准备好的有效 JSON 输出至 STDOUT。每次运行都是干净的数据转换，不保留状态，不缓存。

## Быстрый старт / Quick Start / 快速启动

```bash
cat template.jsonmod | ./jsonmod > output.json
```
Без флагов / No flags / 无标志
Без аргументов / No arguments / 无参数
Ввод → `jsonmod` → Вывод / Input → `jsonmod` → Output / 输入 → `jsonmod` → 输出
Результат: валидный JSON / Result: valid JSON / 结果：有效 JSON

## 🏗 Принципы / Principles / 原则

| Принцип / Principle / 原则 | Описание / Description / 说明 |
| --- | --- |
| Модульная композиция <br> Modular Composition / 模块化组合 | @% ,  @@ ,  @$  — операторы сборки. Файлы = модули. Связи = URI. <br> @%, @@, @$ — assembly operators. Files = modules. Links = URI. <br> @%、@@、@$ — 组装操作符。文件 = 模块。链接 = URI。 |
| Без состояния <br> Stateless / 无状态 | Каждый запуск — чистая трансформация. Глобальный реестр сбрасывается. <br> Each run is a clean transformation. Global registry resets. <br> 每次运行都是干净的转换。全局注册表重置。 |
| Детерминизм <br> Deterministic / 确定性 | Одинаковые входы → идентичный вывод. Хеш конфига стабилен. <br> Same inputs → identical outputs. Config hash is stable. <br> 相同的输入 → 相同的输出。配置哈希值稳定。 |
| C-ABI ядро <br> C-ABI Core / C-ABI 核心 | `jsonmod_run(int in_fd, int out_fd, char* err_buf, size_t err_len)`. Интеграция через FFI. <br> Integration via FFI. <br> 通过 FFI 集成。 |
| Валидный вывод <br> Valid Output / 有效输出 | Ядро гарантирует строго корректный JSON на STDOUT после сборки. <br> Core guarantees strictly correct JSON on STDOUT after assembly. <br> 核心保证组装后在 STDOUT 上输出严格正确的 JSON。 |

## 🔧 Операторы / Operators / 操作符

| Оператор / Operator / 操作符 | Назначение / Purpose / 用途 | Пример / Example / 示例 |
| --- | --- | --- |
| `@%{ "key" }` / `@%{ "a/b/c" }` | Извлечение объекта или значения по ключу/пути <br> Extract object or value by key/path <br> 按键/路径提取对象或值 | `@%{ "db/host" }` `file://conf.json` |
| `@@` / `@@{start..end}` | Слияние массивов или срез по индексу <br> Merge arrays or slice by index <br> 合并数组或按索引切片 | `@@` `file://backends/*.json` |
| `@$` | Преобразование плоского списка `[k,v]` в объект <br> Transform flat list `[k,v]` into object <br> 将扁平列表 `[k,v]` 转换为对象 | `@$` `file://pairs.json` |
| `${VAR}` | Подстановка контекста в URI и контент <br> Context substitution in URI and content <br> 在 URI 和内容中替换上下文 | `file://configs/${ENV}.json` |
| `.jsonmo` | Рекурсивная подстановка внутри модуля <br> Recursive substitution within module <br> 模块内递归替换 | `file://secrets.jsonmo` |

## Протокол / Protocol / 协议: `file://`.

## 🔌 Интеграция / Integration / 集成

**Ядро / Core / 核心**

RU: Экспорт через C-ABI. Подключение напрямую из любого языка с поддержкой FFI.
EN: Export via C-ABI. Direct linking from any FFI-capable language.
ZH: 通过 C-ABI 导出。从任何支持 FFI 的语言直接链接。

```c
int jsonmod_run(int in_fd, int out_fd, char* err_buf, size_t err_len);
// Возврат / Return / 返回: 0 = успех
```

**Языки / Languages / 语言**

| Язык / Language / 语言 | Способ / Method / 方法 | Пример / Example / 示例 |
| --- | --- | --- |
| CLI | Конвейер / Pipeline / 管道 | `cat tpl.jsonmod \| ./jsonmod > out.json` |
| Perl | XS-драйвер в `drivers/perl/` <br> XS driver in `drivers/perl/` <br> `drivers/perl/` 中的 XS 驱动 | `use JSONmod; my $j = JSONmod::run($tpl);` |
| Python | `ctypes` / `cffi` | `lib.jsonmod_run(0, 1, None, 0)` |
| Go | `cgo` с `#include "jsonmod.h"` | `C.jsonmod_run(C.int(0), C.int(1), nil, 0)` |
| Java | JNA (Java Native Access) | `Native.load("jsonmod", JsonmodAPI.class)` |

## 🛠 Сборка / Build / 构建

```bash
make               # CLI-бинарь / CLI binary / CLI 二进制
make test          # Приемочные тесты / Acceptance tests / 验收测试
make clean         # Очистка / Clean / 清理
```

## Требования / Requirements / 依赖: `gdc`/`ldc2` ≥ 1.30, `libjson-c-dev` ≥ 0.17, `gcc`/`clang`, `bash`.

## Документация / Documentation / 文档

Справочники в `docs/` (формат `UPPERCASE.ML.MD`, RU | EN | ZH):

| Файл / File / 文件 | Описание / Description / 说明 |
| --- | --- |
| `USE.CASES.ML.MD` | Практические сценарии по ролям <br> Practical use cases by roles <br> 按角色的实用案例 |
| `CLI.REFERENCE.ML.MD` | Команды, пайпы, интеграция <br> Commands, pipes, integration <br> 命令、管道、集成 |
| `ERRORS.ML.MD` | Диагностика кодов сбоев и фиксы <br> Failure codes diagnosis and fixes <br> 故障代码诊断与修复 |
| `SECURITY.ML.MD` | Эксплуатация, харденинг, чеклист <br> Operation, hardening, checklist <br> 运行、加固、检查清单 |
| `PERL.DEVELOPER.GUIDE.ML.MD` | Использование XS-драйвера <br> Using the XS driver <br> 使用 XS 驱动 |
| `PERL.MOJOLICIOUS.DEVELOPER.GUIDE.ML.MD` | Интеграция в контроллеры/хелперы <br> Integration into controllers/helpers <br> 集成到控制器/辅助函数 |
| `LANGUAGE.REFERENCE.MD` | Справочник команд <br> Command reference <br> 命令参考 |

## Лицензии / Licenses / 许可协议

| Лицензия / License / 许可证 | Назначение / Purpose / 用途 | Файл / File / 文件 |
| --- | --- | --- |
| GPL v3 | Свободное использование с открытием исходников <br> Free use with open sourcing <br> 开源免费使用 | `LICENSE.GPL3` |
| FDL 1.3 | Документация и справочники <br> Documentation and references <br> 文档和参考资料 | `LICENSE.FDL13` |
| AS-IS | Использование "как есть" без гарантий <br> Use "as is" without warranty <br> “原样”使用，不保修 | `LICENSE.AS-IS` |
| Commercial | Закрытое внедрение, поддержка, кастомные фичи <br> Closed deployment, support, custom features <br> 闭源部署、支持、定制功能 | `LICENSE.COMMERCIAL.md` |

RU: Проект распространяется под тройной лицензией. Выберите подходящую: GPL v3 (открытые изменения), FDL 1.3 (документация), AS-IS (внутреннее использование), Commercial (закрытые решения).
EN: Project is distributed under a triple license. Choose one: GPL v3 (open modifications), FDL 1.3 (documentation), AS-IS (internal use), Commercial (closed solutions).
ZH: 项目采用三重许可分发。请选择适用的一项：GPL v3（开源修改）、FDL 1.3（文档）、AS-IS（内部使用）、Commercial（闭源解决方案）。

📬 Commercial-запросы / Commercial inquiries / 商业咨询:

`nobrazov@list.ru` | DingTalk: `aqd-hvkkk0xex` | GitHub Issues: `type:commercial`

## 📜 Статус / Status / 状态
Версия / Version / 版本: `0.2`
Архитектура / Architecture / 架构: D + `libjson-c`
Протокол / Protocol / 协议: `file://`
Лицензия / License / 许可证: GPLv3+Commerce

## Поддержка / Support / 支持

RU: Проект развивается силами сообщества. Если `jsonmod` полезен — поддержите разработку.
EN: Project is community-driven. If `jsonmod` helps you — consider supporting development.
ZH: 项目由社区驱动。如果 `jsonmod` 对您有帮助 — 请考虑支持开发。

| Платформа / Platform / 平台 | Ссылка / Link / 链接 |
| --- | --- |
| ЮMoney | [https://yoomoney.ru/to/4100118167547949](https://yoomoney.ru/to/4100118167547949) |
| CloudTips | [https://pay.cloudtips.ru/p/b9b3f72c](https://pay.cloudtips.ru/p/b9b3f72c) |
| Donatty | [https://donatty.com/itpjuzel](https://donatty.com/itpjuzel) |

## 📬 Контакты / Contacts / 联系

| Канал / Channel / 渠道 | Контакт / Contact / 联系方式 |
| --- | --- |
| GitHub Issues | [github.com/nobrazov/jsonmod/issues](https://github.com/nobrazov/jsonmod/issues) |
| Email | `nobrazov@list.ru` |
| DingTalk | `aqd-hvkkk0xex` |

Золотое правило / Golden Rule / 黄金法则

`jsonmod` собирает модули в единый валидный JSON.
Детерминизм + строгая типизация = предсказуемая конфигурация.

`jsonmod` assembles modules into a single valid JSON.
Determinism + strict typing = predictable configuration.

`jsonmod` 将模块组装为单一有效 JSON。
确定性 + 严格类型 = 可预测的配置。

© 2026 jsonmod contributors. GPL v3 License.