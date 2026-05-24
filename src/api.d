// api.d — C-API ядра / Core C-API / 核心 C-API
// RU: Точка входа для внешних языков (Perl, C, Python через FFI)
// EN: Entry point for external languages (Perl, C, Python via FFI)
// ZH: 外部语言的入口点（Perl, C, Python 通过 FFI）
module api;

// --- Импорт стандартных модулей / Standard library imports / 标准库导入
import std.exception, std.string, std.array, std.json : JSONValue, JSONType;
import std.conv;
import merger;
import core.sys.posix.unistd; // Системные вызовы POSIX
import core.stdc.string; // Строковые функции C
import logger; // Модуль логирования
import core.stdc.errno;      // для errno.errno
import core.sys.posix.string; // для strerror
import std.conv : to;  // если ещё нет
import std.stdio : stderr;      // для stderr.writeln
import core.stdc.stdlib : exit; // для exit(1)


// --- Утилиты / Utilities / 工具函数
// Утилита для работы с ошибками

/**
 * Копирует сообщение об ошибке в буфер
 * @param msg - исходное сообщение
 * @param buf - целевой буфер
 * @param len - длина буфера
 */
void copyToErrBuf(string msg, char* buf, size_t len) {
	size_t n = msg.length < len - 1 ? msg.length : len - 1;
	memcpy(buf, msg.ptr, n);
	buf[n] = '\0';
}

/**
 * Записывает сообщение в stderr
 * @param msg - сообщение для вывода
 */

void writeToStderr(string msg) {
	if (msg.length > 0) core.sys.posix.unistd.write(2, cast(const(void)*)msg.ptr, msg.length);
	core.sys.posix.unistd.write(2, cast(const(void)*)"\n".ptr, 1);
}

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

// Основная точка входа в API
/**
 * Основная функция обработки JSON
 * @param in_fd - файловый дескриптор для чтения входных данных
 * @param out_fd - файловый дескриптор для записи результата
 * @param err_buf - буфер для сообщений об ошибках
 * @param err_len - длина буфера ошибок
 * @return код ошибки (0 - успех, -1 - ошибка)
 */

extern(C) int jsonmod_run(int in_fd, int out_fd, char* err_buf, size_t err_len) {
	try {
		// === Чтение входных данных ===
		ubyte[] buffer;
		ubyte[4096] chunk;
		
		while (true) {
			ssize_t rd = core.sys.posix.unistd.read(in_fd, chunk.ptr, chunk.length);
			if (rd < 0) {
				// Ошибка чтения: передаём системную ошибку
				string err = "ERR_READ";  // ← просто метка, без кода
				copyToErrBuf(err, err_buf, err_len);
				writeToStderr(err);
				Logger(err, "ERROR");
				return -1;
			}
			if (rd == 0) {
				// EOF: нормальное завершение чтения
				break;
			}
			buffer ~= chunk[0..rd];
		}
		
		// === Обработка ===
		string input = cast(string) buffer;
		
		// Пустой ввод — это ошибка, но обрабатывается ядром естественно
		// Если нужно явно ловить — раскомментировать:
		// if (input.length == 0) {
		//     string err = "ERR_EMPTY_INPUT";
		//     copyToErrBuf(err, err_buf, err_len);
		//     writeToStderr(err);
		//     Logger(err, "ERROR");
		//     return -1;
		// }
		
		// ✅ ЕДИНСТВЕННЫЙ ВЫЗОВ ЯДРА
		JSONValue tree = buildAndResolve(input);
		string finalJSON = serializeTree(tree);
		
		// === Запись результата ===
		size_t written = 0;
		while (written < finalJSON.length) {
			ssize_t wr = core.sys.posix.unistd.write(out_fd, cast(const(void)*)finalJSON.ptr + written, finalJSON.length - written);
			if (wr <= 0) {
				string err = "ERR_WRITE";  // ← просто метка
				copyToErrBuf(err, err_buf, err_len);
				writeToStderr(err);
				Logger(err, "ERROR");
				return -1;
			}
			written += wr;
		}
		return 0;
		
	} catch (Exception e) {
		// === Обработка ошибок ядра ===
		// Три канала: C-API буфер, STDERR, файл
		copyToErrBuf(e.msg, err_buf, err_len);
		//writeToStderr(e.msg);
		Logger(e.msg, "ERROR");
		//return -1;
		stderr.writeln(e.msg);  // ← ← ← ВЕРНИТЬ: Makefile изолирует поток, дубля не будет
    	exit(1);         // ← ← ← ОБЯЗАТЕЛЬНО: код возврата 1 для харнесса
	}
}