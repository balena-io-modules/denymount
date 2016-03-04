var execFile = require('child_process').execFile;
var path = require('path');

var EXECUTABLE_PATH = path.join(__dirname, 'bin', 'denymount');

// Callback must be in the form (error) -> Void
module.exports = function(disk, callback) {
  if (!disk) {
    throw new Error('`disk` cannot be empty.');
  }

  if (disk.indexOf('/') !== -1) {
    throw new Error("`disk` cannot be the device path; it must be the disk's BSD name (eg. 'disk3').");
  }

  var childProcess = execFile(EXECUTABLE_PATH, [ disk ]);

  childProcess.on('exit', function(status, signal) {
    var error = null;
    if (status) {
      error = new Error('Command failed: ' + status);
    } else if (signal) {
      error = new Error('Command killed by signal: ' + signal);
    }
    callback && callback(error);
  });

  return function() {
    childProcess && childProcess.kill(); // sends SIGTERM
  };
};
