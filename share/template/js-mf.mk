ROOT=../..

ALL_JS=[% list %]

all: clean all_file

all_file: all.js
	(FILENAME=`cat $< | perl -MDigest::MD5 -e 'my $$d = Digest::MD5->new; $$d->addfile(*STDIN); print $$d->hexdigest'`;mv $< all-$$FILENAME.js)

all.js: $(ALL_JS)
	cat $(ALL_JS) > $@

jemplate.js:
	jemplate --runtime --compile $(ROOT)/template/ > $@

config.js: $(ROOT)/static/config.js
	cp $< $@

url-map.js: $(ROOT)/static/url-map.js
	cp $< $@

%.js: ../../coffee/%.coffee
	coffee --compile --print $< > $@

clean:
	rm -f all*.js jemplate.js
