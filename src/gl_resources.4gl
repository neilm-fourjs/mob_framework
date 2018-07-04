
-- This module is used to load and access entries from a json config file.

IMPORT util
IMPORT os
IMPORT FGL gl_lib

DEFINE m_resources util.JSONObject
DEFINE m_resourceFile STRING

FUNCTION gl_initResources()
	DEFINE l_filename STRING
	DEFINE l_json STRING
	DEFINE c base.Channel
-- Look in sdcard/Download first, then ../config then current dir
	LET l_filename = base.Application.getProgramName()||".json"
	LET m_resourceFile = os.path.join( "/sdcard/Download", l_filename)
	IF NOT os.path.exists(m_resourceFile) THEN
		LET m_resourceFile = os.path.join( os.path.join("..","config"),l_filename)
	END IF
	IF NOT os.path.exists(m_resourceFile) THEN
		LET m_resourceFile = l_filename
	END IF

	LET c = base.Channel.create()
	TRY
		CALL c.openFile(m_resourceFile,"r")
		CALL gl_lib.gl_logIt( SFMT("ResourceFile:%1",m_resourceFile) )
	CATCH
		LET m_resourceFile = SFMT(%"Failed to find %1!",l_filename)
		CALL gl_lib.gl_logIt( m_resourceFile )
		CALL gl_lib.gl_winMessage("Error",m_resourceFile,"exclamation")
		EXIT PROGRAM
	END TRY
	WHILE NOT c.isEof()
		LET l_json = l_json.append( c.readLine() )
	END WHILE
	CALL c.close()
	LET m_resources = util.JSONObject.parse(l_json)

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_getresource( l_name STRING, l_def STRING )
	DEFINE l_val STRING
	LET l_val = m_resources.get(l_name)
	IF l_val IS NULL THEN
		CALL gl_lib.gl_logIt( SFMT(%"Resource '%1' not found!", l_name) )
		LET l_val = l_def
	END IF
	RETURN l_val
END FUNCTION
