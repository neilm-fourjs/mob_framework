
IMPORT util
IMPORT os 

DEFINE m_resources util.JSONObject

FUNCTION gl_initResources()
	DEFINE l_filename, l_file STRING
	DEFINE l_json STRING
	DEFINE c base.Channel
-- Look in sdcard/Download first, then ../config then current dir
	LET l_filename = base.Application.getProgramName()||".json"
	LET l_file = os.path.join( "/sdcard/Download", l_filename)
	IF NOT os.path.exists(l_file) THEN
		LET l_file = os.path.join( os.path.join("..","config"),l_filename)
	END IF
	IF NOT os.path.exists(l_file) THEN
		LET l_file = l_filename
	END IF

	LET c = base.Channel.create()
	TRY
		CALL c.openFile(l_file,"r")
	CATCH
		CALL gl_winMessage("Error",SFMT("Failed to find %1!",l_filename),"exclamation")
		EXIT PROGRAM
	END TRY
	WHILE NOT c.isEof()
		LET l_json = l_json.append( c.readLine() )
	END WHILE
	CALL c.close()
	LET m_resources = util.JSONObject.parse(l_json)

	DISPLAY "Resources:", m_resources.toString()
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_getresource( l_name STRING, l_def STRING )
	DEFINE l_val STRING
	LET l_val = m_resources.get(l_name)
	IF l_val IS NULL THEN
		DISPLAY SFMT(%"Resource '%1' not found!", l_name)
		LET l_val = l_def
	END IF
	RETURN l_val
END FUNCTION
