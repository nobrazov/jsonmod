module Logger;

import std.datetime.systime : Clock;
import std.file : append, write, exists;

/**
 * Записывает сообщение в лог‑файл с временной меткой
 *
 * Parameters:
 *   message — текст сообщения для записи
 *   filePath — путь к файлу лога (по умолчанию "app.log")
 *   level — уровень логирования (по умолчанию "INFO")
 */
// RU: Запись только в файл, без дублирования в STDERR
// EN: Write to file only, no STDERR duplication
// ZH: 仅写入文件，不重复输出到 STDERR
void Logger(string message, string level = "INFO") {
	
	auto timestamp = Clock.currTime().toISOExtString();
	auto line = "[" ~ timestamp ~ "] [" ~ level ~ "] " ~ message ~ "\n";
	
	// ← ← ← УДАЛИТЬ или закомментировать вывод в STDERR:
	// stderr.write("jsonmod error: " ~ message ~ "\n");
	
	// Оставляем только запись в файл:
	auto logPath = "jsonmod.log";
	if (exists(logPath)) {
		append(logPath, line);
	} else {
		write(logPath, line);
	}
}
//import logger;

//void main() {
//    // Простые записи в лог (используются значения по умолчанию: файл "app.log", уровень "INFO")
//    Logger("Приложение запущено");
//    Logger("Инициализация завершена успешно");

//    // Запись с указанием уровня логирования
//    Logger("Предупреждение: низкая память", level: "WARNING");
//    Logger("Критическая ошибка: не удалось подключиться к БД", level: "ERROR");

//    // Запись в другой файл лога
//    Logger("Отладочная информация", filePath: "debug.log", level: "DEBUG");
//    Logger("Тестирование записи в отдельный файл", filePath: "debug.log");
//}
