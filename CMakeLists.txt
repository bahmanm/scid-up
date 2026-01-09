# Copyright (C) 2016-2017  Fulvio Benini
# This file is part of Scid (Shane's Chess Information Database).
#
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# Scid is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scid. If not, see <http://www.gnu.org/licenses/>.
cmake_minimum_required( VERSION 3.30 )

project(
    ScidUp
    VERSION 5.1.0
    LANGUAGES CXX )

include( GNUInstallDirs )
include( cmake/package/portable/layout.cmake )
include( cmake/general.cmake )
include( cmake/libs/threads.cmake )
include( cmake/libs/tcl.cmake )
include( cmake/libs/polyglot.cmake )
include( cmake/bins/main.cmake )
include( cmake/install/main.cmake )
include( cmake/tests/all.cmake )
include( cmake/tools/lint.cmake )
include( cmake/packaging.cmake )
