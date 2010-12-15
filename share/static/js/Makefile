ALL_JS=\
       jquery-1.4.4.min.js \
       separator.js \
       jemplate.js \
       separator.js \
       cogwiki.js \
       separator.js \
       tag-cloud.js \
       separator.js \

#        config.js \

#        jquery-ui-1.8.7.custom.min.js \

all: all.js

all.js: $(ALL_JS) force
	cat $(ALL_JS) > $@

jemplate.js: force
	jemplate --runtime --compile ../../template/ > $@

force:
