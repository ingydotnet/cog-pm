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
    },
    render_page: function(id) {
        $.getJSON('/cache/' + id + '.json', function(data) {
            Jemplate.process('story.html.tt', data, $('div.content')[0]);
            $.get('/cache/' + id + '.html', function(data) {
                $('div.story').html(data);
            });
        });
    },
    THE: 'END'
};

})(jQuery); // End of Wrapper

jQuery(function() {(new CogWiki()).run()});
