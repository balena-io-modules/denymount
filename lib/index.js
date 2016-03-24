/*
 * Copyright 2016 Resin.io
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var execFile = require('child_process').execFile;
var path = require('path');
var utils = require('./utils');

var EXECUTABLE_PATH = path.join(__dirname, '..', 'bin', 'denymount');

// Callback must be in the form (error) -> Void
module.exports = function(disk, handler, callback) {
  if (!disk) {
    throw new Error('`disk` cannot be empty.');
  }

  disk = utils.getDeviceBSDName(disk);

  var childProcess = execFile(EXECUTABLE_PATH, [ disk ]);

  handler(function(error, value) {
    if (error) {
      return callback(error);
    }

    childProcess && childProcess.kill();
    return callback(null, value);
  });

  childProcess.on('exit', function(status, signal) {
    var error = null;
    if (status) {
      error = new Error('Command failed: ' + status);
    } else if (signal) {
      error = new Error('Command killed by signal: ' + signal);
    }
    callback && callback(error);
  });
};
