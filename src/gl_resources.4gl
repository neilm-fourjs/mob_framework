
-- This module is used to load and access entries from a json config file.

IMPORT util
IMPORT os
IMPORT FGL gl_lib

DEFINE m_resources util.JSONObject
DEFINE m_resourceFile STRING
DEFINE m_filename STRING
DEFINE m_downloads DYNAMIC ARRAY OF STRING

FUNCTION gl_initResources()
	DEFINE l_json STRING
	DEFINE c base.Channel
	DEFINE x SMALLINT

-- name of the json config file
	LET m_filename = base.Application.getProgramName()||".json"

-- directories to search for the json config file
	LET m_downloads[m_downloads.getLength()+1] = "/storage/emulated/0/download"
	LET m_downloads[m_downloads.getLength()+1] = "/sdcard/Download"
	LET m_downloads[m_downloads.getLength()+1] = "/storage/sdcard0/download"
	LET m_downloads[m_downloads.getLength()+1] = "/mnt/sdcard/download"
	LET m_downloads[m_downloads.getLength()+1] = "../config"
	LET m_downloads[m_downloads.getLength()+1] = "."

	FOR x = 1 TO m_downloads.getLength()
		LET m_resourceFile = os.path.join(m_downloads[x], m_filename)
		IF os.path.exists(m_resourceFile) THEN
			EXIT FOR
		END IF
	END FOR

	IF NOT os.path.exists(m_resourceFile) THEN
		LET m_resourceFile = NULL
		CALL gl_showResourceFile(SFMT(%"Failed to find %1!",m_filename))
		EXIT PROGRAM
	END IF

	LET c = base.Channel.create()
	TRY
		CALL c.openFile(m_resourceFile,"r")
		CALL gl_lib.gl_logIt( SFMT("ResourceFile:%1",m_resourceFile) )
	CATCH
		LET m_resourceFile = NULL
		CALL gl_showResourceFile(SFMT(%"Failed to find %1!",m_filename))
		EXIT PROGRAM
	END TRY
	WHILE NOT c.isEof()
		LET l_json = l_json.append( c.readLine() )
	END WHILE
	CALL c.close()
	LET m_resources = util.JSONObject.parse(l_json)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_showResourceFile(l_log STRING)
	DEFINE x SMALLINT
	DEFINE l_resourceFile STRING
	IF l_log IS NULL THEN LET l_log = "Resource File Check:" END IF
	FOR x = 1 TO m_downloads.getLength()
		IF os.path.exists(m_downloads[x]) THEN
			LET l_log = l_log.append( "\n\n"||m_downloads[x]||" Exists")
			LET l_resourceFile = os.path.join(m_downloads[x], m_filename)
			LET l_log = l_log.append( "\n\n"||l_resourceFile||IIF( os.path.exists(l_resourceFile)," Exists"," Not Found"))
		ELSE
			LET l_log = l_log.append( "\n\n"||m_downloads[x]||" Not Found")
		END IF
	END FOR
	LET l_log = l_log.append("\n------------\nFile Loaded: "||NVL(m_resourceFile,"NONE! Aborting"))
	OPEN WINDOW gl_showResourceFileLoc WITH FORM "view_log"
	DISPLAY BY NAME l_log
	MENU
		ON ACTION close EXIT MENU
		ON ACTION back EXIT MENU
	END MENU
	CLOSE WINDOW gl_showResourceFileLoc
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
