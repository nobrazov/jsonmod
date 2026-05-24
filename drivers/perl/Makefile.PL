#!/usr/bin/perl
use strict;
use warnings;
use ExtUtils::MakeMaker;

# Читаем путь из окружения (как передал Makefile)
my $lib = $ENV{LIBJSONMOD_SO} || die "FATAL: LIBJSONMOD_SO env var not set\n";
my $dir = $lib; 
$dir =~ s|/[^/]+$||; # Отсекаем имя файла, оставляем директорию

WriteMakefile(
    NAME    => 'JSONmod',
    VERSION => '0.1',
    XS      => {'JSONmod.xs' => 'JSONmod.c'},
    LIBS    => ["-L$dir -ljsonmod -ljson-c -lpq"],
    clean   => {FILES => 'JSONmod.c *.o *.so blib/'},
    PREREQ_PM => {'ExtUtils::MakeMaker' => 0, 'XSLoader' => 0},
);
# НИКАКОГО postamble. ExtUtils::MakeMaker сам генерирует валидный Makefile с нативными TAB.