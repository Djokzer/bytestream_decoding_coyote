SRC := src/thesis.typ
OUT := thesis_pa.pdf

.PHONY: all build watch clean

all: build

build: $(OUT)

$(OUT): $(SRC) src/bibliography.bib
	typst compile $(SRC) $(OUT)

watch:
	typst watch $(SRC) $(OUT)

clean:
	rm -f $(OUT)
