#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
// ppport.h удален — не требуется для Perl 5.36 и отсутствует в системе

// Прототип C-API
extern int jsonmod_run(int in_fd, int out_fd, char* err_buf, size_t err_len);

MODULE = JSONmod  PACKAGE = JSONmod

void
run(IN, OUT)
    SV* IN
    SV* OUT
PREINIT:
    int in_fd, out_fd;
    char err_buf[1024];
    int rc;
CODE:
    // Проверка, что переданы файловые дескрипторы
    if (!SvROK(IN) || !SvROK(OUT))
        croak("JSONmod::run requires filehandle references");

    // Извлечение POSIX-дескрипторов
    in_fd  = PerlIO_fileno(IoIFP(SvRV(IN)));
    out_fd = PerlIO_fileno(IoIFP(SvRV(OUT)));

    if (in_fd < 0 || out_fd < 0)
        croak("Invalid filehandle passed to JSONmod::run");

    // Очистка буфера
    memset(err_buf, 0, sizeof(err_buf));

    // Вызов ядра
    rc = jsonmod_run(in_fd, out_fd, err_buf, sizeof(err_buf));

    // Маппинг ошибок
    if (rc != 0) {
        croak("JSONmod error [%d]: %s", rc, err_buf[0] ? err_buf : "unknown");
    }
    XSRETURN_YES;