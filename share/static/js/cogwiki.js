(function($) { // Wrapper

CogWiki = function() {
    this.init.apply(this, arguments);
}

CogWiki.prototype = {
    init: function() {
        this.path = location.pathname;
    },
    run: function() {
        var self = this;
        if (this.path.match(/^\/story\/name\/([^\/]+)\/?/)) {
            var name = RegExp.$1
                .toLowerCase()
                .replace(/%[0-9a-fA-F]{2}/g, '_')
                .replace(/[^\w]+/g, '_')
                .replace(/_+/g, '_')
                .replace(/^_*(.*?)_*$/, '$1');
            $.get('/cache/name/' + name + '.txt', function(id) {
                self.render_page(id);
            });
        }
        else if (this.path.match(/^\/story\/([A-Z2-7]{4})/)) {
            var id = RegExp.$1;
            this.render_page(id);
        }
        else if (this.path.match(/^\/news\/?$/)) {
            $.getJSON('/cache/news.json', function(data) {
                data = {pages: data};
                Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
            });
        }
        else if (this.path.match(/^\/home\/?$/)) {
            var id = CogWiki.config.home_page_id;
            this.render_page(id);
        }
        else if (this.path.match(/^\/tags\/?$/)) {
            this.tag_cloud();
        }
        else if (this.path.match(/^\/tag\/([^\/]+)\/?/)) {
            var tag = RegExp.$1;
            $.getJSON('/cache/tag/' + tag + '.json', function(data) {
                data = {pages: data};
                Jemplate.process('page-list.html.tt', data, $('div.content')[0]);
            });
        }
        else if (this.path == '/') {
            this.story_board();
        }
        else {
            Jemplate.process('404.html.tt', null, $('div.content')[0]);
        }
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
    story_board: function() {
        $.getJSON('/cache/news.json', function(data) {
            var $content = $('div.content'); //.addClass('wide');
            var $tmp = $('<div></div>');
            for (var i = 0; i < data.length; i++) {
                var datum = {page: data[i]};
                Jemplate.process('postit.html.tt', datum, $tmp[0]);
                $content.append($tmp.children());
            }
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

jQuery(function() {(new CogWiki()).run()});
