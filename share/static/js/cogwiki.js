(function($) { // Wrapper

CogWiki = function() {
    this.init.apply(this, arguments);
}

CogWiki.prototype = {
    init: function() {
        this.path = location.pathname;
    },
    run: function() {
        if (this.path.match(/^\/story\/([A-Z2-7]{4})/)) {
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
        else if (this.path == '/') {
            this.story_board();
        }
        else {
            Jemplate.process('404.html.tt', null, $('div.content')[0]);
        }
    },
    render_page: function(id) {
        $.getJSON('/cache/' + id + '.json', function(data) {
            Jemplate.process('story.html.tt', data, $('div.content')[0]);
            $.get('/cache/' + id + '.html', function(data) {
                $('div.story').html(data);
            });
        });
    },
    story_board: function() {
        $.getJSON('/cache/news.json', function(data) {
            var $content = $('div.content').addClass('wide');
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
            for (var tag in data) {
                num = data[tag];
                tc.add(
                    tag,
                    num,
                    '/tag/' + tag,
                    Date.parse('2010/12/25 00:00:00')
                )
            }
            tc.loadEffector('CountSize').base(30).range(8);
            /*tc.loadEffector('DateTimeColor');*/
            tc.setup('mytagcloud');
        });
    },
    THE: 'END'
};

})(jQuery); // End of Wrapper

jQuery(function() {(new CogWiki()).run()});
