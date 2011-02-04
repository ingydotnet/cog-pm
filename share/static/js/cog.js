// TODO:
// - Add a url decoder/encoder

// $Cog is the Cog prototype object. You can use it anywhere to extend Cog.

$Cog = (Cog = function() {this.init()}).prototype = {
    path: location.pathname,
    url_map: {},
    setup_functions: [],
    busy: false
};

$Cog.init = function() {
    var funcs = this.setup_functions;
    for (var i = 0, l = funcs.length; i < l; i++) {
        funcs[i].apply(this);
    }
};

$Cog.dispatch = function() {
    var map = this.url_map;
    for (var i = 0, il = map.length; i < il; i++) {
        var re = map[i][0];
        var regex = new RegExp('^' + re + '$');
        var method = map[i][1];
        var args = map[i].splice(2);
        var m = this.path.match(regex);
        if (m) {
            for (var j = 0, jl = args.length; j < jl; j++) {
                args[j] = args[j].replace(/^\$(\d)$/, function(x, d) { return m[Number(d)] });
            }
            this[method].apply(this, args);
            if (this.path.length > 1) {
                $.cookie("last_url", this.path, {path:'/'});
            }
            return;
        }
    }
    Jemplate.process('404.html.tt', null, $('div.content')[0]);
    return;
};

$Cog.redirect = function(url) {
    location = url;
};

$Cog.home_page = function() {
    var id = this.config.home_page_id;
    this.page_display(id);
};

$Cog.page_display = function(id) {
    var self = this;
    $.getJSON('/cache/' + id + '.json', function(data) {
        Jemplate.process('page-display.html.tt', data, $('div.content')[0]);
        $.get('/cache/' + id + '.html', function(data) {
            $('div.page').html(data);
        });
        setTimeout(function() {
            self.setup_links();
        }, 500);
    });
};

$Cog.page_list = function(title) {
    $.getJSON('/cache/page-list.json', function(data) {
        data = {pages: data};
        data.title = title,
        Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
    });
};

$Cog.tag_list = function() {
    $.getJSON('/cache/tag-list.json', function(data) {
        data = {tags: data};
        Jemplate.process('tag-list.html.tt', data, $('div.content')[0]);
    });
};

$Cog.tag_page_list = function(tag) {
    $.getJSON('/cache/tag/' + tag + '.json', function(data) {
        data = {pages: data};
        data.title = 'Tag: ' + tag.replace(/%20/g, ' ');
        Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
    });
};

$Cog.page_by_name = function(name) {
    var self = this;
    var name = name
        .toLowerCase()
        .replace(/%[0-9a-fA-F]{2}/g, '_')
        .replace(/[^\w]+/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_*(.*?)_*$/, '$1');
    $.get('/cache/name/' + name + '.txt', function(id) {
        self.page_display(id);
    });
};

$Cog.setup_links = function() {
    var $links = $('.content .sectionbody a')
        .each(function() {
            var $link = $(this);
            if ($link.attr('href') == 'page') {
                $link.attr('href', '/page/name/' + $link.text());
            }
        });
};
