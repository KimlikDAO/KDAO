all: TCKO_32.png TCKO-k_32.png

logo32.png: source.svg
	/Applications/Inkscape.app/Contents/MacOS/inkscape --export-type png --export-filename $@ -w 32 $^

TCKO_32.png: logo32.png
	cp $^ $@

TCKO-k_32.png: source.svg
	sed 's/"st0"/"st2"/' $^ > tmp.svg
	/Applications/Inkscape.app/Contents/MacOS/inkscape --export-type png --export-filename $@ -w 32 tmp.svg
	rm -rf tmp.svg