SRC := src/report.typ
OUT := KandiahAbivarman_rapport_MSE_PA_SP26.pdf

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
