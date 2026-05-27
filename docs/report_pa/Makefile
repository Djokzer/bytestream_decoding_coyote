SRC := src/report.typ
OUT := thesis_pa.pdf

.PHONY: all build watch clean

all: build

build: $(OUT)

DEPS := src/bibliography.bib src/mse-thesis-template.typ $(wildcard src/imgs/*)

$(OUT): $(SRC) $(DEPS)
	typst compile $(SRC) $(OUT)

watch:
	typst watch $(SRC) $(OUT)

clean:
	rm -f $(OUT)
