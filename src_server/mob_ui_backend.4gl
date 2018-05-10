
IMPORT FGL gl_lib
IMPORT FGL mob_db_backend
MAIN

	CALL STARTLOG( base.Application.getProgramName()||".err" )

	CALL mob_db_backend.db_connect()

	MENU
		ON ACTION newuser CALL newUser()
		ON ACTION quit EXIT MENU
	END MENU

END MAIN
--------------------------------------------------------------------------------
-- Create a user mobile user in the database
-- 
-- @params 
-- @returns
FUNCTION newUser()
  
END FUNCTION
