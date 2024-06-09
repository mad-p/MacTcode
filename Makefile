ARCDIR=build/archive.xcarchive
ARCDIR_RELEASE=build/archive.release.xcarchive

.PHONY: build releaseBuild reload

build:
	xcodebuild -workspace MacTcode.xcodeproj/project.xcworkspace -scheme MacTcode clean archive -archivePath $(ARCDIR)

releaseBuild:
	xcodebuild -workspace MacTcode.xcodeproj/project.xcworkspace -scheme MacTcode clean archive -archivePath $(ARCDIR_RELEASE) -configuration Release

reload: build
	pkill "MacTcode" || true
	sudo rm -rf /Library/Input\ Methods/MacTcode.app
	sudo cp -r $(ARCDIR)/Products/Applications/MacTcode.app /Library/Input\ Methods/

releaseReload: releaseBuild
	pkill "MacTcode" || true
	sudo rm -rf /Library/Input\ Methods/MacTcode.app
	sudo cp -r $(ARCDIR_RELEASE)/Products/Applications/MacTcode.app /Library/Input\ Methods/

zip: MacTcode.zip
MacTcode.zip: releaseBuild
	-rm $@
	(cd $(ARCDIR_RELEASE)/Products/Applications/; zip ../../../../$@ MacTcode.app)
