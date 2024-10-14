
.PHONY: build run clean

build:
	odin build . -out:main

run:
	@odin run . -out:main

clean:
	rm -f main
