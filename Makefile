.PHONY: all
all: omegajail sigsys-tracer

MINIJAIL_SOURCE_FILES := $(addprefix minijail/,\
	$(cd minijail && git ls-tree --name-only HEAD -- *.c *.c))
MINIJAIL_CORE_OBJECT_FILES := $(addprefix minijail/,$(patsubst %.o,%.pic.o,\
	libminijail.o syscall_filter.o signal_handler.o bpf.o util.o system.o \
	syscall_wrapper.o libconstants.gen.o libsyscalls.gen.o))

ARCH ?= $(shell uname -m)
CFLAGS += -Wall -Werror -O2
CXXFLAGS += -std=c++11
LDFLAGS += -lcap

ifeq ($(ARCH),amd64)
	SCRIPTS_ARCH := x86_64
else
	SCRIPTS_ARCH := $(ARCH)
endif

${MINIJAIL_CORE_OBJECT_FILES}: ${MINIJAIL_SOURCE_FILES}
	LDFLAGS= $(MAKE) OUT=${PWD}/minijail -C minijail

util.o: util.cpp util.h logging.h macros.h
	g++ $(CFLAGS) $(CXXFLAGS) -fno-exceptions $< -c -o $@

logging.o: logging.cpp logging.h util.h
	g++ $(CFLAGS) $(CXXFLAGS) -fno-exceptions $< -c -o $@

args.o: args.cpp args.h logging.h
	g++ $(CFLAGS) $(CXXFLAGS) -fexceptions -I cxxopts/include $< -c -o $@

omegajail: main.cpp ${MINIJAIL_CORE_OBJECT_FILES} args.o util.o logging.o
	g++ $(CFLAGS) $(CXXFLAGS) -fno-exceptions $^ $(LDFLAGS) -o $@

sigsys-tracer: sigsys_tracer.cpp ${MINIJAIL_CORE_OBJECT_FILES} util.o logging.o
	g++ $(CFLAGS) $(CXXFLAGS) -fno-exceptions $^ $(LDFLAGS) -o $@

.PHONY: install
install: omegajail omegajail-setup sigsys-tracer
	install -d $(DESTDIR)/var/lib/omegajail/bin
	install -t $(DESTDIR)/var/lib/omegajail/bin $^
	install -d $(DESTDIR)/var/lib/omegajail/scripts
	install -t $(DESTDIR)/var/lib/omegajail/scripts -m 0644 scripts/$(SCRIPTS_ARCH)/*

.PHONY: clean
clean:
	rm -f omegajail sigsys-tracer *.o
	$(MAKE) OUT=${PWD}/minijail -C minijail clean
