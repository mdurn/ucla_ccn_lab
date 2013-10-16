%  Created by Michael Durnhofer on 2010-09-13.
%  Copyright (c) 2010 Center for Cognitive Neuroscience. All rights reserved.
%
%   This file is part of @Headtracker.
%
%   Headtracker is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   Foobar is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

function [ rpy_array ] = Calibrate(obj)
  obj.calibration = [ 0 0 0 0 0 0 0 ];
  obj.debug('Calibrating Head Position');
  obj.GetScannerHeadPosition;
  if obj.position.new
    st = sprintf('x: %f, y: %f, z: %f, pitch: %f, yaw: %f, roll: %f', ...
      obj.position.x,...
      obj.position.y,...
      obj.position.z,...
      obj.position.pitch,...
      obj.position.yaw,...
      obj.position.roll);
    obj.debug(st);
    rpy_array = [ 0 0 0 0 obj.position.yaw obj.position.pitch obj.position.roll ];
  end
  obj.debug('Calibration Complete');
end

