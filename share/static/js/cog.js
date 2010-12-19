(function($) { // Wrapper

(Cog = function() {}).prototype = {
    path: location.pathname,
    url_map: {},

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
        this.render_page(id);
    },

    render_page: function(id) {
        var self = this;
        $.getJSON('/cache/' + id + '.json', function(data) {
            Jemplate.process('story.html.tt', data, $('div.content')[0]);
            $.get('/cache/' + id + '.html', function(data) {
                $('div.story').html(data);
            });
            setTimeout(function() {
                self.setup_links();
            }, 500);
        });
    },

    story_board: function(status) {
        $.getJSON('/cache/news.json', function(data) {
            var $content = $('div.content'); //.addClass('wide');
            var $tmp = $('<div></div>');
            for (var i = 0; i < data.length; i++) {
                var datum = data[i];
                if (status && ! (datum.status && datum.status.toLowerCase() == status)) continue;  
                Jemplate.process('postit.html.tt', {page: datum}, $tmp[0]);
                $content.append($tmp.children());
            }
        });
    },

    news_list: function() {
        $.getJSON('/cache/news.json', function(data) {
            data = {pages: data};
            Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
        });
    },

    tag_cloud: function() {
        Jemplate.process('tag-cloud.html.tt', {}, $('div.content')[0]);
        $.getJSON('/cache/tag-cloud.json', function(data) {
            var tc = TagCloud.create();
            for (var i = 0; i < data.length; i++) {
                var tag = data[i][0];
                var num = data[i][1];
                var time = data[i][2];
                tc.add(
                    tag,
                    num,
                    '/tag/' + tag,
                    time
                )
            }
            tc.loadEffector('CountSize').base(30).range(15);
            tc.loadEffector('DateTimeColor');
            tc.setup('mytagcloud');
        });
    },

    tag_list: function(tag) {
        $.getJSON('/cache/tag/' + tag + '.json', function(data) {
            data = {pages: data};
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
            self.render_page(id);
        });
    },

    setup_links: function() {
        var $links = $('.content .sectionbody a')
            .each(function() {
                var $link = $(this);
                Q = $link;
                if ($link.attr('href') == 'story') {
                    $link.attr('href', '/story/name/' + $link.text());
                }
            });
    },

    THE: 'END'
};

})(jQuery); // End of Wrapper
