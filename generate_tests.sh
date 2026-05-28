#!/usr/bin/env bash
set -euo pipefail
echo "📦 Generating complete JSONmod test suite (60 scenarios)..."

# === 1. ОЧИСТКА: удаляем старое ===
rm -rf test/donors test/*.jsonmod
mkdir -p test/donors

# === Функция записи: читает из STDIN, пишет в файл ===
write() {
    cat > "$1"
    echo "✓ $1"
}

# ==================== DONORS (Источники данных) ====================

# Базовые доноры (с ключами для тестов 1-15)
write "test/donors/obj.json" <<'EOF'
{"id": 1, "name": "core", "active": true, "cfg": {"db": "postgres"}, "primary": {"host": "localhost"}, "fallback": {"host": "backup"}, "provider": {"auth": "oauth2"}}
EOF

write "test/donors/arr.json" <<'EOF'
[{"role": "admin"}, {"role": "editor"}, {"role": "viewer"}]
EOF

write "test/donors/flat.json" <<'EOF'
["timeout_ms", 5000, "retry_count", 3]
EOF

write "test/donors/deep.json" <<'EOF'
{"network": {"host": "127.0.0.1", "port": 8080, "tls": true}, "database": {"type": "sql", "conn": "pool"}}
EOF

write "test/donors/tmpl.jsonmo" <<'EOF'
{"user": "${USERNAME}", "env": "${ENV}", "debug": ${DEBUG}, "creds": {"token": "abc123"}}
EOF

write "test/donors/glob_a.json" <<'EOF'
{"part": "ingest-alpha", "seq": 1}
EOF

write "test/donors/glob_b.json" <<'EOF'
{"part": "ingest-beta", "seq": 2}
EOF

write "test/donors/unwrap.json" <<'EOF'
[{"cluster_id": "prod-eu-1", "region": "eu-west-2", "target": {"id": 1, "name": "main"}}]
EOF

write "test/donors/empty.json" <<'EOF'
[]
EOF

write "test/donors/mismatch.json" <<'EOF'
["this", "is", "an", "array", "not", "object"]
EOF

write "test/donors/service.json" <<'EOF'
{"replicas": 3, "resources": {"cpu": "2.0", "mem": "4Gi"}, "health": "/ready", "svc": {"port": 8080}, "svc_cfg": {"env": "prod"}}
EOF

write "test/donors/routes.json" <<'EOF'
[{"path": "/v1/users", "methods": ["GET", "POST"]}, {"path": "/v1/health", "methods": ["GET"]}]
EOF

write "test/donors/secrets.jsonmo" <<'EOF'
{"db_pass": "${DB_PASS}", "jwt_secret": "${JWT}", "rotation": "monthly", "vault": {"key": "secret_val"}}
EOF

# Доноры для тестов 16-50
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

# === DONORS FOR RECURSION TESTS (51–60) ===

# Цепочка 3 уровня: A → B → C
write "test/donors/rec_chain_c.json" <<'EOF'
{"final": "value", "depth": 3, "data": {"link": "ok"}}
EOF

write "test/donors/rec_chain_b.jsonmod" <<'EOF'
{"middle": @%{"data"} "file://test/donors/rec_chain_c.json"}
EOF

write "test/donors/rec_chain_a.jsonmod" <<'EOF'
{"start": @%{"link"} "file://test/donors/rec_chain_b.jsonmod"}
EOF

# Глубокая цепочка 5 уровней
write "test/donors/rec_deep_5.json" <<'EOF'
{"leaf": "end", "level": 5, "n": {"next": "ok"}}
EOF

write "test/donors/rec_deep_4.jsonmod" <<'EOF'
{"l4": @%{"n"} "file://test/donors/rec_deep_5.json"}
EOF

write "test/donors/rec_deep_3.jsonmod" <<'EOF'
{"l3": @%{"n"} "file://test/donors/rec_deep_4.jsonmod"}
EOF

write "test/donors/rec_deep_2.jsonmod" <<'EOF'
{"l2": @%{"n"} "file://test/donors/rec_deep_3.jsonmod"}
EOF

write "test/donors/rec_deep_1.jsonmod" <<'EOF'
{"l1": @%{"n"} "file://test/donors/rec_deep_2.jsonmod"}
EOF

# Мульти-инклюды
write "test/donors/rec_multi_left.json" <<'EOF'
{"side": "left", "val": 10, "data": {"id": 1}}
EOF

write "test/donors/rec_multi_right.json" <<'EOF'
{"side": "right", "val": 20, "data": {"id": 2}}
EOF

write "test/donors/rec_multi_base.jsonmod" <<'EOF'
{
"left": @%{"data"} "file://test/donors/rec_multi_left.json",
"right": @%{"data"} "file://test/donors/rec_multi_right.json"
}
EOF

write "test/donors/rec_multi_root.jsonmod" <<'EOF'
{"tree": @%{"branch"} "file://test/donors/rec_multi_base.jsonmod"}
EOF

# Рекурсия с переменными в URI
write "test/donors/rec_var_end.json" <<'EOF'
{"result": "resolved", "via": "var", "x": {"step": "done"}}
EOF

write "test/donors/rec_var_mid.jsonmod" <<'EOF'
{"step": @%{"x"} "file://test/donors/rec_var_end.json"}
EOF

write "test/donors/rec_var_start.jsonmod" <<'EOF'
target = "rec_var_mid"
{"root": @%{"link"} "file://test/donors/${target}.jsonmod"}
EOF

# Рекурсия с селектором @@ (массив)
write "test/donors/rec_arr_leaf.json" <<'EOF'
[{"id": 1}, {"id": 2}]
EOF

write "test/donors/rec_arr_mid.jsonmod" <<'EOF'
{"items": @@ "file://test/donors/rec_arr_leaf.json", "data": {"collection": [1,2]}}
EOF

write "test/donors/rec_arr_root.jsonmod" <<'EOF'
{"collection": @%{"data"} "file://test/donors/rec_arr_mid.jsonmod"}
EOF

# Рекурсия с селектором @$ (плоский список)
write "test/donors/rec_flat_leaf.json" <<'EOF'
["key_a", "val_a", "key_b", "val_b", "section", {"cfg": "ok"}]
EOF

write "test/donors/rec_flat_mid.jsonmod" <<'EOF'
{"map": @$ "file://test/donors/rec_flat_leaf.json", "section": {"config": "val"}}
EOF

write "test/donors/rec_flat_root.jsonmod" <<'EOF'
{"config": @%{"section"} "file://test/donors/rec_flat_mid.jsonmod"}
EOF

# Смешанная цепочка: .json → .jsonmod → .json → .jsonmod
write "test/donors/rec_mix_d.json" <<'EOF'
{"final_node": true, "end": {"ref": "ok"}}
EOF

write "test/donors/rec_mix_c.jsonmod" <<'EOF'
{"c_ref": @%{"end"} "file://test/donors/rec_mix_d.json"}
EOF

write "test/donors/rec_mix_b.json" <<'EOF'
{"b_data": {"inner": @%{"c_ref"} "file://test/donors/rec_mix_c.jsonmod"}}
EOF

write "test/donors/rec_mix_a.jsonmod" <<'EOF'
{"start": @%{"b"} "file://test/donors/rec_mix_b.json"}
EOF

# Рекурсия с glob-маской
write "test/donors/rec_glob_part1.json" <<'EOF'
{"part": 1, "chunks": [1]}
EOF

write "test/donors/rec_glob_part2.json" <<'EOF'
{"part": 2, "chunks": [2]}
EOF

write "test/donors/rec_glob_mid.jsonmod" <<'EOF'
{"parts": @@ "file://test/donors/rec_glob_part*.json"}
EOF

write "test/donors/rec_glob_root.jsonmod" <<'EOF'
{"bundle": @%{"chunks"} "file://test/donors/rec_glob_mid.jsonmod"}
EOF

# Цепочка с @% на каждом уровне
write "test/donors/rec_pct_c.json" <<'EOF'
{"core": {"value": 42}}
EOF

write "test/donors/rec_pct_b.jsonmod" <<'EOF'
{"wrap": @%{"core"} "file://test/donors/rec_pct_c.json"}
EOF

write "test/donors/rec_pct_a.jsonmod" <<'EOF'
{"outer": @%{"wrap"} "file://test/donors/rec_pct_b.jsonmod"}
EOF

# Валидная длинная цепочка (10 уровней)
write "test/donors/rec_l10.json" <<'EOF'
{"v": "ok", "x": {"next": "ok"}}
EOF

write "test/donors/rec_l9.jsonmod" <<'EOF'
{"l9": @%{"x"} "file://test/donors/rec_l10.json"}
EOF

write "test/donors/rec_l8.jsonmod" <<'EOF'
{"l8": @%{"x"} "file://test/donors/rec_l9.jsonmod"}
EOF

write "test/donors/rec_l7.jsonmod" <<'EOF'
{"l7": @%{"x"} "file://test/donors/rec_l8.jsonmod"}
EOF

write "test/donors/rec_l6.jsonmod" <<'EOF'
{"l6": @%{"x"} "file://test/donors/rec_l7.jsonmod"}
EOF

write "test/donors/rec_l5.jsonmod" <<'EOF'
{"l5": @%{"x"} "file://test/donors/rec_l6.jsonmod"}
EOF

write "test/donors/rec_l4.jsonmod" <<'EOF'
{"l4": @%{"x"} "file://test/donors/rec_l5.jsonmod"}
EOF

write "test/donors/rec_l3.jsonmod" <<'EOF'
{"l3": @%{"x"} "file://test/donors/rec_l4.jsonmod"}
EOF

write "test/donors/rec_l2.jsonmod" <<'EOF'
{"l2": @%{"x"} "file://test/donors/rec_l3.jsonmod"}
EOF

write "test/donors/rec_l1.jsonmod" <<'EOF'
{"l1": @%{"x"} "file://test/donors/rec_l2.jsonmod"}
EOF

# Рекурсия с путевыми селекторами
write "test/donors/rec_path_end.json" <<'EOF'
{"a": {"b": {"c": "deep_value"}}}
EOF

write "test/donors/rec_path_mid.jsonmod" <<'EOF'
{"extracted": @%{"a/b"} "file://test/donors/rec_path_end.json"}
EOF

write "test/donors/rec_path_root.jsonmod" <<'EOF'
{"result": @%{"extracted"} "file://test/donors/rec_path_mid.jsonmod"}
EOF

# ==================== TEMPLATES (Сценарии 1-50) ====================

# 1–15
write "test/01_value_inject.jsonmod" <<'EOF'
{
"app": "auth-service",
"config": @%{"cfg"} "file://test/donors/obj.json",
"status": "running"
}
EOF

write "test/02_array_value.jsonmod" <<'EOF'
{
"title": "Access Control",
"roles": @@ "file://test/donors/arr.json",
"default_role": "viewer"
}
EOF

write "test/03_flat_inject.jsonmod" <<'EOF'
{
"base": {"env": "prod"},
"overrides": @$ "file://test/donors/flat.json",
"locked": true
}
EOF

write "test/04_block_replace.jsonmod" <<'EOF'
{
"name": "payment-core",
"version": "2.1.0",
@%{"database"} "file://test/donors/deep.json",
"logging": "stdout"
}
EOF

write "test/05_nested_mixed.jsonmod" <<'EOF'
{
"gateway": {
"name": "api-edge",
"upstream": @%{"svc"} "file://test/donors/service.json",
"routes": @@ "file://test/donors/routes.json"
}
}
EOF

write "test/06_vars_in_uri.jsonmod" <<'EOF'
target = "obj"
ext = "json"
{
"dynamic_load": @%{"data"} "file://test/donors/${target}.${ext}"
}
EOF

write "test/07_vars_in_content.jsonmod" <<'EOF'
USERNAME = "admin"
ENV = "production"
DEBUG = false
{
"security": @%{"creds"} "file://test/donors/tmpl.jsonmo"
}
EOF

write "test/08_glob_merge.jsonmod" <<'EOF'
{
"pipeline": {
"name": "data-ingest",
"sources": @@ "file://test/donors/glob_*.json"
}
}
EOF

write "test/09_unwrap.jsonmod" <<'EOF'
{
"active_cluster": @%{"target"} "file://test/donors/unwrap.json",
"fallback": "none"
}
EOF

write "test/10_prod_microservice.jsonmod" <<'EOF'
DB_PASS = "s3cur3_p@ss"
JWT = "tok_99x"
{
"service": "order-processor",
"version": "3.4.1",
"infra": @%{"svc_cfg"} "file://test/donors/service.json",
"secrets": @%{"vault"} "file://test/donors/secrets.jsonmo",
"routes": @@ "file://test/donors/routes.json"
}
EOF

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

# 16–50
write "test/16_simple_key.jsonmod" <<'EOF'
{"result": @%{"key"} "file://test/donors/simple.json"}
EOF

write "test/17_number_value.jsonmod" <<'EOF'
{"count": @%{"num"} "file://test/donors/simple.json"}
EOF

write "test/18_bool_value.jsonmod" <<'EOF'
{"enabled": @%{"flag"} "file://test/donors/simple.json"}
EOF

write "test/19_deep_access.jsonmod" <<'EOF'
{"deep": @%{"level1"} "file://test/donors/nested.json"}
EOF

write "test/20_multi_key.jsonmod" <<'EOF'
{"subset": @%{"a","c"} "file://test/donors/multi_key.json"}
EOF

write "test/21_bool_true.jsonmod" <<'EOF'
{"feature": @%{"yes"} "file://test/donors/bools.json"}
EOF

write "test/22_null_value.jsonmod" <<'EOF'
{"empty": @%{"null_val"} "file://test/donors/bools.json"}
EOF

write "test/23_float_value.jsonmod" <<'EOF'
{"pi": @%{"float"} "file://test/donors/numbers.json"}
EOF

write "test/24_unicode.jsonmod" <<'EOF'
{"greeting": @%{"unicode"} "file://test/donors/strings.json"}
EOF

write "test/25_array_full.jsonmod" <<'EOF'
{"nums": @@ "file://test/donors/array_nums.json"}
EOF

write "test/26_array_range.jsonmod" <<'EOF'
{"first_three": @@{0..2} "file://test/donors/array_nums.json"}
EOF

write "test/27_array_single.jsonmod" <<'EOF'
{"second": @@{1} "file://test/donors/array_str.json"}
EOF

write "test/28_flat_full.jsonmod" <<'EOF'
{"settings": @$ "file://test/donors/flat.json"}
EOF

write "test/29_flat_single.jsonmod" <<'EOF'
{"timeout": @${"timeout_ms"} "file://test/donors/flat.json"}
EOF

write "test/30_nested_obj.jsonmod" <<'EOF'
{"app_info": @%{"app"} "file://test/donors/config.json"}
EOF

write "test/31_two_level.jsonmod" <<'EOF'
{"db_host": @%{"db"} "file://test/donors/config.json"}
EOF

write "test/32_glob_single.jsonmod" <<'EOF'
{"source": @@ "file://test/donors/glob_a.json"}
EOF

write "test/33_unwrap_ok.jsonmod" <<'EOF'
{"cluster": @%{"region"} "file://test/donors/unwrap.json"}
EOF

write "test/34_uri_dev.jsonmod" <<'EOF'
target = "env_dev"
ext = "json"
{"env_config": @%{"env"} "file://test/donors/${target}.${ext}"}
EOF

write "test/35_content_vars.jsonmod" <<'EOF'
USERNAME = "deploy"
ENV = "staging"
DEBUG = true
{"auth": @%{"user"} "file://test/donors/tmpl.jsonmo"}
EOF

write "test/36_feature_flag.jsonmod" <<'EOF'
{"new_ui_enabled": @%{"new_ui"} "file://test/donors/feature_flags.json"}
EOF

write "test/37_limit_value.jsonmod" <<'EOF'
{"max_connections": @%{"max_conn"} "file://test/donors/limits.json"}
EOF

write "test/38_path_value.jsonmod" <<'EOF'
{"log_dir": @%{"logs"} "file://test/donors/paths.json"}
EOF

write "test/39_mixed_obj.jsonmod" <<'EOF'
{"first_item": @@{0} "file://test/donors/mixed_array.json"}
EOF

write "test/40_service_resources.jsonmod" <<'EOF'
{"res": @%{"resources"} "file://test/donors/service.json"}
EOF

write "test/41_routes_full.jsonmod" <<'EOF'
{"endpoints": @@ "file://test/donors/routes.json"}
EOF

write "test/42_nested_array.jsonmod" <<'EOF'
{"gateway": {
"name": "edge",
"routes": @@{0} "file://test/donors/routes.json"
}}
EOF

write "test/43_multi_directive.jsonmod" <<'EOF'
{
"app_name": @%{"name"} "file://test/donors/config.json",
"db_port": @%{"port"} "file://test/donors/config.json"
}
EOF

write "test/44_block_ok.jsonmod" <<'EOF'
{
"meta": {"ver": "1.0"},
@%{"app"} "file://test/donors/config.json",
"footer": "done"
}
EOF

write "test/45_chain_valid.jsonmod" <<'EOF'
{
"service": {
"name": @%{"name"} "file://test/donors/config.json",
"limits": @%{"max_conn"} "file://test/donors/limits.json",
"paths": @%{"root"} "file://test/donors/paths.json"
}
}
EOF

write "test/46_path_simple.jsonmod" <<'EOF'
{"app_name": @%{"app/name"} "file://test/donors/config.json"}
EOF

write "test/47_path_object.jsonmod" <<'EOF'
{"l2_data": @%{"level1/level2"} "file://test/donors/nested.json"}
EOF

write "test/48_path_number.jsonmod" <<'EOF'
{"db_port": @%{"db/port"} "file://test/donors/config.json"}
EOF

write "test/49_path_multi.jsonmod" <<'EOF'
{"config": @%{"app/name","db/port"} "file://test/donors/config.json"}
EOF

write "test/50_path_service.jsonmod" <<'EOF'
{"cpu_limit": @%{"resources/cpu"} "file://test/donors/service.json"}
EOF

# ==================== RECURSION TESTS (51–60) ====================

write "test/51_rec_chain.jsonmod" <<'EOF'
{"output": @%{"start"} "file://test/donors/rec_chain_a.jsonmod"}
EOF

write "test/52_rec_deep.jsonmod" <<'EOF'
{"depth_test": @%{"l1"} "file://test/donors/rec_deep_1.jsonmod"}
EOF

write "test/53_rec_multi.jsonmod" <<'EOF'
{"result": @%{"tree"} "file://test/donors/rec_multi_root.jsonmod"}
EOF

write "test/54_rec_var_uri.jsonmod" <<'EOF'
target = "rec_var_start"
{"final": @%{"root"} "file://test/donors/${target}.jsonmod"}
EOF

write "test/55_rec_array.jsonmod" <<'EOF'
{"data": @%{"collection"} "file://test/donors/rec_arr_root.jsonmod"}
EOF

write "test/56_rec_flat.jsonmod" <<'EOF'
{"settings": @%{"config"} "file://test/donors/rec_flat_root.jsonmod"}
EOF

write "test/57_rec_mixed.jsonmod" <<'EOF'
{"output": @%{"start"} "file://test/donors/rec_mix_a.jsonmod"}
EOF

write "test/58_rec_glob.jsonmod" <<'EOF'
{"bundle": @%{"bundle"} "file://test/donors/rec_glob_root.jsonmod"}
EOF

write "test/59_rec_percent.jsonmod" <<'EOF'
{"value": @%{"outer"} "file://test/donors/rec_pct_a.jsonmod"}
EOF

write "test/60_rec_long.jsonmod" <<'EOF'
{"stress": @%{"l1"} "file://test/donors/rec_l1.jsonmod"}
EOF

echo "✅ Suite generated (60 tests). Ready for: make test"