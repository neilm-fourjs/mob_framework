
-- Application Specific backend Code

IMPORT os
IMPORT FGL gl_lib
IMPORT FGL mob_db_backend

GLOBALS
	DEFINE g_user STRING
END GLOBALS

PUBLIC DEFINE m_media_uri STRING
PUBLIC DEFINE m_media_path STRING

FUNCTION init_app_backend()
	DEFINE l_host STRING

	LET m_media_path = fgl_getEnv("MEDIAPATH")
	IF NOT os.path.exists( m_media_path ) THEN
		IF NOT os.path.mkdir( m_media_path ) THEN
			RETURN SFMT(%"ERR: Media Path Failed to create %1!",m_media_path)
		END IF
	END IF
	CALL gl_lib.gl_logIt(SFMT("Media Path:%1",m_media_path))

	LET l_host = gl_lib.gl_getHostName()
	LET m_media_uri = "http://"||l_host||"/"||fgl_getEnv("MEDIAURI")
	CALL gl_lib.gl_logIt(SFMT("Media URI:%1",m_media_uri))

	RETURN NULL
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION process_media(l_file STRING, l_vid BOOLEAN, l_imgid STRING )
	DEFINE l_media_path, l_newpath STRING

	LET l_media_path = os.path.join(m_media_path,l_imgid)
	IF NOT os.path.mkdir( l_media_path ) THEN
		RETURN SFMT(%"ERR: Media Path Failed to create %1!",l_media_path)
	END IF

	LET l_newpath = os.path.join( l_media_path, os.path.basename(l_file) )

	IF os.Path.copy(l_file, l_newpath) THEN
		IF NOT os.path.delete(l_file) THEN
			CALL gl_lib.gl_logIt(SFMT(%"Failed to delete %1",l_file))
		END IF
	ELSE
		CALL gl_lib.gl_logIt(SFMT(%"Failed to copy %1 to %2",l_file,l_newpath))
		RETURN %"ERR: Media processing failed!"
	END IF

	RUN "./mk_thumbnail.sh "||l_media_path||" "||os.path.basename(l_file) WITHOUT WAITING

	CALL mob_db_backend.db_log_media( IIF(l_vid,"V","P"), os.path.join( l_imgid, os.path.basename(l_file) )
 )

	RETURN "Okay"
END FUNCTION