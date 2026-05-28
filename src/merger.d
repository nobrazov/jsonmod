// merger.d — Конвейерная сборка: декомпозиция → json-c парсинг → централизованный резолв
// Pipeline assembly: decomposition → json-c parsing → centralized resolve
// 管道组装：分解 → json-c 解析 → 集中式解析
module merger;

// --- Импорт стандартных модулей / Standard library imports / 标准库导入
// RU: std.string, std.array, std.algorithm для строк/массивов; std.json для D-дерева
// EN: std.string, std.array, std.algorithm for strings/arrays; std.json for D-tree
// ZH: std.string, std.array, std.algorithm 用于字符串/数组；std.json 用于 D 树
import std.string, std.array, std.algorithm, std.exception, std.conv, std.json;
import protocols.file;
import core.stdc.string : strlen;
import logger;

// --- D-дескрипторы (непрозрачные указатели на C-структуры json-c)
// RU: Opaque handles. Память управляется libjson-c, D GC не вмешивается.
// EN: Opaque handles. Memory managed by libjson-c, D GC untouched.
// ZH: 不透明句柄。内存由 libjson-c 管理，D GC 不干预。
struct JMObject {}
struct JMTokener {}

// --- Константы типов json-c (анонимный enum → int, совместимо с C-ABI)
// RU: Сопоставлены с enum json_type из json_object.h
// EN: Matched with enum json_type from json_object.h
// ZH: 与 json_object.h 中的 enum json_type 匹配
enum {
	JM_TYPE_NULL   = 0,
	JM_TYPE_BOOLEAN= 1,
	JM_TYPE_DOUBLE = 2,
	JM_TYPE_INT    = 3,
	JM_TYPE_OBJECT = 4,
	JM_TYPE_ARRAY  = 5,
	JM_TYPE_STRING = 6
}

// --- json-c C-API bindings (строго по документации json-c 0.17+)
// RU: Имена сохранены для линковки. Типы приведены к JMObject/JMTokener.
// EN: Names kept for linking. Types mapped to JMObject/JMTokener.
// ZH: 保留函数名用于链接。类型映射为 JMObject/JMTokener。
extern(C) {
	int json_object_get_type(JMObject* obj);
	const(char)* json_object_get_string(JMObject* obj);
	int json_object_object_get_ex(JMObject* obj, const(char)* key, JMObject** val);
	int json_object_object_add(JMObject* obj, const(char)* key, JMObject* val);
	int json_object_object_del(JMObject* obj, const(char)* key);
	size_t json_object_array_length(JMObject* obj);
	JMObject* json_object_array_get_idx(JMObject* obj, size_t idx);
	int json_object_array_put_idx(JMObject* obj, size_t idx, JMObject* val);
	void json_object_put(JMObject* obj);
	void json_object_get(JMObject* obj);
	const(char)* json_object_to_json_string(JMObject* obj);
	JMObject* json_object_new_object();
	JMObject* json_object_new_array();
	int json_object_array_add(JMObject* obj, JMObject* val);

	JMTokener* json_tokener_new();
	JMObject* json_tokener_parse_ex(JMTokener* tok, const(char)* str, int len);
	void json_tokener_free(JMTokener* tok);
	int json_tokener_get_error(JMTokener* tok);
	const(char)* json_tokener_error_desc(int err);
}

// --- Слой состояния: Три независимых реестра / State Layer: Three independent registries / 状态层：三个独立注册表
// RU: Разделение структуры, путей и переменных для детерминированной обработки
// EN: Separation of structure, paths, and variables for deterministic processing
// ZH: 分离结构、路径和变量以实现确定性处理
struct ResolutionState {
	string skeleton;                // Слой 1: Валидный JSON-каркас с маркерами
	string[string] uriRegistry;     // Слой 2: Карта [маркер → URI донора]
	string[string] varRegistry;     // Слой 3: Карта [имя → значение переменной]
	string[string] directiveMeta;   // Метаданные: [маркер → тип|селектор]
	size_t markerCounter;
	bool keyContext;                // Флаг позиции: true = ожидаем ключ, false = значение
}

// --- Глобальные контексты / Global contexts / 全局上下文
// RU: Инициализируются единожды в buildAndResolve
// EN: Initialized once in buildAndResolve
// ZH: 在 buildAndResolve 中初始化一次
private ResolutionState g_state;
private string[string] g_usedKeys;

// --- Диспетчер протоколов: вызывает fetch_<scheme> по префиксу URI
// --- Protocol dispatcher: calls fetch_<scheme> based on URI prefix
// --- 协议分发器：根据 URI 前缀调用 fetch_<scheme>
string[] fetchByScheme(string uri, string context) {
	size_t sep = uri.indexOf("://");
	if (sep == size_t.max) throw new Exception("ERR_INVALID_URI: missing scheme");
	string scheme = uri[0 .. sep];

	// RU: switch по строкам разрешён в D. default обрабатывает неизвестные схемы.
	// EN: switch on strings is allowed in D. default handles unknown schemes.
	// ZH: D 允许对字符串使用 switch。default 处理未知协议。
	switch (scheme) {
		case "file": return fetch_file(uri, context);
		// case "ftp":  return fetch_ftp(uri, context);  // Версия 0.2
		// case "http": return fetch_http(uri, context); // Версия 0.3
		default: throw new Exception("ERR_UNSUPPORTED_PROTOCOL: " ~ scheme);
	}
}

// --- Утилиты экранирования / Escape utilities / 转义工具
// RU: Обработка $$ и \@ до основного сканирования
// EN: Handle $$ and \@ before main scanning
// ZH: 在主扫描前处理 $$ 和 \@
string escapeSpecials(string s) {
	string res;
	size_t i = 0, len = s.length;
	while (i < len) {
		if (i+1 < len && s[i] == '$' && s[i+1] == '$') { res ~= '$'; i += 2; continue; }
		if (i+1 < len && s[i] == '\\' && s[i+1] == '@') { res ~= '@'; i += 2; continue; }
		res ~= s[i]; i++;
	}
	return res;
}

// --- Хелпер: токенизация селектора / Helper: selector tokenization / 辅助函数：选择器令牌化
// RU: Разбивает "k1", "k2" → ["k1","k2"], "1..4" → ["1..4"], очищает кавычки
// EN: Split "k1", "k2" → ["k1","k2"], "1..4" → ["1..4"], strip quotes
// ZH: 拆分 "k1", "k2" → ["k1","k2"]，"1..4" → ["1..4"]，剥离引号
string[] tokenizeSelector(string raw) {
	if (raw.length == 0) return [];
	string[] tokens;
	size_t start = 0;
	for (size_t i = 0; i <= raw.length; i++) {
		if (i == raw.length || raw[i] == ',') {
			string tok = raw[start..i].strip;
			if (tok.length >= 2 && tok[0] == '"' && tok[$-1] == '"') tok = tok[1..$-1];
			if (tok.length > 0) tokens ~= tok;
			start = i + 1;
		}
	}
	return tokens;
}
// RU: Разрешение пути вида "a/b/c" в объекте
// EN: Resolve path "a/b/c" inside an object
// ZH: 解析对象内的 "a/b/c" 路径
JMObject* resolvePath(JMObject* root, string path) {
	if (root is null || path.length == 0) return root;
	auto parts = path.split("/");
	JMObject* curr = root;
	foreach (p; parts) {
		if (p.length == 0) continue;
		JMObject* next;
		if (!json_object_object_get_ex(curr, p.toStringz, &next)) {
			return null; // Путь обрывается
		}
		curr = next;
	}
	return curr;
}

// RU: Универсальный хелпер: поиск ключа в объекте через json-c
//     Возвращает JMObject* если ключ найден, иначе бросает исключение + лог
// EN: Universal helper: lookup key in object via json-c native API
//     Returns JMObject* if found, otherwise throws exception + logs
// ZH: 通用辅助函数：通过 json-c 原生 API 在对象中查找键
//     如果找到则返回 JMObject*，否则抛出异常并记录日志
//JMObject* requireKeyInObject(JMObject* obj, string key, string errCode, string donorUri) @safe {
//	import logger;
//	if (obj is null) {
//		string msg = errCode ~ ": donor object is null for key '" ~ key ~ "' in " ~ donorUri;
//		Logger(msg, "ERROR");
//		throw new Exception(msg);
//	}
//	JMObject* val;
//	if (!json_object_object_get_ex(obj, key.toStringz, &val)) {
//		string msg = errCode ~ ": key '" ~ key ~ "' not found in donor " ~ donorUri;
//		Logger(msg, "ERROR");
//		throw new Exception(msg);
//	}
//	// RU: Увеличиваем refcount, чтобы вызывающий код мог безопасно владеть значением
//	// EN: Increment refcount so caller can safely own the value
//	// ZH: 增加引用计数，使调用者可以安全地持有该值
//	json_object_get(val);
//	return val;
//}

// --- ЦЕНТРАЛИЗОВАННЫЙ РЕЗОЛВЕР ПЕРЕМЕННЫХ / Centralized Variable Resolver / 集中式变量解析器
// RU: Применяется ТОЛЬКО к URI и сырому контенту доноров ДО парсинга. Безопасен для JSON.
// EN: Applied ONLY to URIs and raw donor content BEFORE parsing. JSON-safe.
// ZH: 仅应用于 URI 和解析前的原始捐赠者内容。JSON 安全。
string resolveVarsInText(string s) {
	string res;
	size_t i = 0, len = s.length;
	while (i < len) {
		if (i+1 < len && s[i] == '$' && s[i+1] == '{') {
			i += 2; size_t start = i;
			while (i < len && s[i] != '}') i++;
			string vn = s[start..i]; i++;
			if (vn in g_state.varRegistry) res ~= g_state.varRegistry[vn];
			else res ~= "${" ~ vn ~ "}";
		} else {
			res ~= s[i]; i++;
		}
	}
	return res;
}

// --- Фаза 1: Декомпозиция / Phase 1: Decomposition / 阶段 1：分解
// RU: Детерминированный сканер. Заполняет 3 слоя состояния. Возвращает чистый skeleton.
// EN: Deterministic scanner. Fills 3 state layers. Returns clean skeleton.
// ZH: 确定性扫描器。填充 3 个状态层。返回干净的 skeleton。
string decompose(string input) {
	g_state.skeleton = "";
	g_state.uriRegistry = null;
	g_state.varRegistry = null;
	g_state.directiveMeta = null;
	g_state.markerCounter = 0;
	g_state.keyContext = true;

	string[] lines = input.splitLines;
	string[] jsonLines;
	foreach (line; lines) {
		string trimmed = line.strip;
		if (trimmed.length == 0) continue;
		// RU: Сбор переменных в Слой 3
		// EN: Collect variables into Layer 3
		// ZH: 收集变量到第 3 层
		if (trimmed.indexOf('=') > 0 && !trimmed.startsWith("@")) {
			string[] kv = trimmed.split("=");
			if (kv.length == 2) {
				string val = kv[1].strip;
				if (val.length >= 2 && val[0] == '"' && val[$-1] == '"') val = val[1..$-1];
				g_state.varRegistry[kv[0].strip] = val;
			}
			continue;
		}
		jsonLines ~= line;
	}

	string joined = jsonLines.join("\n");
	string escaped = escapeSpecials(joined);
	size_t i = 0, len = escaped.length;

	while (i < len) {
		char c = escaped[i];

		// RU: Трекинг JSON-контекста для детерминированного определения позиции
		// EN: Track JSON context for deterministic position detection
		// ZH: 跟踪 JSON 上下文以确定性检测位置
		if (c == ':') { g_state.keyContext = false; g_state.skeleton ~= c; i++; continue; }
		if (c == ',' || c == '{') { g_state.keyContext = true; g_state.skeleton ~= c; i++; continue; }
		if (c == '}' || c == ']') { g_state.keyContext = false; g_state.skeleton ~= c; i++; continue; }
		if (c == '[') { g_state.keyContext = false; g_state.skeleton ~= c; i++; continue; }
		// RU: Внутри строк пропускаем трекинг контекста
		// EN: Skip context tracking inside strings
		// ZH: 字符串内跳过上下文跟踪
		if (c == '"') {
			g_state.skeleton ~= c; i++;
			while (i < len && escaped[i] != '"') {
				if (escaped[i] == '\\') { g_state.skeleton ~= escaped[i..i+2]; i += 2; }
				else { g_state.skeleton ~= escaped[i]; i++; }
			}
			if (i < len) { g_state.skeleton ~= escaped[i]; i++; }
			continue;
		}

		// RU: Обработка директив @%|@@|@$ → Слой 1 + Слой 2
		// EN: Process directives @%|@@|@$ → Layer 1 + Layer 2
		// ZH: 处理指令 @%|@@|@$ → 第 1 层 + 第 2 层
		if (c == '@' && i+1 < len) {
			char d = escaped[i+1];
			if (d == '%' || d == '@' || d == '$') {
				i += 2;
				while (i < len && escaped[i] == ' ') i++;
				string selector, uri;
				if (i < len && escaped[i] == '{') {
					i++; size_t ks = i;
					while (i < len && escaped[i] != '}') i++;
					selector = escaped[ks..i]; i++;
				}
				while (i < len && escaped[i] == ' ') i++;
				size_t us = i;
				if (i < len && escaped[i] == '"') { i++; us = i; while (i < len && escaped[i] != '"') i++; uri = escaped[us..i]; i++; }
				else { while (i < len && !isJsonDelimiter(escaped[i])) i++; uri = escaped[us..i]; }

				string marker = "__JM_REF_" ~ g_state.markerCounter.to!string ~ "__";
				g_state.markerCounter++;
				g_state.uriRegistry[marker] = uri;
				g_state.directiveMeta[marker] = d.to!string ~ "|" ~ selector;

				// RU: Детерминированный вывод на основе трекинга (без циклов назад)
				// EN: Deterministic output based on tracking (no backward loops)
				// ZH: 基于跟踪的确定性输出（无向后循环）
				if (g_state.keyContext) {
					string cleanSel = (selector.length >= 2 && selector[0] == '"' && selector[$-1] == '"') 
									  ? selector[1..$-1] : selector;
					g_state.skeleton ~= "\"" ~ cleanSel ~ "\": \"" ~ marker ~ "\"";
				} else {
					g_state.skeleton ~= "\"" ~ marker ~ "\"";
				}
				continue;
			}
		}

		// RU: Обработка переменных ${VAR} → Слой 1 + Слой 3
		// EN: Process variables ${VAR} → Layer 1 + Layer 3
		// ZH: 处理变量 ${VAR} → 第 1 层 + 第 3 层
		if (c == '$' && i+1 < len && escaped[i+1] == '{') {
			i += 2; size_t start = i;
			while (i < len && escaped[i] != '}') i++;
			string varName = escaped[start..i]; i++;
			g_state.skeleton ~= "\"" ~ "__JM_VAR_" ~ varName ~ "__\"";
			continue;
		}

		g_state.skeleton ~= c; i++;
	}
	return g_state.skeleton;
}

// --- Фаза 2: Парсинг скелета / Phase 2: Parse skeleton / 阶段 2：解析骨架
JMObject* parseSkeleton(string jsonStr) {
	auto tok = json_tokener_new();
	if (tok is null) throw new Exception("json-c: tokener alloc failed");
	auto obj = json_tokener_parse_ex(tok, jsonStr.ptr, cast(int)jsonStr.length);
	int err = json_tokener_get_error(tok);
	json_tokener_free(tok);
	if (err != 0) {
		const(char)* desc = json_tokener_error_desc(err);
		throw new Exception("json-c: " ~ (desc !is null ? to!string(desc) : "parse error"));
	}
	return obj;
}

// --- Фаза 3: Централизованная загрузка и применение директив / Phase 3: Centralized fetch & apply / 阶段 3：集中加载与应用指令
// RU: Фетч → резолв переменных в доноре → парсинг → применение селектора → возврат узла
// EN: Fetch → resolve vars in donor → parse → apply selector → return node
// ZH: 获取 → 解析捐赠者中的变量 → 解析 → 应用选择器 → 返回节点
JMObject* fetchAndApply(string marker, JMObject* root = null) {
	string uri = g_state.uriRegistry[marker];
	string meta = g_state.directiveMeta[marker];
	string[] parts = meta.split("|");
	string dtype = parts.length > 0 ? parts[0] : "";
	string selector = parts.length > 1 ? parts[1] : "";

	string resolvedUri = resolveVarsInText(uri);
	string[] rawContent = fetchByScheme(resolvedUri, "");
// --- WARN: .json с директивами / WARN: .json with directives / 警告：.json 含指令
// RU: Если файл имеет расширение .json, но содержит @%|@@|@$ — это семантически грязно
// EN: If file has .json extension but contains @%|@@|@$ — semantically unclear
// ZH: 如果文件扩展名为 .json 但包含 @%|@@|@$ — 语义不清晰
	if (resolvedUri.endsWith(".json") || resolvedUri.endsWith(".json\"")) {
	    string content = rawContent.length > 0 ? rawContent[0] : "";
	    if (content.indexOf("@%") != -1 || content.indexOf("@@") != -1 || content.indexOf("@$") != -1) {
	        Logger("WARN: .json file contains jsonmod directives: " ~ resolvedUri, "WARNING");
	    }
	}
// -----------------------------------------------------------
	
	if (rawContent.length == 0) throw new Exception("ERR_EMPTY_RESULT");
	
	// RU: Централизованный резолв переменных в сыро JSON донора
	// EN: Centralized var resolution in raw donor JSON
	// ZH: 原始捐赠者 JSON 中的集中变量解析
	string donorText = resolveVarsInText(rawContent[0]);

	// --- 0.3 RECURSION: Полная обработка включаемого файла ---
	// Сохраняем состояние родителя, чтобы рекурсия не затерла его контекст
	ResolutionState savedState = g_state;
	string[string] savedUsed = g_usedKeys.dup;  // ← просто добавь .dup

	// Рекурсивный вызов: прогоняем файл через весь конвейер jsonmod
	JSONValue childResult = buildAndResolve(donorText);

	// Восстанавливаем состояние родителя
	g_state = savedState;
	g_usedKeys = savedUsed;

	// Преобразуем результат обратно в json-c объект для работы селекторов
	JMObject* src = parseSkeleton(serializeTree(childResult));
	// -----------------------------------------------------------
	int srcType = json_object_get_type(src);
	string[] tokens = tokenizeSelector(selector);
	
	// ============================================================
	// ВЕТКА 1: Массив (@@) → целевой контейнер: массив
	// BRANCH 1: Array (@@) → target container: array
	// 分支 1：数组 (@@) → 目标容器：数组
	// ============================================================
	if (dtype == "@") {
		if (srcType != JM_TYPE_ARRAY) { 
			// json_object_put(src); 
			Logger("ERR_EMPTY_DONOR: @% cannot extract key from empty array", "ERROR");
			throw new Exception("ERR_EMPTY_DONOR: empty array cannot provide key '" ~ selector ~ "'"); 
		}
		JMObject* target = json_object_new_array();
		if (tokens.length == 0) {
			size_t len = json_object_array_length(src);
			for (size_t i=0; i<len; i++) {
				JMObject* c = json_object_array_get_idx(src, i);
				json_object_get(c); json_object_array_add(target, c);
			}
		} else {
			foreach (tok; tokens) {
			// RU: Обработка диапазона "1..4"
			// EN: Handle range "1..4"
			// ZH: 处理范围 "1..4"
				if (tok.indexOf("..") != -1) {
					auto b = tok.split("..");
					if (b.length != 2) {
						Logger("ERR_INVALID_SELECTOR: malformed range '" ~ tok ~ "' in " ~ uri, "ERROR");
						throw new Exception("ERR_INVALID_SELECTOR: range '" ~ tok ~ "'");
					}
					int s, e;
					try {
						s = to!int(b[0].strip);
						e = to!int(b[1].strip);
					} catch (Throwable) {
						Logger("ERR_INVALID_SELECTOR: non-numeric range '" ~ tok ~ "' in " ~ uri, "ERROR");
						throw new Exception("ERR_INVALID_SELECTOR: range '" ~ tok ~ "'");
					}
					// RU: Проверка границ для КАЖДОГО индекса в диапазоне
					// EN: Bounds check for EVERY index in range
					// ZH: 对范围内每个索引进行边界检查
					for (int i = s; i <= e; i++) {
						if (i < 0 || i >= cast(int)json_object_array_length(src)) {
							Logger("ERR_INDEX_OUT_OF_RANGE: index " ~ i.to!string ~ " in " ~ uri, "ERROR");
							throw new Exception("ERR_INDEX_OUT_OF_RANGE: index " ~ i.to!string);
						}
						JMObject* c = json_object_array_get_idx(src, i);
						json_object_get(c);
						json_object_array_add(target, c);
					}
				}
				// RU: Обработка одиночного индекса "2"
				// EN: Handle single index "2"
				// ZH: 处理单个索引 "2"
				else {
					int idx;
					try {
						idx = to!int(tok.strip);
					} catch (Throwable) {
						// RU: Селектор не является числом → ошибка, а не пропуск
						// EN: Selector is not numeric → error, not skip
						// ZH: 选择器不是数字 → 报错，而非跳过
						Logger("ERR_INVALID_SELECTOR: non-numeric index '" ~ tok ~ "' in " ~ uri, "ERROR");
						throw new Exception("ERR_INVALID_SELECTOR: index '" ~ tok ~ "'");
					}
					// RU: Проверка границы перед доступом
					// EN: Bounds check before access
					// ZH: 访问前检查边界
					if (idx < 0 || idx >= cast(int)json_object_array_length(src)) {
						Logger("ERR_INDEX_OUT_OF_RANGE: index " ~ idx.to!string ~ " in " ~ uri, "ERROR");
						throw new Exception("ERR_INDEX_OUT_OF_RANGE: index " ~ idx.to!string);
					}
					JMObject* c = json_object_array_get_idx(src, idx);
					json_object_get(c);
					json_object_array_add(target, c);
				}
			}
		}
		json_object_put(src); return target;
	}
	
	// ============================================================
	// ВЕТКА 2: Объект/Список (@%, @$) → целевой контейнер: объект
	// BRANCH 2: Object/List (@%, @$) → target container: object
	// 分支 2：对象/列表 (@%, @$) → 目标容器：对象
	// ============================================================
	JMObject* target = json_object_new_object();
	
	if (dtype == "%") {
		// 1. Сначала пробуем unwrap (массив из 1 объекта → объект)
		if (srcType == JM_TYPE_ARRAY) {
			size_t arrLen = json_object_array_length(src);
			if (arrLen == 1) {
				// Unwrap: извлекаем объект из массива
				JMObject* item = json_object_array_get_idx(src, 0);
				if (json_object_get_type(item) == JM_TYPE_OBJECT) {
					json_object_get(item);
					json_object_put(src);
					src = item;  // ← продолжаем с развёрнутым объектом
					srcType = JM_TYPE_OBJECT;
				}
			}
			// 2. Если массив пустой → ERR_EMPTY_DONOR
			else if (arrLen == 0) {
				json_object_put(src); json_object_put(target);
				string err = "ERR_EMPTY_DONOR: @% cannot extract key from empty array";
				Logger(err, "ERROR");  // ← ← ← ДОБАВЛЕНО
				throw new Exception(err);
			}
			// 3. Если массив >1 элемента → TYPE_MISMATCH
			else {
				json_object_put(src); json_object_put(target);
				string err = "ERR_TYPE_MISMATCH: @% expects object or single-element array";
				Logger(err, "ERROR");  // ← ← ← ДОБАВЛЕНО
				throw new Exception(err);
			}
		}
		
		// 4. Теперь проверяем тип (должен быть объект после unwrap)
		if (srcType != JM_TYPE_OBJECT) {
			json_object_put(src); json_object_put(target);
			string err = "ERR_TYPE_MISMATCH: @% expects object";
			Logger(err, "ERROR");  // ← ← ← ДОБАВЛЕНО
			throw new Exception(err);
		}
		
			// 5. Селекторы и глубина (единый блок)
		if (tokens.length == 0) {
			// Без селектора → полный объект
			string jstr = to!string(json_object_to_json_string(src));
			if (jstr.length > 0) {
				JMObject* copy = parseSkeleton(jstr);
				json_object_put(target); target = copy;
			}
		} else {
			foreach (k; tokens) {
				JMObject* child;
				string outKey = k; // По умолчанию ключ = имя селектора

				if (k.indexOf("/") != -1) {
					// Глубина: "app/name"
					child = resolvePath(src, k);
					if (child is null) {
						Logger("ERR_KEY_NOT_FOUND: path '" ~ k ~ "' not found in donor " ~ uri, "ERROR");
						throw new Exception("ERR_KEY_NOT_FOUND: path '" ~ k ~ "' not found in donor " ~ uri);
					}
					// Для путей берем последний сегмент как имя ключа в результате
					auto pathSegs = k.split("/");
					outKey = pathSegs[$-1];
				} else {
					// Плоскость: "name"
					if (!json_object_object_get_ex(src, k.toStringz, &child)) {
						Logger("ERR_KEY_NOT_FOUND: key '" ~ k ~ "' not found in donor " ~ uri, "ERROR");
						throw new Exception("ERR_KEY_NOT_FOUND: key '" ~ k ~ "' not found in donor " ~ uri);
					}
				}
				json_object_get(child);
				json_object_object_add(target, outKey.toStringz, child);
			}
		}
	} else if (dtype == "$") {
			 // RU: Проверка типа: @$ ожидает массив
			if (srcType != JM_TYPE_ARRAY) {
				json_object_put(src); json_object_put(target);
				string err = "ERR_TYPE_MISMATCH: @$ expects array [k, v, ...]";
				Logger(err, "ERROR");
				throw new Exception(err);
			}

			size_t len = json_object_array_length(src);
			if (len == 0) {
				// Пустой массив -> пустой объект (валидно)
				json_object_put(src);
				return target;
			}

			bool anyFound = false;

			// RU: Проход по парам [ключ, значение]
			for (size_t i=0; i<len; i+=2) {
				JMObject* kObj = json_object_array_get_idx(src, i);
				JMObject* vObj = json_object_array_get_idx(src, i+1);
				string k = to!string(json_object_get_string(kObj));

				// Если есть селектор (например @${"key1", "key2"})
				if (tokens.length > 0) {
					if (canFind(tokens, k)) {
						json_object_get(vObj); // Берём ссылку
						json_object_object_add(target, k.toStringz, vObj); // Вставляем
						anyFound = true;
					}
				}
				// Если селектора нет — берём всё
				else {
					json_object_get(vObj);
					json_object_object_add(target, k.toStringz, vObj);
				}
			}

			// RU: Если селектор был, но ни одного ключа не нашли -> ошибка
			if (tokens.length > 0 && !anyFound) {
				json_object_put(src); json_object_put(target);
				string err = "ERR_KEY_NOT_FOUND: key(s) '" ~ selector ~ "' not found in donor " ~ uri;
				Logger(err, "ERROR");
				throw new Exception(err);
			}
		}
	else {
		json_object_put(src); json_object_put(target); throw new Exception("Unknown directive type");
	}
	
	json_object_put(src);
	return target;
}

// --- Фаза 4: Обратная сборка дерева (Централизованный обход) / Phase 4: Reverse Assembly (Centralized Traversal) / 阶段 4：反向树组装（集中遍历）
// RU: Рекурсивно заменяет маркеры директив и переменных в D-дереве
// EN: Recursively replaces directive and variable markers in D-tree
// ZH: 递归替换 D 树中的指令和变量标记
JSONValue assembleTree(JSONValue v, JMObject* root = null) {
	if (v.type == JSONType.object) {
		JSONValue[string] obj;
		foreach (k, val; v.object) {
			obj[k] = assembleTree(val, root);
			Logger(obj[k].toString(), "TRACE");
		}
		return JSONValue(obj);
	}
	if (v.type == JSONType.array) {
		JSONValue[] arr;
		foreach (val; v.array) {
			Logger(val.toString(), "TRACE");
			arr ~= assembleTree(val, root);
		}
		return JSONValue(arr);
	}
	if (v.type == JSONType.string) {
		string s = v.str;
		if (s.startsWith("__JM_REF_") && s.endsWith("__") && (s in g_state.uriRegistry)) {
			JMObject* resolved = fetchAndApply(s, root);
			string jsonStr = to!string(json_object_to_json_string(resolved));
			json_object_put(resolved);
			return parseJSON(jsonStr);
		}
		if (s.startsWith("__JM_VAR_") && s.endsWith("__")) {
			string vn = s[9 .. $-2];
			if (vn in g_state.varRegistry) {
				string val = g_state.varRegistry[vn];
				try { 
					return parseJSON(val); 
				} catch(Throwable ex) { 
					Logger(ex.toString(), "ERROR");
					return JSONValue(val); 
				}
			}
		}
		// RU: Фоллбэк: резолв сырых ${VAR}, оставшихся в донорах
		// EN: Fallback: resolve raw ${VAR} left in donors
		// ZH: 回退：解析捐赠者中遗留的原始 ${VAR}
		if (s.indexOf("${") != -1) {
			return JSONValue(resolveVarsInText(s));
		}
	}
	return v;
}

// --- Основной конвейер / Main pipeline / 主管道
JSONValue buildAndResolve(string rawInput) {
	g_usedKeys = null;
	// RU: Фаза 1: Декомпозиция в 3 слоя
	// EN: Phase 1: Decompose into 3 layers
	// ZH: 阶段 1：分解为 3 层
	string skeleton = decompose(rawInput);
	// RU: Фаза 2: Валидный парсинг скелета
	// EN: Phase 2: Valid skeleton parsing
	// ZH: 阶段 2：有效骨架解析
	JMObject* root = parseSkeleton(skeleton);
	if (root is null) { 
			Logger("json-c: parse failed", "ERROR");
			throw new Exception("json-c: parse failed");
		}
	// RU: Фаза 3+4: Обратная сборка и подстановка
	// EN: Phase 3+4: Reverse assembly and substitution
	// ZH: 阶段 3+4：反向组装与替换
	JSONValue result = assembleTree(parseJSON(to!string(json_object_to_json_string(root))), root);
	json_object_put(root);
	return result;
}


// --- Утилиты сериализации / Serialization utils / 序列化工具
// RU: Перенесены из api.d для избежания циклической зависимости. Вызываются ядром и C-API
// EN: Moved from api.d to avoid circular dependency. Used by core and C-API
// ZH: 从 api.d 移至此处以避免循环依赖。核心与 C-API 共用

// --- Экранирование строк для JSON / Escape JSON strings / JSON 字符串转义
/**  * Экранирует специальные символы в строке для корректной сериализации JSON
 * @param s - исходная строка
 * @return экранированная строка
 */

string escapeJSON(string s) {
    string r = s;
    r = r.replace("\\", "\\\\");
    r = r.replace("\"", "\\\"");
    r = r.replace("\n", "\\n");
    r = r.replace("\r", "\\r");
    r = r.replace("\t", "\\t");
    return r;
}

// --- Детерминированный сериализатор / Deterministic serializer / 确定性序列化器
string serializeTree(JSONValue v) {
    if (v.type == JSONType.object) {
        string[] pairs;
        foreach (k, val; v.object)
            pairs ~= "\"" ~ escapeJSON(k) ~ "\":" ~ serializeTree(val);
        return "{" ~ pairs.join(",") ~ "}";
        		// Аналогичная обработка для массивов и примитивных типов
    }
    if (v.type == JSONType.array) {
        string[] items;
        foreach (val; v.array)
            items ~= serializeTree(val);
        return "[" ~ items.join(",") ~ "]";
    }
    if (v.type == JSONType.string)  return "\"" ~ escapeJSON(v.str) ~ "\"";
    if (v.type == JSONType.integer) return v.integer.to!string;
    if (v.type == JSONType.float_)  return v.floating.to!string;
    if (v.type == JSONType.true_)   return "true";
    if (v.type == JSONType.false_)  return "false";
    if (v.type == JSONType.null_)   return "null";
    return "null";
}
// --- Вспомогательные функции / Helper functions / 辅助函数
bool isJsonDelimiter(char c) { return c == ',' || c == '}' || c == ']' || c == ' ' || c == '\t' || c == '\n'; }