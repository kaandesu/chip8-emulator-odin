
.PHONY: build run clean

build:
	odin build . -out:main

run:
	odin run .

clean:
	rm -f main
