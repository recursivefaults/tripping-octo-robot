
/*
 * GET home page.
 */

exports.index = function(req, res){
  res.render('index', { title: 'Express' });
};

exports.cleanup = function(req, res, data) {
    res.render('cleanup', {title: 'Clean up old entries', posts : data});
};

//Starts the export stuff.
exports.start =  function(req, res) {
  
};
