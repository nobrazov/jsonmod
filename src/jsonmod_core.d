// jsonmod_core.d — Лексер структурного JSONmod (каркас + инъекции)
// Structural lexer: preserves JSON skeleton, tokenizes directives & literals
// 结构化解词器：保留 JSON 骨架，标记指令与字面量

module jsonmod_core;

// --- Импорт стандартных модулей / Standard library imports / 标准库导入
// RU: std.string для работы с подстроками, std.exception для ошибок парсинга
// EN: std.string for substring operations, std.exception for parse errors
// ZH: std.string 用于子串操作，std.exception 用于解析错误
import std.string, std.array, std.exception, std.conv;

// --- Типы токенов / Token types / 令牌类型
// RU: Структура, литералы, директивы, объявления переменных
// EN: Structure, literals, directives, variable declarations
// ZH: 结构，字面量，指令，变量声明
enum TokenType {
    ObjOpen, ObjClose, ArrOpen, ArrClose,
    Colon, Comma,
    Str, Num, Bool, Null,
    DirObj, DirArr, DirFlat, // @%, @@, @$
    VarDecl, // key = value
    EOF
}

// --- Структура токена / Token structure / 令牌结构
struct Token {
    TokenType type;
    string payload;
    size_t line;
}

// --- Основная функция лексера / Main lexer function / 主词法分析函数
Token[] lexJSONmod(string input) {
    Token[] tokens;
    size_t i = 0, len = input.length, line = 1;

    while (i < len) {
        char c = input[i];
        // RU: Пропуск пробелов и табуляций / EN: Skip spaces/tabs / ZH: 跳过空格/制表符
        if (c == ' ' || c == '\t' || c == '\r') { i++; continue; }
        // RU: Подсчёт строк / EN: Line counting / ZH: 行计数
        if (c == '\n') { line++; i++; continue; }
        // RU: Однострочные комментарии // ... / EN: Single-line comments / ZH: 单行注释
        if (c == '/' && i+1 < len && input[i+1] == '/') { while (i < len && input[i] != '\n') i++; continue; }

        // --- Структурные символы / Structural symbols / 结构符号
        if (c == '{') { tokens ~= Token(TokenType.ObjOpen, "", line); i++; continue; }
        if (c == '}') { tokens ~= Token(TokenType.ObjClose, "", line); i++; continue; }
        if (c == '[') { tokens ~= Token(TokenType.ArrOpen, "", line); i++; continue; }
        if (c == ']') { tokens ~= Token(TokenType.ArrClose, "", line); i++; continue; }
        if (c == ':') { tokens ~= Token(TokenType.Colon, "", line); i++; continue; }
        if (c == ',') { tokens ~= Token(TokenType.Comma, "", line); i++; continue; }

        // --- Строковые литералы / String literals / 字符串字面量
        if (c == '"') {
            i++; string s;
            while (i < len && input[i] != '"') {
                if (input[i] == '\\' && i+1 < len) { i++; s ~= input[i]; }
                else s ~= input[i];
                i++;
            }
            i++; tokens ~= Token(TokenType.Str, s, line); continue;
        }

        // --- Числа / Numbers / 数字
        if ((c >= '0' && c <= '9') || c == '-' || c == '.') {
            size_t start = i;
            while (i < len && (input[i] >= '0' && input[i] <= '9' || input[i] == '.' || input[i] == '-' || input[i] == 'e' || input[i] == 'E')) i++;
            tokens ~= Token(TokenType.Num, input[start..i], line); continue;
        }
        // --- Булевы и null / Booleans & null / 布尔值与 null
        if (input[i..$].startsWith("true")) { tokens ~= Token(TokenType.Bool, "true", line); i += 4; continue; }
        if (input[i..$].startsWith("false")) { tokens ~= Token(TokenType.Bool, "false", line); i += 5; continue; }
        if (input[i..$].startsWith("null")) { tokens ~= Token(TokenType.Null, "null", line); i += 4; continue; }

        // --- Объявление переменных / Variable declaration / 变量声明
        // RU: Формат: key = "value" или key = value
        if (isIdentifierStart(c) && scanAhead(input, i) == '=') {
            size_t start = i;
            while (i < len && input[i] != '=' && input[i] != ' ') i++;
            string key = input[start..i].strip;
            while (i < len && (input[i] == ' ' || input[i] == '=')) i++;
            size_t vStart = i;
            while (i < len && input[i] != '\n' && input[i] != '\r') i++;
            string val = input[vStart..i].strip;
            if (val.length >= 2 && val[0] == '"' && val[$-1] == '"') val = val[1..$-1];
            tokens ~= Token(TokenType.VarDecl, key ~ "=" ~ val, line); continue;
        }
        // --- Директивы / Directives / 指令
        if (c == '@') {
            i++;
            // Проверка на конец файла после '@'
            if (i >= len) {
                throw new Exception("Unexpected @ at EOF");
            }
            char d = input[i];
            i++;
            // Пропуск пробелов и табуляций
            while (i < len && (input[i] == ' ' || input[i] == '\t')) {
                i++;
            }
            // Ожидание открывающей фигурной скобки
            if (input[i] != '{') {
                throw new Exception("Expected { in directive at line " ~ line.to!string);
            }
            i++;
            // Извлечение ключа между { и }
            size_t ks = i;
            while (i < len && input[i] != '}') {
                i++;
            }
            string key = input[ks..i];
            i++; // Пропуск закрывающей фигурной скобки

            // Пропуск пробелов и табуляций после ключа
            while (i < len && (input[i] == ' ' || input[i] == '\t')) {
                i++;
            }
            string uri;
            // Извлечение URI — два варианта в зависимости от наличия кавычек
            if (i < len && input[i] == '"') {
                // Случай с кавычками: извлекаем содержимое между кавычками
                i++; // Пропуск открывающей кавычки
                size_t us = i;
                while (i < len && input[i] != '"') {
                    i++;
                }
                uri = input[us..i];
                i++; // Пропуск закрывающей кавычки
            } else {
                // Случай без кавычек: извлекаем до разделителей
                size_t us = i;
                while (i < len
                    && input[i] != ','
                    && input[i] != '}'
                    && input[i] != ']'
                    && input[i] != '\n'
                    && input[i] != ' ') {
                    i++;
                }
                uri = input[us..i];
            }
            // Определение типа токена на основе символа d
            TokenType t = d == '%'
                ? TokenType.DirObj
                : (d == '@'
                    ? TokenType.DirArr
                    : TokenType.DirFlat);

            // Добавление нового токена в список
            tokens ~= Token(t, d ~ "{" ~ key ~ "}" ~ " " ~ uri, line);
            continue;
        }
        throw new Exception("Unexpected char '" ~ c ~ "' at line " ~ line.to!string);
    }
    return tokens;
}

// --- Вспомогательные функции / Helper functions / 辅助函数
bool isIdentifierStart(char c) { 
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; 
}
size_t scanAhead(string s, size_t pos) {
    size_t p = pos;
    while (p < s.length && (s[p] == ' ' || s[p] == '\t')) p++;
    return (p < s.length) ? s[p] : 0;
}