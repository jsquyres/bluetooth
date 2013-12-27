all: simpletest scanner

CC = gcc
CXX = g++
CFLAGS = -g
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

scanner: scanner.cc
	$(CXX) $(CFLAGS) $< $(LDFLAGS) $(LIBS) -o $@

clean:
	rm -f simpletest scanner
