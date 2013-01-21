$(document).ready(function() {
    $('a.delete').click(function() {
        console.log("Click");
        var id = $(this).parent().parent().attr('id');
        console.log("ID:" + id);
        jQuery.post('/sessions/delete', {id: id}, function(data) {
            $(this).fadeOut();
        });
    });
});
