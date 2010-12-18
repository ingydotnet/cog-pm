(function($) { // Wrapper

(Cog = function() {}).prototype = {
    path: location.pathname,

    dispatch: function() {
        if (this.path == '/') {
            location = '/story/board'
        }
        else if (this.path.match(/^\/story\/name\/([^\/]+)\/?/)) {
            this.page_by_name(RegExp.$1);
        }
        else if (this.path.match(/^\/story\/([A-Z2-7]{4})/)) {
            this.render_page(RegExp.$1);
        }
        else if (this.path.match(/^\/news\/?$/)) {
            this.render_news();
        }
        else if (this.path.match(/^\/home\/?$/)) {
            var id = Cog.config.home_page_id;
            this.render_page(id);
        }
        else if (this.path.match(/^\/tags\/?$/)) {
            this.tag_cloud();
        }
        else if (this.path.match(/^\/tag\/([^\/]+)\/?/)) {
            this.render_tag_list(RegExp.$1);
        }
        else if (this.path.match(/^\/story\/board\/([^\/]+)\/?/)) {
            this.story_board(RegExp.$1);
        }
        else if (this.path.match(/^\/story\/board\/?/)) {
            this.story_board(null);
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
    render_news: function() {
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
    render_tag_list: function(tag) {
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

jQuery(function() {(new Cog()).dispatch()});
