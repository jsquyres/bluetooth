all: simpletest scanner

CC = gcc
CXX = g++
CFLAGS = -g -Wall
CXXFLAGS = $(CFLAGS)
LDFLAGS =
LIBS = -lbluetooth

#
# On Raspbian, you must first:
#
# apt-get download libbluetooth-dev
# apt-get install libbluetooth-dev
#

simpletest: simpletest.c
	$(CC) $(CXXFLAGS) $< $(LDFLAGS) $(LIBS) -o $@

.cc.o:
	$(CXX) -c $(CXXFLAGS) $?

argv.cc: argv.h
argv.o: argv.cc
scanner.o: scanner.cc

scanner: scanner.o argv.o
	$(CXX) $(CXXFLAGS) $? $(LDFLAGS) $(LIBS) -o $@

clean:
	rm -f simpletest scanner *~ *.o
