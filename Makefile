ARCDIR=build/archive.xcarchive
ARCDIR_RELEASE=build/archive.release.xcarchive
APPNAME=MacTcode.app
DMGNAME=MacTcode.dmg
WORKDIR=work
SIGNING_IDENTITY="Developer ID Application: Kaoru Maeda (8H7RHH924X)"
BUNDLE_ID=jp.mad-p.inputmethod.MacTcode

.PHONY: build releaseBuild reload releaseReload sign dmg notary test

build:
	xcodebuild -workspace MacTcode.xcodeproj/project.xcworkspace -scheme MacTcode clean archive -archivePath $(ARCDIR) OTHER_SWIFT_FLAGS='-D ENABLE_NSLOG'

releaseBuild $(WORKDIR)/$(APPNAME):
	rm -rf $(WORKDIR)/$(APPNAME)
	CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO xcodebuild -workspace MacTcode.xcodeproj/project.xcworkspace -scheme MacTcode clean archive -archivePath $(ARCDIR_RELEASE) -configuration Release -destination 'generic/platform=macOS'
	cp -r $(ARCDIR_RELEASE)/Products/Applications/$(APPNAME) $(WORKDIR)

reload: build
	pkill "MacTcode" || true
	sudo rm -rf /Library/Input\ Methods/$(APPNAME)
	sudo cp -r $(ARCDIR)/Products/Applications/$(APPNAME) /Library/Input\ Methods/
	mkdir -p $(WORKDIR)

releaseReload: releaseBuild
	pkill "MacTcode" || true
	sudo rm -rf /Library/Input\ Methods/$(APPNAME)
	sudo cp -r $(ARCDIR_RELEASE)/Products/Applications/$(APPNAME) /Library/Input\ Methods/

sign: $(WORKDIR)/$(APPNAME)
	codesign --deep --force --verify --verbose \
		--sign $(SIGNING_IDENTITY) $(WORKDIR)/$(APPNAME) \
		--options runtime \
		--entitlements MacTcode/MacTcode.entitlements \
		--timestamp

dmg $(WORKDIR)/$(DMGNAME): sign
	hdiutil create -volname "MacTcode" -srcfolder $(WORKDIR)/$(APPNAME) -ov -format UDZO $(WORKDIR)/$(DMGNAME)
	codesign --sign $(SIGNING_IDENTITY) --timestamp --verbose $(WORKDIR)/$(DMGNAME)

notary: dmg
	xcrun notarytool submit $(WORKDIR)/$(DMGNAME) --keychain-profile "MacTcode" --wait
	xcrun stapler staple $(WORKDIR)/$(DMGNAME)

test:
	xcodebuild -project MacTcode.xcodeproj -scheme MacTcode -destination 'platform=macOS' test
