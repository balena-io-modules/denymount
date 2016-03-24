bin/denymount: src/build/Release/denymount
	cp -p $< $@

src/build/Release/denymount: src/denymount.xcodeproj
	xcodebuild \
		-project $< \
		-target denymount \
		-configuration Release

clean:
	rm -rf src/build/
