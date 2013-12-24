all: simpletest

#
# On Raspbian, you must first:
#
# apt-get download libbluetooth-dev
# apt-get install libbluetooth-dev
#

simpletest: simpletest.c
	$(CC) simpletest.c -g -lbluetooth -o simpletest

clean:
	rm -f simpletest
