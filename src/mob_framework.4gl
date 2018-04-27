--SCHEMA mob_database

-- A Genero Mobile Framework Demo with web services.

IMPORT util
IMPORT os

IMPORT FGL mob_lib
IMPORT FGL mob_ws_lib
IMPORT FGL gl_lib

MAIN

	CALL mob_lib.init_app()

	IF NOT mob_lib.login() THEN
		EXIT PROGRAM
	END IF

	OPEN FORM main FROM "mob_framework"
	DISPLAY FORM main
	DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network

	MENU
		ON ACTION list_custs
			CALL list_custs()
		ON ACTION take_photo
			CALL photo(TRUE)
		ON ACTION choose_photo
			CALL photo(FALSE)
		ON ACTION send_data
			CALL send_data("This is some test data!")
		ON ACTION about
			CALL ui.interface.frontCall("Android","showAbout",[],[])
		ON ACTION quit
			EXIT MENU
		ON TIMER 10
			DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network
	END MENU

END MAIN
--------------------------------------------------------------------------------
FUNCTION list_custs()

	IF mob_lib.m_sel_list1.getLength() = 0 THEN
		IF NOT mob_lib.get_list1() THEN
			RETURN
		END IF
	END IF

	OPEN WINDOW custs WITH FORM "cust_list" 

	MESSAGE "Data as of: "||mob_lib.m_list1_date
	DISPLAY ARRAY m_sel_list1 TO scr_arr.* ATTRIBUTES(ACCEPT=FALSE,CANCEL=FALSE)
		ON ACTION select
			CALL show_cust( mob_lib.m_sel_list1[ arr_curr() ].key )
		ON ACTION back EXIT DISPLAY
	END DISPLAY

	CLOSE WINDOW custs
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION show_cust(l_key STRING)

	IF NOT mob_lib.get_dets1( l_key ) THEN
		RETURN 
	END IF

	OPEN WINDOW cust_det WITH FORM "cust_dets"

	DISPLAY "Data as of: "||mob_lib.m_dets1.updated_date TO f_info
	DISPLAY BY NAME mob_lib.m_Dets1.*

	MENU
		ON ACTION back EXIT MENU
		ON ACTION close EXIT MENU
	END MENU

	CLOSE WINDOW cust_det
END FUNCTION
