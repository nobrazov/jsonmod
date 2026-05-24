#!/usr/bin/perl
use strict;
use warnings;
use ExtUtils::MakeMaker;

my $libjsonmod_so = $ENV{LIBJSONMOD_SO} || '/usr/local/lib/libjsonmod.so';
my $lib_dir = $libjsonmod_so;
$lib_dir =~ s|/[^/]+$||; # Безопасно для всех версий Perl

die "✗ libjsonmod.so not found at '$libjsonmod_so'\n" .
    "  Set LIBJSONMOD_SO env var or install libjsonmod\n" .
    "  | ✗ libjsonmod.so не найдена по пути '$libjsonmod_so'\n" .
    "    Укажите переменную LIBJSONMOD_SO или установите libjsonmod\n" .
    "  | ✗ 未在 '$libjsonmod_so' 找到 libjsonmod.so\n" .
    "    设置 LIBJSONMOD_SO 环境变量或安装 libjsonmod\n"
    unless -f $libjsonmod_so;

WriteMakefile(
    NAME         => 'JSONmod',
    VERSION_FROM => 'lib/JSONmod.pm',
    ABSTRACT     => 'Perl binding for JSONmod C API',
    AUTHOR       => 'nobrazov',
    LICENSE      => 'apache_2_0',
    CCFLAGS      => "-Wall -Wextra -I/usr/include",
    LDDLFLAGS    => "-shared -L$lib_dir -ljsonmod -ljson-c -lpq",
    XS           => {'JSONmod.xs' => 'JSONmod.c'},
    clean        => {FILES => 'JSONmod.c *.o *.so blib/'},
    PREREQ_PM    => {'ExtUtils::MakeMaker' => 0, 'XSLoader' => 0},
);