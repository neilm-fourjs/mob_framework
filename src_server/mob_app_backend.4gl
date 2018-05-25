
-- Application Specific backend Code

IMPORT os
IMPORT FGL gl_lib
IMPORT FGL mob_db_backend

GLOBALS
	DEFINE g_user STRING
END GLOBALS

DEFINE m_media_path STRING

FUNCTION process_media(l_file STRING, l_vid BOOLEAN, l_imgid STRING )
	DEFINE l_newpath STRING

	LET m_media_path = fgl_getEnv("MEDIAPATH")
	IF NOT os.path.exists( m_media_path ) THEN
		IF NOT os.path.mkdir( m_media_path ) THEN
			RETURN SFMT(%"ERR: Media Path Failed to create %1!",m_media_path)
		END IF
	END IF

	LET m_media_path = os.path.join(m_media_path,l_imgid)
	IF NOT os.path.mkdir( m_media_path ) THEN
		RETURN SFMT(%"ERR: Media Path Failed to create %1!",m_media_path)
	END IF

	LET l_newpath = os.path.join( m_media_path, os.path.basename(l_file) )

	IF os.Path.copy(l_file, l_newpath) THEN
		IF NOT os.path.delete(l_file) THEN
			CALL gl_lib.gl_logIt(SFMT(%"Failed to delete %1",l_file))
		END IF
	ELSE
		CALL gl_lib.gl_logIt(SFMT(%"Failed to copy %1 to %2",l_file,l_newpath))
		RETURN %"ERR: Media processing failed!"
	END IF

	RUN "./mk_thumbnail.sh "||m_media_path||" "||os.path.basename(l_file) WITHOUT WAITING

	CALL mob_db_backend.db_log_media(g_user, IIF(l_vid,"V","P"), l_newpath)

	RETURN "Okay"
END FUNCTION