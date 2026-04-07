generate:
    xcodegen generate

build:
    xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'generic/platform=iOS' build

test:
    swift test

test-ios:
    xcodebuild test -project splitspeak.xcodeproj -scheme splitspeak -destination 'platform=iOS Simulator,name=iPhone 15'

clean:
    rm -rf splitspeak.xcodeproj
    rm -rf .build
