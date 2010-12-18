ALL_JS=\
       jquery-1.4.4.min.js \
       separator.js \
       jemplate.js \
       separator.js \
       cog.js \
       sidepanel.js \
       tag-cloud.js \

all: all.js

all.js: $(ALL_JS) force
	cat $(ALL_JS) > $@

jemplate.js: force
	jemplate --runtime --compile ../../template/ > $@

force:
