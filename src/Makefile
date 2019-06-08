# Makefile for ship2mgd77 project
# Compiles the two C files lopassvel.c and udmerge.c
# Just type "make all" and the script and programs will
# be installed in the bin directory at the top leve.

CFLAGs=-Wall

all:	dir moveC copyS

dir:
	mkdir -p ../bin

moveC:	lopassvel udmerge
	mv lopassvel udmerge ../bin

copyS:
	cp -f ship2mgd77.sh ../bin

clean:
	rm -rf ../bin

spotless:	clean
