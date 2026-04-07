# justfile for splitspeak

# Default recipe - show help
default:
    @just --list

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build for iOS Simulator
build-sim:
    xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build for generic iOS device (requires Xcode to have destination)
build-ios:
    xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build

# Run tests via swift test (macOS)
test:
    swift test

# Run tests on iOS Simulator
test-ios:
    xcodebuild test -project splitspeak.xcodeproj -scheme splitspeak -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build and run on connected iPhone
# Requires:
#   1. iPhone connected via USB
#   2. Apple ID added in Xcode (free personal team works)
#   3. iOS platform version installed in Xcode
run-iphone:
    xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build

# Clean build artifacts
clean:
    rm -rf splitspeak.xcodeproj
    rm -rf .build
    rm -rf .swiftpm

# Full setup: generate project + run tests
setup: generate test
