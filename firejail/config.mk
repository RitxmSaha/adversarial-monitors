# config.mk.  Generated from config.mk.in by configure.
#
# Configure-time variable definitions and any other common definition that can
# be safely included by all makefiles.
#
# Note: Do not define any targets on this file, as that could potentially end
# up overriding the includer's intended default target (which by default is the
# first target encountered).
MAKEFLAGS += -r

NAME=firejail
TARNAME=firejail
PACKAGE_TARNAME=firejail # needed by docdir
VERSION=0.9.73

prefix=/usr/local
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
libdir=${exec_prefix}/lib
datarootdir=${prefix}/share
docdir=${datarootdir}/doc/${PACKAGE_TARNAME}
mandir=${datarootdir}/man
sysconfdir=${prefix}/etc

# Misc flags
BUSYBOX_WORKAROUND=no
HAVE_CONTRIB_INSTALL=yes
HAVE_FATAL_WARNINGS=
HAVE_GCOV=
HAVE_MAN=-DHAVE_MAN

# MANFLAGS
HAVE_APPARMOR=
HAVE_CHROOT=-DHAVE_CHROOT
HAVE_DBUSPROXY=-DHAVE_DBUSPROXY
HAVE_FILE_TRANSFER=-DHAVE_FILE_TRANSFER
HAVE_FORCE_NONEWPRIVS=
HAVE_GLOBALCFG=-DHAVE_GLOBALCFG
HAVE_IDS=
HAVE_LANDLOCK=-DHAVE_LANDLOCK
HAVE_NETWORK=-DHAVE_NETWORK
HAVE_ONLY_SYSCFG_PROFILES=
HAVE_OUTPUT=-DHAVE_OUTPUT
HAVE_OVERLAYFS=
HAVE_PRIVATE_HOME=-DHAVE_PRIVATE_HOME
HAVE_PRIVATE_LIB=
HAVE_SANDBOX_CHECK=-DHAVE_SANDBOX_CHECK
HAVE_SELINUX=
HAVE_SUID=-DHAVE_SUID
HAVE_USERNS=-DHAVE_USERNS
HAVE_USERTMPFS=-DHAVE_USERTMPFS
HAVE_X11=-DHAVE_X11

MANFLAGS = \
	$(HAVE_APPARMOR) \
	$(HAVE_CHROOT) \
	$(HAVE_DBUSPROXY) \
	$(HAVE_FILE_TRANSFER) \
	$(HAVE_FORCE_NONEWPRIVS) \
	$(HAVE_GLOBALCFG) \
	$(HAVE_IDS) \
	$(HAVE_LANDLOCK) \
	$(HAVE_NETWORK) \
	$(HAVE_ONLY_SYSCFG_PROFILES) \
	$(HAVE_OUTPUT) \
	$(HAVE_OVERLAYFS) \
	$(HAVE_PRIVATE_HOME) \
	$(HAVE_PRIVATE_LIB) \
	$(HAVE_SANDBOX_CHECK) \
	$(HAVE_SELINUX) \
	$(HAVE_SUID) \
	$(HAVE_USERNS) \
	$(HAVE_USERTMPFS) \
	$(HAVE_X11)

# User variables - should not be modified in the code (as they are reserved for
# the user building the package); see the following for details:
# https://www.gnu.org/software/automake/manual/1.16.5/html_node/User-Variables.html
CC=gcc
CODESPELL=
CPPCHECK=
GAWK=gawk
GZIP=gzip
SCAN_BUILD=
STRIP=strip
TAR=tar

CFLAGS=-g -O2
CPPFLAGS=
LDFLAGS=

# Project variables
EXTRA_CFLAGS  = -D_FORTIFY_SOURCE=2 -fstack-clash-protection -fstack-protector-strong
DEPS_CFLAGS   = -MMD -MP
COMMON_CFLAGS = \
	-ggdb -O2 -DVERSION='"$(VERSION)"' \
	-Wall -Wextra $(HAVE_FATAL_WARNINGS) \
	-Wformat -Wformat-security \
	-fstack-protector-all \
	-DPREFIX='"$(prefix)"' -DSYSCONFDIR='"$(sysconfdir)/firejail"' \
	-DLIBDIR='"$(libdir)"' -DBINDIR='"$(bindir)"' \
	-DVARDIR='"/var/lib/firejail"'

PROG_CFLAGS = \
	$(COMMON_CFLAGS) \
	$(HAVE_GCOV) $(MANFLAGS) \
	$(EXTRA_CFLAGS) \
	$(DEPS_CFLAGS) \
	-fPIE

SO_CFLAGS = \
	$(COMMON_CFLAGS) \
	$(DEPS_CFLAGS) \
	-fPIC

EXTRA_LDFLAGS =
PROG_LDFLAGS  = -Wl,-z,relro -Wl,-z,now -fPIE -pie $(EXTRA_LDFLAGS)
SO_LDFLAGS    = -Wl,-z,relro -Wl,-z,now -fPIC
LIBS =

CLEANFILES = *.d *.o *.gcov *.gcda *.gcno *.plist
