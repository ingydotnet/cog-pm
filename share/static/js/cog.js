(function($) { // Wrapper

(Cog = function() {}).prototype = {
    path: location.pathname,
    url_map: {},
    page_name: 'page',

    dispatch: function() {
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
                return;
            }
        }
        Jemplate.process('404.html.tt', null, $('div.content')[0]);
        return;
    },

    redirect: function(url) {
        location = url;
    },

    home_page: function() {
        var id = this.config.home_page_id;
        this.page_display(id);
    },

    page_display: function(id) {
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
    },

    page_list: function() {
        $.getJSON('/cache/page-list.json', function(data) {
            data = {pages: data};
            data.title = 'Recent Changes';
            Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
        });
    },

    tag_list: function() {
        $.getJSON('/cache/tag-list.json', function(data) {
            data = {tags: data};
            Jemplate.process('tag-list.html.tt', data, $('div.content')[0]);
        });
    },

    tag_page_list: function(tag) {
        $.getJSON('/cache/tag/' + tag + '.json', function(data) {
            data = {pages: data};
            data.title = 'Tag: ' + tag.replace(/%20/g, ' ');
            Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
        });
    },

    page_by_name: function(name) {
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
    },

    setup_links: function() {
        var page_name = this.page_name;
        var $links = $('.content .sectionbody a')
            .each(function() {
                var $link = $(this);
                Q = $link;
                if ($link.attr('href') == 'page') {
                    $link.attr('href', '/' + page_name + '/name/' + $link.text());
                }
            });
    },

    THE: 'END'
};

})(jQuery); // End of Wrapper
