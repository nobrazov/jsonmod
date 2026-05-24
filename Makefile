# ==============================================================================
# JSONmod Build System — OCP-compliant registry
# Сборка JSONmod — реестр с поддержкой OCP
# JSONmod 构建系统 — 支持 OCP 的注册表
# ==============================================================================
# Принцип: расширение без правки этого файла. Правки только в incoming.mk / outgoing.mk
# Principle: extend without modifying this file. Changes only in incoming.mk / outgoing.mk
# 原则：无需修改此文件即可扩展。仅在 incoming.mk / outgoing.mk 中更改

# --- Compiler & flags ---------------------------------------------------------
# Компилятор и флаги / Compiler and flags / 编译器和标志
DCC        := gdc
DCCFLAGS   := -Wall -Wextra -Os -fPIC -Isrc -I/usr/include/json-c \
              -fdata-sections -ffunction-sections -flto
# В v0.1 достаточно json-c. -lpq добавлен для v0.3 (postgres).
# Если libpq-dev не установлен, уберите -lpq из этой строки.
DLIBS      := -L/usr/lib/arm-linux-gnueabihf -ljson-c -lpq
LDFLAGS_A  := -static-libgcc -static-libphobos -s \
              -Wl,--gc-sections -Wl,--strip-all -Wl,-O1 -Wl,--as-needed
LDFLAGS_SO := -shared -fPIC -s -Wl,--gc-sections -Wl,-O1

# --- OCP Registry: include user-editable lists --------------------------------
# OCP-реестр: подключаем редактируемые списки / OCP registry: include editable lists
# OCP 注册表：包含用户可编辑的列表
-include incoming.mk
-include outgoing.mk

# --- Default module list (core + exec) ----------------------------------------
# Базовый список модулей (ядро + exec) / Default module list (core + exec)
# 默认模块列表（核心 + exec）
# ВНИМАНИЕ: core.d заменён на jsonmod_core.d для избежания конфликта с Phobos
COMMON_MODULES := src/jsonmod_core.d src/merger.d src/api.d src/logger.d src/exec/main.d
PROTOCOL_MODULES := $(wildcard src/protocols/*.d)
PROTOCOL_OBJS := $(PROTOCOL_MODULES:.d=.o)

# --- Build active list: common + incoming - outgoing --------------------------
# Формируем активный список: общие + прибывшие - убывшие
# Build active list: common + incoming - outgoing
# 构建活动列表：通用 + 新增 - 移除
MODULES := $(filter-out $(outgoing), $(sort $(COMMON_MODULES) $(incoming))) $(PROTOCOL_OBJS)

# RU: Авто-обнаружение модулей протоколов
# EN: Auto-discover protocol modules
# ZH: 自动发现协议模块

# Разделяем модули ядра и exec-обёртки
# Separate library modules and exec wrapper
# 分离库模块和 exec 包装器
LIB_MODS  := $(filter-out src/exec/%,$(MODULES))
EXEC_MODS := $(filter src/exec/%,$(MODULES))

LIB_SRCS  := $(LIB_MODS)
LIB_OBJS  := $(LIB_SRCS:.d=.o)

EXEC_SRCS := $(EXEC_MODS)
EXEC_OBJS := $(EXEC_SRCS:.d=.o)

# --- Targets ------------------------------------------------------------------
# Цели / Targets / 目标
.DEFAULT_GOAL := all
.PHONY: all libjsonmod.a libjsonmod.so exec perl-driver test clean help

# По умолчанию: собрать всё + запустить тест
# Default: build all + run test
# 默认：构建全部 + 运行测试
all: libjsonmod.a libjsonmod.so exec perl-driver
	@echo "✅ Build & Test complete | ✅ Сборка и тест завершены | ✅ 构建与测试完成"

# Статическая библиотека / Static library / 静态库
libjsonmod.a: $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)
	@echo "✓ libjsonmod.a built | ✓ libjsonmod.a собрана | ✓ libjsonmod.a 已构建"

# Динамическая библиотека (для Perl XS) / Dynamic library (for Perl XS)
# 动态库（用于 Perl XS）
libjsonmod.so: $(LIB_OBJS)
	$(DCC) $(LDFLAGS_SO) -o $@ $(LIB_OBJS) $(DLIBS)
	@echo "✓ libjsonmod.so built | ✓ libjsonmod.so собрана | ✓ libjsonmod.so 已构建"

# Exec-обёртка (pipe-entry point) / Exec wrapper (pipe-entry point)
# Exec 包装器（管道入口点）
# RU: Для -flto линкуем все .o напрямую, чтобы LTO видел _ModuleInfoZ каждого модуля
# EN: For -flto, link all .o directly so LTO sees _ModuleInfoZ of every module
# ZH: 使用 -flto 时直接链接所有 .o，确保 LTO 能识别每个模块的 _ModuleInfoZ
exec: $(LIB_OBJS) $(EXEC_OBJS)
	$(DCC) $(DCCFLAGS) $(LDFLAGS_A) -Wl,-rpath,'$$ORIGIN' -o jsonmod $(LIB_OBJS) $(EXEC_OBJS) $(DLIBS)
	@echo "✓ jsonmod built | ✓ jsonmod собран | ✓ jsonmod 已构建"

# Perl-драйвер: делегирование в поддиректорию
perl-driver: libjsonmod.so
	@echo "→ Delegating Perl build to Makefile.PL..."
	@cd drivers/perl && rm -f Makefile MYMETA.* blib/ && LIBJSONMOD_SO=$(CURDIR)/libjsonmod.so perl Makefile.PL
	$(MAKE) -C drivers/perl

# RU: Приёмочные тесты: строгая проверка exit code + валидация jq
# EN: Acceptance tests: strict exit code check + jq validation
# ZH: 验收测试：严格检查退出码 + jq 验证
test: jsonmod
	@echo "→ Running acceptance tests... | → Запуск тестов... | → 运行测试..."
	@pass=0; fail=0; \
	for f in test/*.jsonmod; do \
		./jsonmod < "$$f" > /tmp/jm_ok.txt 2> /tmp/jm_err.txt; \
		rc=$$?; \
		if [ $$rc -eq 0 ]; then \
			echo "✓ $$f"; \
			cat /tmp/jm_ok.txt | jq -C .; \
			echo "─────────────────────────────────────"; \
			pass=$$((pass+1)); \
		else \
			cat /tmp/jm_err.txt; \
			echo "✗ $$f"; \
			fail=$$((fail+1)); \
		fi; \
		rm -f /tmp/jm_ok.txt /tmp/jm_err.txt; \
	done; \
	echo "✅ $$pass passed | ❌ $$fail failed"; \
	[ $$fail -eq 0 ] || exit 1

# Очистка / Clean / 清理
clean:
	rm -f src/*.o src/protocols/*.o src/exec/*.o libjsonmod.a libjsonmod.so jsonmod
	rm -rf drivers/perl/Makefile drivers/perl/MYMETA.* drivers/perl/blib drivers/perl/JSONmod.c drivers/perl/*.o drivers/perl/*.so
	@echo "✓ Cleaned | ✓ Очищено | ✓ 已清理"

# --- Compilation rules --------------------------------------------------------
# Правила компиляции / Compilation rules / 编译规则
src/%.o: src/%.d
	$(DCC) $(DCCFLAGS) -c $< -o $@

# --- Help ---------------------------------------------------------------------
# Справка / Help / 帮助
help:
	@echo "JSONmod Build Targets:"
	@echo "  make               — build all + test | собрать всё + тест | 构建全部 + 测试"
	@echo "  make libjsonmod.a  — static library | статическая библиотека | 静态库"
	@echo "  make libjsonmod.so — dynamic library | динамическая библиотека | 动态库"
	@echo "  make exec          — pipe utility 'jsonmod' | утилита 'jsonmod' | 管道工具 'jsonmod'"
	@echo "  make perl-driver   — build Perl XS wrapper | собрать Perl XS-обёртку | 构建 Perl XS 包装器"
	@echo "  make test          — run jq acceptance test | запустить тест с jq | 运行 jq 验收测试"
	@echo "  make clean         — remove build artifacts | удалить артефакты сборки | 清除构建产物"
	@echo ""
	@echo "OCP Registry:"
	@echo "  Add module:   echo 'src/protocols/new.d' >> incoming.mk"
	@echo "  Remove:       echo 'src/old.d' >> outgoing.mk"
	@echo "  Active list:  computed automatically (common + incoming - outgoing)"