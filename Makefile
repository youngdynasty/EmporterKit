all: EmporterKit/Emporter-Bridge.h

EmporterKit/Emporter-Bridge.h: SEARCH_PATH_FLAG := $(shell if [ -n "$(DEBUG)" ]; then echo "-onlyin ~/Library"; fi)
EmporterKit/Emporter-Bridge.h: EMPORTER_PATH := $(shell mdfind $(SEARCH_PATH_FLAG) "kMDItemCFBundleIdentifier = net.youngdynasty.emporter.mas" | head -n 1)
EmporterKit/Emporter-Bridge.h:
	@echo "Generating scripting bridge header from $(EMPORTER_PATH)..."
	@sdef "$(EMPORTER_PATH)" | sdp -fh --basename Emporter -o EmporterKit/Emporter-Bridge.h

clean:
	rm EmporterKit/Emporter-Bridge.h
