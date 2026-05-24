#!/usr/bin/env bash
set -euo pipefail

echo "📦 Generating complete JSONmod test suite (45 scenarios)..."

# === 1. ОЧИСТКА: удаляем старое ===
rm -rf test/donors test/*.jsonmod
mkdir -p test/donors

# Безопасная запись: одинарные кавычки у EOF запрещают bash раскрывать ${}
write() {
    cat > "$1"
    echo "✓ $1"
}

# ==================== DONORS (Источники данных) ====================
# ... (старые доноры) ...
write "test/donors/obj.json" <<'EOF'
{"id": 1, "name": "core", "active": true}
EOF

write "test/donors/arr.json" <<'EOF'
[{"role": "admin"}, {"role": "editor"}, {"role": "viewer"}]
EOF

write "test/donors/flat.json" <<'EOF'
["timeout_ms", 5000, "retry_count", 3]
EOF

write "test/donors/deep.json" <<'EOF'
{"network": {"host": "127.0.0.1", "port": 8080, "tls": true}}
EOF

write "test/donors/tmpl.jsonmo" <<'EOF'
{"user": "${USERNAME}", "env": "${ENV}", "debug": ${DEBUG}}
EOF

write "test/donors/glob_a.json" <<'EOF'
{"part": "ingest-alpha", "seq": 1}
EOF

write "test/donors/glob_b.json" <<'EOF'
{"part": "ingest-beta", "seq": 2}
EOF

write "test/donors/unwrap.json" <<'EOF'
[{"cluster_id": "prod-eu-1", "region": "eu-west-2"}]
EOF

write "test/donors/empty.json" <<'EOF'
[]
EOF

write "test/donors/mismatch.json" <<'EOF'
["this", "is", "an", "array", "not", "object"]
EOF

write "test/donors/service.json" <<'EOF'
{"replicas": 3, "resources": {"cpu": "2.0", "mem": "4Gi"}, "health": "/ready"}
EOF

write "test/donors/routes.json" <<'EOF'
[{"path": "/v1/users", "methods": ["GET", "POST"]}, {"path": "/v1/health", "methods": ["GET"]}]
EOF

write "test/donors/secrets.jsonmo" <<'EOF'
{"db_pass": "${DB_PASS}", "jwt_secret": "${JWT}", "rotation": "monthly"}
EOF

# === Новые доноры для тестов 16–45 ===
write "test/donors/simple.json" <<'EOF'
{"key": "value", "num": 42, "flag": false}
EOF

write "test/donors/nested.json" <<'EOF'
{"level1": {"level2": {"level3": "deep_value"}}}
EOF

write "test/donors/multi_key.json" <<'EOF'
{"a": 1, "b": 2, "c": 3, "d": 4}
EOF

write "test/donors/bools.json" <<'EOF'
{"yes": true, "no": false, "null_val": null}
EOF

write "test/donors/numbers.json" <<'EOF'
{"int": 123, "float": 3.14, "neg": -42, "exp": 1e10}
EOF

write "test/donors/strings.json" <<'EOF'
{"empty": "", "space": " ", "unicode": "Привет🚀", "escape": "line\nbreak"}
EOF

write "test/donors/array_nums.json" <<'EOF'
[1, 2, 3, 4, 5]
EOF

write "test/donors/array_str.json" <<'EOF'
["alpha", "beta", "gamma"]
EOF

write "test/donors/mixed_array.json" <<'EOF'
[{"id": 1}, "plain", 42, true, null]
EOF

write "test/donors/config.json" <<'EOF'
{"app": {"name": "myapp", "ver": "1.0"}, "db": {"host": "localhost", "port": 5432}}
EOF

write "test/donors/env_dev.json" <<'EOF'
{"env": "dev", "debug": true, "log_level": "debug"}
EOF

write "test/donors/env_prod.json" <<'EOF'
{"env": "prod", "debug": false, "log_level": "warn"}
EOF

write "test/donors/feature_flags.json" <<'EOF'
{"new_ui": true, "beta_api": false, "maintenance": false}
EOF

write "test/donors/limits.json" <<'EOF'
{"max_conn": 100, "timeout_sec": 30, "retry_max": 5}
EOF

write "test/donors/paths.json" <<'EOF'
{"root": "/var/app", "logs": "/var/log/app", "tmp": "/tmp/app"}
EOF

# ==================== TEMPLATES (Сценарии) ====================
# ... (старые тесты 01–15 остаются без изменений) ...

# 1. Директива как значение (ключ из шаблона)
write "test/01_value_inject.jsonmod" <<'EOF'
{
"app": "auth-service",
"config": @%{"cfg"} "file://test/donors/obj.json",
"status": "running"
}
EOF

# 2. Директива как значение (массив)
write "test/02_array_value.jsonmod" <<'EOF'
{
"title": "Access Control",
"roles": @@{"list"} "file://test/donors/arr.json",
"default_role": "viewer"
}
EOF

# 3. Плоская вставка (массив становится значением ключа)
write "test/03_flat_inject.jsonmod" <<'EOF'
{
"base": {"env": "prod"},
"overrides": @${"props"} "file://test/donors/flat.json",
"locked": true
}
EOF

# 4. Директива как ЦЕЛЫЙ БЛОК (генерирует ключ + значение)
write "test/04_block_replace.jsonmod" <<'EOF'
{
"name": "payment-core",
"version": "2.1.0",
@%{"database"} "file://test/donors/deep.json",
"logging": "stdout"
}
EOF

# 5. Смешанная вложенность (объект + массив внутри одного узла)
write "test/05_nested_mixed.jsonmod" <<'EOF'
{
"gateway": {
"name": "api-edge",
"upstream": @%{"svc"} "file://test/donors/service.json",
"routes": @@{"endpoints"} "file://test/donors/routes.json"
}
}
EOF

# 6. Переменные в URI (динамический путь)
write "test/06_vars_in_uri.jsonmod" <<'EOF'
target = "obj"
ext = "json"
{
"dynamic_load": @%{"data"} "file://test/donors/${target}.${ext}"
}
EOF

# 7. Переменные в контенте (.jsonmo резолвинг)
write "test/07_vars_in_content.jsonmod" <<'EOF'
USERNAME = "admin"
ENV = "production"
DEBUG = false
{
"security": @%{"creds"} "file://test/donors/tmpl.jsonmo"
}
EOF

# 8. Glob-маска (объединение нескольких файлов в массив)
write "test/08_glob_merge.jsonmod" <<'EOF'
{
"pipeline": {
"name": "data-ingest",
"sources": @@{"parts"} "file://test/donors/glob_*.json"
}
}
EOF

# 9. Unwrap (массив из 1 объекта → объект для @%)
write "test/09_unwrap.jsonmod" <<'EOF'
{
"active_cluster": @%{"target"} "file://test/donors/unwrap.json",
"fallback": "none"
}
EOF

# 10. Продакшен-микросервис (комплексный шаблон)
write "test/10_prod_microservice.jsonmod" <<'EOF'
DB_PASS = "s3cur3_p@ss"
JWT = "tok_99x"
{
"service": "order-processor",
"version": "3.4.1",
"infra": @%{"svc_cfg"} "file://test/donors/service.json",
"secrets": @%{"vault"} "file://test/donors/secrets.jsonmo",
"routes": @@{"api"} "file://test/donors/routes.json"
}
EOF

# 11. API-шлюз (глубокая вложенность + блоки)
write "test/11_api_gateway.jsonmod" <<'EOF'
{
"gateway": {
"version": "2.8.0",
"cors": {"origins": ["*"], "methods": ["GET", "POST"]},
@%{"routing"} "file://test/donors/routes.json",
"auth": @%{"provider"} "file://test/donors/obj.json"
}
}
EOF

# 12–15. Ошибки (негативные тесты — оставляем как есть)
write "test/12_err_conflict.jsonmod" <<'EOF'
{
"database": @%{"primary"} "file://test/donors/obj.json",
"database": @%{"fallback"} "file://test/donors/obj.json"
}
EOF

write "test/13_err_type_mismatch.jsonmod" <<'EOF'
{
"config": @%{"must_be_obj"} "file://test/donors/mismatch.json"
}
EOF

write "test/14_err_empty.jsonmod" <<'EOF'
{
"payload": @%{"data"} "file://test/donors/empty.json"
}
EOF

write "test/15_err_missing.jsonmod" <<'EOF'
{
"ghost": @%{"nowhere"} "file://test/donors/phantom.json"
}
EOF

# ==================== НОВЫЕ ТЕСТЫ 16–45 (успешные) ====================

# 16. Простая инъекция существующего ключа
write "test/16_simple_key.jsonmod" <<'EOF'
{"result": @%{"key"} "file://test/donors/simple.json"}
EOF

# 17. Инъекция числа
write "test/17_number_value.jsonmod" <<'EOF'
{"count": @%{"num"} "file://test/donors/simple.json"}
EOF

# 18. Инъекция булева значения
write "test/18_bool_value.jsonmod" <<'EOF'
{"enabled": @%{"flag"} "file://test/donors/simple.json"}
EOF

# 19. Глубокая вложенность: доступ к level3
write "test/19_deep_access.jsonmod" <<'EOF'
{"deep": @%{"level1"} "file://test/donors/nested.json"}
EOF

# 20. Мульти-ключ: запрашиваем два существующих ключа
write "test/20_multi_key.jsonmod" <<'EOF'
{"subset": @%{"a","c"} "file://test/donors/multi_key.json"}
EOF

# 21. Boolean-донор: извлечение true
write "test/21_bool_true.jsonmod" <<'EOF'
{"feature": @%{"yes"} "file://test/donors/bools.json"}
EOF

# 22. Null-значение
write "test/22_null_value.jsonmod" <<'EOF'
{"empty": @%{"null_val"} "file://test/donors/bools.json"}
EOF

# 23. Числа: извлечение float
write "test/23_float_value.jsonmod" <<'EOF'
{"pi": @%{"float"} "file://test/donors/numbers.json"}
EOF

# 24. Строки: unicode
write "test/24_unicode.jsonmod" <<'EOF'
{"greeting": @%{"unicode"} "file://test/donors/strings.json"}
EOF

# 25. Массив чисел: весь массив без селектора
write "test/25_array_full.jsonmod" <<'EOF'
{"nums": @@ "file://test/donors/array_nums.json"}
EOF

# 26. Массив чисел: диапазон индексов
write "test/26_array_range.jsonmod" <<'EOF'
{"first_three": @@{0..2} "file://test/donors/array_nums.json"}
EOF

# 27. Массив строк: один элемент по индексу
write "test/27_array_single.jsonmod" <<'EOF'
{"second": @@{1} "file://test/donors/array_str.json"}
EOF

# 28. Плоский массив: вставка без селектора (все пары)
write "test/28_flat_full.jsonmod" <<'EOF'
{"settings": @$ "file://test/donors/flat.json"}
EOF

# 29. Плоский массив: один ключ
write "test/29_flat_single.jsonmod" <<'EOF'
{"timeout": @${"timeout_ms"} "file://test/donors/flat.json"}
EOF

# 30. Конфиг: вложенный объект
write "test/30_nested_obj.jsonmod" <<'EOF'
{"app_info": @%{"app"} "file://test/donors/config.json"}
EOF

# 31. Конфиг: извлечение db.host (через два уровня @%)
write "test/31_two_level.jsonmod" <<'EOF'
{"db_host": @%{"db"} "file://test/donors/config.json"}
EOF

# 32. Glob: один файл (маска совпадает с одним)
write "test/32_glob_single.jsonmod" <<'EOF'
{"source": @@ "file://test/donors/glob_a.json"}
EOF

# 33. Unwrap: корректный ключ после развёртки
write "test/33_unwrap_ok.jsonmod" <<'EOF'
{"cluster": @%{"region"} "file://test/donors/unwrap.json"}
EOF

# 34. Переменные в URI: dev-окружение
write "test/34_uri_dev.jsonmod" <<'EOF'
target = "env_dev"
ext = "json"
{"env_config": @%{"env"} "file://test/donors/${target}.${ext}"}
EOF

# 35. Переменные в контенте: подстановка в .jsonmo
write "test/35_content_vars.jsonmod" <<'EOF'
USERNAME = "deploy"
ENV = "staging"
DEBUG = true
{"auth": @%{"user"} "file://test/donors/tmpl.jsonmo"}
EOF

# 36. Feature flags: извлечение одного флага
write "test/36_feature_flag.jsonmod" <<'EOF'
{"new_ui_enabled": @%{"new_ui"} "file://test/donors/feature_flags.json"}
EOF

# 37. Limits: извлечение числа
write "test/37_limit_value.jsonmod" <<'EOF'
{"max_connections": @%{"max_conn"} "file://test/donors/limits.json"}
EOF

# 38. Paths: извлечение строки
write "test/38_path_value.jsonmod" <<'EOF'
{"log_dir": @%{"logs"} "file://test/donors/paths.json"}
EOF

# 39. Mixed array: извлечение объекта по индексу
write "test/39_mixed_obj.jsonmod" <<'EOF'
{"first_item": @@{0} "file://test/donors/mixed_array.json"}
EOF

# 40. Service config: извлечение resources
write "test/40_service_resources.jsonmod" <<'EOF'
{"res": @%{"resources"} "file://test/donors/service.json"}
EOF

# 41. Routes: весь массив маршрутов
write "test/41_routes_full.jsonmod" <<'EOF'
{"endpoints": @@ "file://test/donors/routes.json"}
EOF

# 42. Nested + array: комбинация в одном поле
write "test/42_nested_array.jsonmod" <<'EOF'
{"gateway": {
  "name": "edge",
  "routes": @@{0} "file://test/donors/routes.json"
}}
EOF

# 43. Multiple directives in one object
write "test/43_multi_directive.jsonmod" <<'EOF'
{
  "app_name": @%{"name"} "file://test/donors/config.json",
  "db_port": @%{"port"} "file://test/donors/config.json"
}
EOF

# 44. Block replace with existing key
write "test/44_block_ok.jsonmod" <<'EOF'
{
  "meta": {"ver": "1.0"},
  @%{"app"} "file://test/donors/config.json",
  "footer": "done"
}
EOF

# 45. Complex: chain of valid injections
write "test/45_chain_valid.jsonmod" <<'EOF'
{
  "service": {
    "name": @%{"name"} "file://test/donors/config.json",
    "limits": @%{"max_conn"} "file://test/donors/limits.json",
    "paths": @%{"root"} "file://test/donors/paths.json"
  }
}
EOF

# ==================== НОВЫЕ ТЕСТЫ 46–50 (Путевые селекторы / Path Selectors) ====================
# 46. Простой путь: извлечение строки по пути
write "test/46_path_simple.jsonmod" <<'EOF'
{"app_name": @%{"app/name"} "file://test/donors/config.json"}
EOF

# 47. Глубокий путь: извлечение вложенного объекта
write "test/47_path_object.jsonmod" <<'EOF'
{"l2_data": @%{"level1/level2"} "file://test/donors/nested.json"}
EOF

# 48. Путь к числу: извлечение порта
write "test/48_path_number.jsonmod" <<'EOF'
{"db_port": @%{"db/port"} "file://test/donors/config.json"}
EOF

# 49. Мультиселектор с путями
write "test/49_path_multi.jsonmod" <<'EOF'
{"config": @%{"app/name","db/port"} "file://test/donors/config.json"}
EOF

# 50. Путь в сервис-конфиге
write "test/50_path_service.jsonmod" <<'EOF'
{"cpu_limit": @%{"resources/cpu"} "file://test/donors/service.json"}
EOF

echo "✅ Suite generated (45 tests: 15 error + 30 success). Ready for: make test"