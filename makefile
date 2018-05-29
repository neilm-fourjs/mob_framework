# Automatic Makefile made by make4js by N.J.M.

fgl_obj1 = 

fgl_frm1 = 

#depend::
#	echo "making depends";  cd lib ; ./link_lib

bin/mob_framework.42r: src/*.4gl src/*.per
	gsmake -t mob_framework.42r mob_framework.4pw

include ./Make_fjs.inc
