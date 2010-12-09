(function($) { // Wrapper

CogWiki = function() {
    this.init.apply(this, arguments);
}

CogWiki.prototype = {
    init: function() {
        this.path = location.pathname;
    },
    run: function() {
        if (this.path.match(/^\/stories\/([A-Z2-7]{4})/)) {
            var id = RegExp.$1;
            $.getJSON('/cache/' + id + '.json', function(data) {
                Jemplate.process('story.html.tt', data, $('div.content')[0]);
                $.get('/cache/' + id + '.html', function(data) {
                    $('div.story').html(data);
                });
            });
        }
        else if (this.path.match(/^\/stories\/?$/)) {
            $.getJSON('/cache/changes.json', function(data) {
                data = {pages: data};
                Jemplate.process('changes.html.tt', data, $('div.content')[0]);
            });
        }
    },
    THE: 'END'
};

})(jQuery); // End of Wrapper

jQuery(function() {(new CogWiki()).run()});
