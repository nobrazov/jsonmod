// main.d — Exec-обёртка (pipe-entry point)
// Exec wrapper (pipe-entry point)
// Exec 包装器（管道入口点）

module main;

import core.sys.posix.unistd;
import core.stdc.stdio;
import api; // C-API ядра

// Исправлено: int main() вместо void. Возврат кода ошибки напрямую.
// Fixed: int main() instead of void. Returns error code directly.
// 修复：使用 int main() 替代 void。直接返回错误码。
int main() {
    char[512] errBuf;
    int rc = jsonmod_run(STDIN_FILENO, STDOUT_FILENO, errBuf.ptr, errBuf.length);
    
    if (rc != 0) {
        // Ошибки строго в STDERR. В STDOUT только валидный JSON.
        // Errors strictly to STDERR. STDOUT only valid JSON.
        // 错误严格输出到 STDERR。STDOUT 仅输出有效的 JSON。
        size_t len = 0;
        while (len < errBuf.length && errBuf[len] != '\0') len++;
        fprintf(stderr, "JSONmod error: %.*s\n", cast(int)len, errBuf.ptr);
        return rc; // Рантайм D корректно завершит процесс с этим кодом
    }
    return 0;
}