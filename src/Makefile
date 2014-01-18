all: simpletest scanner

CC = gcc
CXX = g++
CFLAGS = -g -Wall
LDFLAGS =
LIBS = -lbluetooth

#
# On Raspbian, you must first:
#
# apt-get download libbluetooth-dev
# apt-get install libbluetooth-dev
#

simpletest: simpletest.c
	$(CC) $(CFLAGS) $< $(LDFLAGS) $(LIBS) -o $@

argv.cc: argv.h
scanner: scanner.cc argv.cc
	$(CXX) $(CFLAGS) $? $(LDFLAGS) $(LIBS) -o $@

clean:
	rm -f simpletest scanner *~ *.o
