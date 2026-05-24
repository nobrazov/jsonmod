// protocols/file.d - Протокол file:// (локальные файлы, glob)
// protocols/file.d - file:// protocol (local files, glob)
// protocols/file.d - file:// 协议（本地文件，通配符）
module protocols.file;

import std.file, std.path, std.array, std.exception, std.conv, std.string;

// RU: Загрузка контента по URI file:// с поддержкой wildcard
// EN: Load content from file:// URI with wildcard support
// ZH: 从 file:// URI 加载内容（支持通配符）
string[] fetch_file(string uri, string context) {
    // RU: Отрезаем префикс "file://"
    // EN: Strip "file://" prefix
    // ZH: 剥离 "file://" 前缀
    if (uri.length > 7 && uri[0..7] == "file://") uri = uri[7..$];

    // RU: ВАРИАНТ D: Преобразуем относительный путь в абсолютный для детерминизма
    // EN: VARIANT D: Convert relative path to absolute for determinism
    // ZH: 选项 D：将相对路径转换为绝对路径以确保确定性
    uri = absolutePath(uri);

    // RU: Если нет glob-символов, читаем файл напрямую
    // EN: If no glob chars, read file directly
    // ZH: 如果没有通配符，直接读取文件
    if (uri.indexOf('*') == -1 && uri.indexOf('?') == -1 && uri.indexOf('[') == -1) {
        if (!exists(uri)) throw new Exception("ERR_FILE_NOT_FOUND: " ~ uri);
        return [readText(uri)];
    }

    // RU: Разделяем путь на директорию и шаблон имени
    // EN: Split path into directory and name pattern
    // ZH: 将路径拆分为目录和名称模式
    string dir = dirName(uri);
    string pattern = baseName(uri);
    if (!exists(dir)) throw new Exception("ERR_DIR_NOT_FOUND: " ~ dir);

    string[] result;
    foreach (e; dirEntries(dir, SpanMode.shallow)) {
        if (e.isFile && globMatch(baseName(e.name), pattern)) {
            result ~= readText(e.name);
        }
    }
    if (result.length == 0) throw new Exception("ERR_EMPTY_RESULT: " ~ uri);
    return result;
}

// RU: Детерминированный glob-матчер (*, ?, [...], [!...])
// EN: Deterministic glob matcher (*, ?, [...], [!...])
// ZH: 确定性 glob 匹配器（*，?，[...]，[!...]）
private bool globMatch(string name, string pattern) @safe {
    size_t ni = 0, pi = 0;
    size_t starNi = size_t.max, starPi = size_t.max;

    while (ni < name.length) {
        bool matchChar = false;
        if (pi < pattern.length) {
            char p = pattern[pi];
            char n = name[ni];
            if (p == '?') matchChar = true;
            else if (p == '*') {
                starNi = ni; starPi = pi; pi++; continue;
            }
            else if (p == '[') {
                pi++; bool invert = false;
                if (pi < pattern.length && pattern[pi] == '!') { invert = true; pi++; }
                bool found = false;
                while (pi < pattern.length && pattern[pi] != ']') {
                    char start = pattern[pi]; pi++;
                    if (pi < pattern.length && pattern[pi] == '-') {
                        char end = pattern[pi+1]; pi += 2;
                        if (n >= start && n <= end) found = true;
                    } else {
                        if (n == start) found = true;
                    }
                }
                if (invert) matchChar = !found;
                else matchChar = found;
                if (pi < pattern.length && pattern[pi] == ']') pi++;
            }
            else if (p == n) matchChar = true;
        }

        if (matchChar) { ni++; pi++; }
        else if (starPi != size_t.max) { ni = ++starNi; pi = starPi + 1; }
        else return false;
    }

    while (pi < pattern.length && pattern[pi] == '*') pi++;
    return pi == pattern.length;
}