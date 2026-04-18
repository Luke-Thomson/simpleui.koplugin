ZIP_NAME = simpleui.koplugin.zip
ROOT_DIR = simpleui.koplugin

.PHONY: clean build clean

build:
	@echo ">> Building $(ZIP_NAME)"
	@rm -f $(ZIP_NAME)
	@mkdir -p $(ROOT_DIR)

	# Copy everything except ignored items into ROOT_DIR
	@rsync -av \
		--exclude '.git' \
		--exclude '.github' \
		--exclude 'Makefile' \
		--exclude '.DS_Store' \
		--exclude '.gitignore' \
		--exclude 'CONTRIBUTING.md' \
		--exclude 'LICENSE' \
		--exclude 'README.md' \
		--exclude 'extract_strings.py' \
		--exclude '$(ZIP_NAME)' \
		./ $(ROOT_DIR)

	# Zip the ROOT_DIR as the top-level folder
	@zip -r $(ZIP_NAME) $(ROOT_DIR)

	@echo ">> Done!"

clean:
	@rm -rf $(ROOT_DIR) $(ZIP_NAME)
