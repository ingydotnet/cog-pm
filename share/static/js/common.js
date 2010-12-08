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
            $.get('/cache/' + id + '.html', function(data) {
                $('div.story').html(data);
            });
            $.getJSON('/cache/' + id + '.json', function(data) {
                $('h1.title').html(data['title']);
            });
        }
    },
    THE: 'END'
};

})(jQuery); // End of Wrapper

jQuery(function() {(new CogWiki()).run()});
