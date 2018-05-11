
IMPORT FGL gl_lib
IMPORT FGL mob_db_backend

SCHEMA njm_demo310

MAIN

	CALL STARTLOG( base.Application.getProgramName()||".err" )

	CALL mob_db_backend.db_connect()

	OPEN FORM f1 FROM "mob_ui_backend"
	DISPLAY FORM f1

	MENU %"Menu"
		ON ACTION users CALL users()
		ON ACTION accesslog CALL accessLog()
		ON ACTION medialog CALL mediaLog()
		ON ACTION quit EXIT MENU
	END MENU

END MAIN
--------------------------------------------------------------------------------
-- Manage mobile users in the database
-- 
-- @params 
-- @returns
FUNCTION users()
  
END FUNCTION
--------------------------------------------------------------------------------
-- View the Access log
-- 
-- @params 
-- @returns
FUNCTION accessLog()
	DEFINE l_al DYNAMIC ARRAY OF RECORD LIKE ws_log_access.*

	DECLARE cur_al CURSOR FOR SELECT * FROM ws_log_access 
	FOREACH cur_al INTO l_al[ l_al.getLength() + 1 ].*
	END FOREACH
	CALL l_al.deleteElement( l_al.getLength() )

	OPEN WINDOW al WITH FORM "accessLog"
	
	DISPLAY ARRAY l_al TO arr.*

	CLOSE WINDOW al
  
END FUNCTION
--------------------------------------------------------------------------------
-- View the Media log
-- 
-- @params 
-- @returns
FUNCTION mediaLog()
  DEFINE l_ml DYNAMIC ARRAY OF RECORD LIKE ws_log_media.*

	DECLARE cur_ml CURSOR FOR SELECT * FROM ws_log_media 
	FOREACH cur_ml INTO l_ml[ l_ml.getLength() + 1 ].*
	END FOREACH
	CALL l_ml.deleteElement( l_ml.getLength() )

	OPEN WINDOW ml WITH FORM "mediaLog"
	
	DISPLAY ARRAY l_ml TO arr.*
		BEFORE ROW 
			IF l_ml[arr_curr()].media_type = "P" THEN
				DISPLAY l_ml[arr_curr()].filepath TO f_img
			END IF
	END DISPLAY

	CLOSE WINDOW ml
END FUNCTION