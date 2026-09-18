APP = build/Jev Voice.app
BINARY = .build/release/JevVoice

.PHONY: build app run test clean

build:
	swift build -c release

app: build
	mkdir -p "$(APP)/Contents/MacOS"
	cp "$(BINARY)" "$(APP)/Contents/MacOS/JevVoice"
	cp Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP)"

run: app
	open "$(APP)"

test:
	swift test

clean:
	rm -rf build .build
