all: TCKO_32.png TCKO-k_32.png TCKO_200.png

INKSCAPE = /Applications/Inkscape.app/Contents/MacOS/inkscape

TCKO_32.png: source.svg Makefile
	$(INKSCAPE) --export-type png --export-filename $@ -w 32 $<

TCKO_200.png: source.svg Makefile
	$(INKSCAPE)  --export-type png --export-filename $@ -w 200 $<

TCKO-k_32.png: source.svg Makefile
	sed 's/"st0"/"st2"/' $< > tmp.svg
	$(INKSCAPE) --export-type png --export-filename $@ -w 32 tmp.svg
	rm -rf tmp.svg

.PHONY: clean
clean:
	rm *.png
