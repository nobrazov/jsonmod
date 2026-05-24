# CONTRIBUTING.md / Правила контрибуции / 贡献规则

> **Внимание / Warning / 警告**  
> Это проект с единоличным управлением. Автор — финальная инстанция.  
> **This is a single-maintainer project. The author has final authority.**  
> **本项目为单人维护。作者拥有最终决定权。**

---

## ⚡ Коротко / TL;DR / 速览

| Действие / Action / 行为 | Результат / Result / 结果 |
|-------------------------|--------------------------|
| ❌ Спорить с архитектурой | Мёрдж отклонён + бан на 24ч |
| ❌ Пушить без `make test` | PR закрыт без чтения |
| ❌ Менять API без согласования | Ревью остановлено, предупреждение |
| ❌ Токсичность в 이슈х | Мгновенный перманентный бан |
| ✅ Чёткий баг-репорт + фикс | Мёрдж + спасибо |
| ✅ Предварительный дизкус в Issue | Одобрение + коллаборация |

---

## 🚫 Жёсткие правила / Hard Rules / 硬性规则

### 1. Архитектура не обсуждается / Architecture is not negotiable / 架构不可协商
**RU:**  
Решения по ядру (`merger.d`, `lexer.d`, C-ABI) принимает автор. Если ты не согласен с `pipe-only`, `stateless` или `strict validation` — форкни проект. Не трать время на споры.

**EN:**  
Core decisions (`merger.d`, `lexer.d`, C-ABI) are made by the author. If you disagree with `pipe-only`, `stateless`, or `strict validation` — fork the project. Do not waste time arguing.

**ZH:**  
核心决策（`merger.d`、`lexer.d`、C-ABI）由作者决定。如果您不同意 `pipe-only`、`stateless` 或 `strict validation` — 请 fork 项目。不要浪费时间争论。

### 2. Код без тестов = мусор / Code without tests = trash / 无测试代码 = 垃圾
**RU:**  
Любой PR обязан проходить `make test`. Нет новых тестов для новой фичи? Закрою сразу. Сломаешь существующий тест? Отклоню без ревью.

**EN:**  
Every PR must pass `make test`. No new tests for a new feature? Closed immediately. Break an existing test? Rejected without review.

**ZH:**  
每个 PR 必须通过 `make test`。新功能无新测试？立即关闭。破坏现有测试？无需审查直接拒绝。

### 3. Один фокус за раз / One focus per PR / 一个 PR 一个焦点
**RU:**  
Не смешивай рефакторинг, фичи и фиксы в одном пулл-реквесте. Хочешь поменять стиль кода? Отдельный PR. Хочешь добавить протокол? Отдельный PR + предварительное обсуждение в Issue.

**EN:**  
Do not mix refactoring, features, and fixes in one PR. Want to change code style? Separate PR. Want to add a protocol? Separate PR + prior discussion in Issue.

**ZH:**  
不要在一个 PR 中混用重构、新功能和修复。想改代码风格？单独开 PR。想加协议？单独开 PR + 先在 Issue 中讨论。

### 4. Токсичность = бан / Toxicity = ban / 有毒言论 = 封禁
**RU:**  
Оскорбления, пассивная агрессия, «а почему вы не используете Х» без контекста — мгновенный бан. Хочешь покритиковать? Предложи конкретный патч с обоснованием. Нет патча — нет разговора.

**EN:**  
Insults, passive aggression, "why don't you use X" without context — instant ban. Want to criticize? Provide a concrete patch with rationale. No patch — no discussion.

**ZH:**  
侮辱、被动攻击、无上下文的「为什么不用 X」— 立即封禁。想批评？请提供具体补丁并说明理由。无补丁 — 不讨论。

---

## ✅ Как внести вклад / How to Contribute / 如何贡献

### Шаг 1: Открой Issue / Open an Issue / 先开 Issue
**RU:**  
Перед кодом — опиши задачу. Шаблон:
```
[TYPE] Краткое описание
- Что ломаю/чиню:
- Почему это нужно:
- Как протестирую:
- Совместимость с текущим API: [да/нет]
```
Типы: `bug`, `feature`, `docs`, `perf`, `wontfix` (для дискуссий).

**EN:**  
Before coding — describe the task. Template:
```
[TYPE] Brief description
- What I break/fix:
- Why it's needed:
- How I'll test:
- API compatibility: [yes/no]
```
Types: `bug`, `feature`, `docs`, `perf`, `wontfix` (for discussions).

**ZH:**  
写代码前先描述任务。模板：
```
[类型] 简要描述
- 我修复/破坏的内容：
- 为什么需要：
- 如何测试：
- API 兼容性：[是/否]
```
类型：`bug`、`feature`、`docs`、`perf`、`wontfix`（用于讨论）。

### Шаг 2: Жди апрува / Wait for approval / 等待批准
**RU:**  
Автор ответит: ✅ (делай), ❌ (не нужно), 🤔 (обсуди детали). Не начинай кодировать до ✅. Исключение: опечатки в доках — можно пушить сразу.

**EN:**  
Author will reply: ✅ (go ahead), ❌ (not needed), 🤔 (discuss details). Do not start coding before ✅. Exception: typos in docs — push immediately.

**ZH:**  
作者将回复：✅（继续）、❌（不需要）、🤔（讨论细节）。在收到 ✅ 前不要开始编码。例外：文档错别字 — 可直接提交。

### Шаг 3: Пиши код / Write code / 编写代码
**Требования / Requirements / 要求:**
- **RU:** Форматируй через `dfmt -i`. Комментируй сложные места. Не добавляй зависимости без согласования.
- **EN:** Format with `dfmt -i`. Comment complex logic. Do not add dependencies without approval.
- **ZH:** 使用 `dfmt -i` 格式化。为复杂逻辑添加注释。未经批准不得添加依赖。

### Шаг 4: Тесты и пуш / Tests and push / 测试并提交
```bash
make clean && make && make test
# Все 50 тестов зелёные? Тогда:
git commit -S -m "[TYPE] description (#IssueID)"
git push fork/branch
# Открывай PR. Ссылка на апрувнутый Issue — в описании.
```

---

## 🔨 Что автор мёржит / What the author merges / 作者合并的内容

| Тип / Type / 类型 | Шанс мёрджа / Merge chance / 合并概率 | Условия / Conditions / 条件 |
|------------------|-------------------------------------|----------------------------|
| 🐛 Багфикс ядра | ✅ Высокий | + тест на регрессию, не ломает API |
| 📚 Документация | ✅ Высокий | Без изменения смысла, формат `.ML.MD` |
| ⚡ Оптимизация | 🤔 Средний | Бенчмарки + доказательство, что не ломает детерминизм |
| 🔌 Новый протокол | 🤔 Средний | Предварительный дизкус в Issue + пример использования |
| 🎨 Рефакторинг | ❌ Низкий | Только если не меняет поведение + 100% покрытие тестами |
| 💡 Новая фича | ❌ Низкий | Только после апрува архитектуры в Issue |

---

## ⚡ Бан-политика / Ban Policy / 封禁政策

**RU:**  
Автор оставляет за собой право забанить любого участника без объяснения причин. На практике бан применяется за:
- Повторное игнорирование правил после предупреждения
- Агрессия, троллинг, спам
- Попытки продавить архитектурные изменения через давление
- Публикация уязвимостей без ответственного раскрытия (сначала автору в личку)

**Бан =** отзыв прав на форк-репозиторий (если есть), блокировка в организации, игнор будущих PR.

**EN:**  
The author reserves the right to ban any contributor without explanation. In practice, bans are issued for:
- Repeated rule violations after warning
- Aggression, trolling, spam
- Attempting to force architectural changes through pressure
- Publishing vulnerabilities without responsible disclosure (contact author first)

**Ban =** revocation of fork repo access (if applicable), org block, ignoring future PRs.

**ZH:**  
作者保留无需解释即可封禁任何贡献者的权利。实践中，封禁适用于：
- 警告后重复违反规则
- 攻击、挑衅、垃圾信息
- 试图通过施压强行推动架构变更
- 未负责任披露即发布漏洞（请先私信作者）

**封禁 =** 撤销 fork 仓库权限（如适用）、组织内拉黑、忽略未来 PR。

---

## 📬 Связь с автором / Contact the author / 联系作者

| Канал / Channel / 渠道 | Для чего / Purpose / 用途 | Ответ / Response / 响应 |
|-----------------------|--------------------------|------------------------|
| 🐙 **GitHub Issues** | Баги, фичи, вопросы по коду | 1–3 дня (рабочие) |
| 📧 **Email** | Коммерческие запросы, уязвимости | ≤ 24 часа |
| 💬 **DingTalk** | Быстрые уточнения (только после апрува в Issue) | По наличию времени |
| ❌ **Личные сообщения в соцсетях** | Игнорируются | Нет ответа |

**RU:**  
Не пиши «привет, есть вопрос». Пиши сразу суть: ссылка на код/лог/тест + конкретный вопрос. Нет контекста — нет ответа.

**EN:**  
Do not write "hi, got a question". Write the essence immediately: link to code/log/test + concrete question. No context — no answer.

**ZH:**  
不要写「你好，有个问题」。请直接写重点：代码/日志/测试链接 + 具体问题。无上下文 — 无回复。

---

> 💡 **Финальное правило / Final Rule / 最终规则**  
> `jsonmod` — это инструмент, а не демократия.  
> Хочешь влиять на развитие? Предоставляй код, тесты, аргументы.  
> Не готов соблюдать правила? Форк — твоё право.  
>  
> `jsonmod` is a tool, not a democracy.  
> Want to influence development? Provide code, tests, arguments.  
> Not ready to follow the rules? Fork is your right.  
>  
> `jsonmod` 是工具，不是民主。  
> 想影响项目发展？请提供代码、测试、论据。  
> 不愿遵守规则？Fork 是你的权利。

---

```
© 2026 jsonmod contributors. Contributing = accepting these rules.
```