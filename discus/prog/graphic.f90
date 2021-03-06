MODULE output_menu
!
CONTAINS
!*****7*****************************************************************
SUBROUTINE do_niplps (linverse) 
!-                                                                      
!     This sublevel contains all routines used to write the output      
!     of the Fourier transform/Patterson to an output file in           
!     various formats.                                                  
!+                                                                      
      USE discus_config_mod 
      USE diffuse_mod 
      USE nexus_discus
      USE discus_mrc
      USE vtk_mod
      USE output_mod 
      USE powder_write_mod
      USE chem_aver_mod
      USE qval_mod
!
      USE ber_params_mod
      USE build_name_mod
      USE calc_expr_mod
      USE doact_mod 
      USE do_eval_mod
      USE do_wait_mod
      USE errlist_mod 
      USE get_params_mod
      USE learn_mod 
      USE class_macro_internal
USE precision_mod
      USE prompt_mod 
      USE sup_mod
!                                                                       
      IMPLICIT none 
!                                                                       
      INTEGER maxp
      PARAMETER (maxp = 11) 
!                                                                       
      CHARACTER(5) befehl 
      CHARACTER(LEN=LEN(prompt)) :: orig_prompt
      CHARACTER(14) cvalue (0:14) 
      CHARACTER(22) cgraphik (0:8) 
      CHARACTER(1024) infile 
      CHARACTER(1024) zeile 
      CHARACTER(1024) line, cpara (maxp) 
      INTEGER lpara (maxp) 
      INTEGER ix, iy, ianz, value, lp, length, lbef 
      INTEGER indxg 
      LOGICAL laver, lread, linverse 
      REAL xmin, ymin, xmax, ymax 
REAL(KIND=PREC_DP), DIMENSION(MAXP) ::werte
!                                                                       
      INTEGER len_str 
      LOGICAL str_comp 
!                                                                       
      DATA cgraphik / 'Standard', 'Postscript', 'Pseudo Grey Map', 'Gnup&
     &lot', 'Portable Any Map', 'Powder Pattern', 'SHELX', 'SHELXL List &
     &5', 'SHELXL List 5 real HKL' /                                    
      DATA cvalue / 'undefined     ', 'Intensity     ', 'Amplitude     ',&
                    'Phase angle   ', 'Real Part     ', 'Imaginary Part',&
                    'Random Phase  ', 'S(Q)          ', 'F(Q)          ',&
                    'f2aver = <f^2>', 'faver2 = <f>^2', 'faver = <f>   ',&
                    'Normal Inten  ', 'I(Q)          ', 'PDF           ' /
!                                                                       
      DATA value / 1 / 
      DATA laver / .false. / 
!                                                                       
      zmin = ps_low * diffumax 
      zmax = ps_high * diffumax 
      orig_prompt = prompt
      prompt = prompt (1:len_str (prompt) ) //'/output' 
   10 CONTINUE 
!                                                                       
      CALL no_error 
!                                                                       
      CALL get_cmd (line, length, befehl, lbef, zeile, lp, prompt) 
      IF (ier_num.eq.0) THEN 
         IF (line (1:1)  == ' '.or.line (1:1)  == '#' .or.   & 
             line == char(13) .or. line(1:1) == '!'  ) THEN
            IF(linteractive .or. lmakro) THEN
               GOTO 10
            ELSE
               RETURN
            ENDIF
         ENDIF
!                                                                       
!     search for "="                                                    
!                                                                       
indxg = index (line, '=') 
IF (indxg.ne.0.AND..NOT. (str_comp (befehl, 'echo', 2, lbef, 4) ) &
              .AND..NOT. (str_comp (befehl, 'syst', 2, lbef, 4) )    &
              .AND..NOT. (str_comp (befehl, 'help', 2, lbef, 4) .OR. &
                          str_comp (befehl, '?   ', 2, lbef, 4) )    &
              .AND. INDEX(line,'==') == 0                            ) THEN
!
!     --evaluatean expression and assign the value to a variabble       
!                                                                       
            CALL do_math (line, indxg, length) 
         ELSE 
!                                                                       
!------ execute a macro file                                            
!                                                                       
            IF (befehl (1:1) .eq.'@') THEN 
               IF (length.ge.2) THEN 
                  CALL file_kdo (line (2:length), length - 1) 
               ELSE 
                  ier_num = - 13 
                  ier_typ = ER_MAC 
               ENDIF 
!                                                                       
!     continues a macro 'continue'                                      
!                                                                       
            ELSEIF (str_comp (befehl, 'continue', 1, lbef, 8) ) THEN 
               CALL macro_continue (zeile, lp) 
!                                                                       
!------ Echo a string, just for interactive check in a macro 'echo'     
!                                                                       
            ELSEIF (str_comp (befehl, 'echo', 2, lbef, 4) ) THEN 
               CALL echo (zeile, lp) 
!                                                                       
!     Evaluate an expression, just for interactive check 'eval'         
!                                                                       
            ELSEIF (str_comp (befehl, 'eval', 2, lbef, 4) ) THEN 
               CALL do_eval (zeile, lp, .TRUE.) 
!                                                                       
!     Terminate output 'exit'                                           
!                                                                       
            ELSEIF (str_comp (befehl, 'exit', 2, lbef, 4) ) THEN 
               GOTO 9999 
!                                                                       
!     Determine format for output 'format'                              
!                                                                       
            ELSEIF (str_comp (befehl, 'form', 1, lbef, 4) ) THEN 
               CALL get_params (zeile, ianz, cpara, lpara, maxp, lp) 
               IF (ier_num.eq.0) THEN 
                  IF (ianz.eq.1.or.ianz.eq.2.or.ianz==5) THEN 
!                                                                       
!     ------Switch output type to ASCII 3D  '3d'                      
!                                                                       
                     IF(str_comp(cpara(1),'3d',2,lpara(1),2)) THEN                                        
                        ityp = 9 
!                                                                       
!     ------Switch output type to GNUPLOT 'gnup'                        
!                                                                       
                     ELSEIF(str_comp(cpara(1),'gnup',1,lpara(1),4)) THEN                                             
                        ityp = 3 
!                                                                       
!     ------Switch output type to pgm 'pgm'                             
!                                                                       
                     ELSEIF(str_comp(cpara(1),'pgm ',2,lpara(1),4)) THEN                                        
                        ityp = 2 
!                                                                       
!     ------Switch output type to postscript 'post'                     
!                                                                       
                     ELSEIF(str_comp(cpara(1),'post',3,lpara(1),4)) THEN                                        
                        ityp = 1 
!                                                                       
!     ------Switch output type to powder pattern 'powd'                 
!                                                                       
                     ELSEIF(str_comp(cpara(1),'powd',3,lpara(1),4)) THEN                                        
                        ityp = 5 
                        IF (ianz >= 2) THEN 
                           IF (str_comp (cpara (2) , 'tth', 2, lpara (2)&
                           , 3) ) THEN                                  
                              cpow_form = 'tth' 
                           ELSEIF (str_comp (cpara (2) , 'q', 1, lpara (&
                           2) , 1) ) THEN                               
                              cpow_form = 'q  ' 
                           ELSEIF (str_comp (cpara (2) , 'stl', 2,      &
                           lpara (2) , 3) ) THEN                        
                              cpow_form = 'stl' 
                           ELSEIF (str_comp (cpara (2) , 'dst', 2,      &
                           lpara (2) , 3) ) THEN                        
                              cpow_form = 'dst' 
                           ELSEIF (str_comp (cpara (2) , 'lop', 2,      &
                           lpara (2) , 3) ) THEN                        
                              cpow_form = 'lop' 
                           ELSE 
                              ier_num = - 6 
                              ier_typ = ER_COMM 
                           ENDIF 
                           out_user_limits      = .false.
                           IF(ianz==5) THEN
                              cpara(1:2)='0'
                              lpara(1:2)= 1 
                              CALL ber_params (ianz, cpara, lpara, werte, maxp)
                              IF(ier_num==0) THEN
                                 out_user_values(1:3) = werte(3:5)
                                 out_user_limits      = .true.
                              ENDIF
                           ENDIF
                        ENDIF 
!                                                                       
!     ------Switch output type to ppm 'ppm'                             
!                                                                       
                     ELSEIF(str_comp(cpara(1),'ppm ',2,lpara(1),4)) THEN                                        
                        ityp = 4 
!                                                                       
!     ------Switch output type to standard  'stan'                      
!                                                                       
                     ELSEIF(str_comp(cpara(1),'stan',2,lpara(1),4)) THEN                                        
                        ityp = 0 
!                                                                       
!     ------Switch output type to Shelx 'shel', or 'hklf4'              
!                                                                       
                     ELSEIF(str_comp(cpara(1),'shel',2,lpara(1),4)) THEN                                        
                        ityp = 6 
                     ELSEIF(str_comp(cpara(1),'hklf4',2,lpara(1),5)) THEN                                        
                        ityp = 6 
!                                                                       
!     ------Switch output type to Shelx LIST 5   'list5'                
!                                                                       
                     ELSEIF(str_comp(cpara(1),'list5',2,lpara(1),5)) THEN                                        
                        ityp = 7 
!                                                                       
!     ------Switch output type to Shelx LIST 5   'list9'                
!                                                                       
                     ELSEIF(str_comp(cpara(1),'list9',2,lpara(1),5)) THEN                                        
                        ityp = 8 
!                                                                       
!     ------Switch output type to NeXus format   'nexus'                
!                                                                       
                     ELSEIF(str_comp(cpara(1),'nexus',2,lpara(1),5)) THEN                                        
                        ityp = 10 
!                                                                       
!     ------Switch output type to VTK format   'vtk'
!                                                                       
                     ELSEIF(str_comp(cpara(1),'vtk',2,lpara(1),5)) THEN
                        ityp = 11
!                                                                       
!     ------Switch output type to MRC   format   'mrc'                
!                                                                       
                     ELSEIF (str_comp(cpara(1), 'mrc', 2, lpara(1), 3) ) THEN                                        
                        ityp = 12 
                     ELSE
                        ier_num = - 9 
                        ier_typ = ER_APPL 
                     ENDIF 
                  ELSE 
                     ier_num = - 6 
                     ier_typ = ER_COMM 
                  ENDIF 
               ENDIF 
!                                                                       
!     help on output 'help'                                             
!                                                                       
      ELSEIF (str_comp (befehl, 'help', 2, lbef, 4) .or.str_comp (befehl&
     &, '?   ', 1, lbef, 4) ) THEN                                      
               IF (str_comp (zeile, 'errors', 2, lp, 6) ) THEN 
                  lp = lp + 7 
                  CALL do_hel ('discus '//zeile, lp) 
               ELSE 
                  lp = lp + 14 
                  CALL do_hel ('discus output '//zeile, lp) 
               ENDIF 
!                                                                       
!     read an old output file (only for standard file type' 'inpu'      
!                                                                       
            ELSEIF (str_comp (befehl, 'inpu', 1, lbef, 4) ) THEN 
               CALL get_params (zeile, ianz, cpara, lpara, maxp, lp) 
               IF (ier_num.eq.0) THEN 
                  infile = cpara (1) 
                  lread = .true. 
                  CALL oeffne (1, infile, 'old') 
                  IF (ier_num.eq.0) THEN 
                     READ (1, * ) out_inc (1), out_inc (2) 
                     READ (1, * ) xmin, xmax, ymin, ymax 
                     READ (1, * ) zmax 
                     zmin = zmax 
                     BACKSPACE (1) 
!                                                                       
                     DO iy = 1, out_inc (2) 
                     READ (1, * ) (dsi ( (ix - 1) * out_inc (2) + iy),  &
                     ix = 1, out_inc (1) )                              
                     DO ix = 1, out_inc (1) 
                     zmax = max (zmax, REAL(dsi ( (ix - 1) * out_inc (2)     &
                     + iy) ))                                            
                     zmin = min (zmin, REAL(dsi ( (ix - 1) * out_inc (2)     &
                     + iy)) )                                            
                     ENDDO 
                     ENDDO 
                     WRITE (output_io, 1015, advance='no') zmin, zmax 
                     READ ( *, *, end = 20) zmin, zmax 
   20                CONTINUE 
                  ENDIF 
                  CLOSE (1) 
               ENDIF 
!                                                                       
!     define name of output file 'outf'                                 
!                                                                       
            ELSEIF (str_comp (befehl, 'outf', 1, lbef, 4) ) THEN 
               CALL get_params (zeile, ianz, cpara, lpara, maxp, lp) 
               IF (ier_num.eq.0) THEN 
                  CALL do_build_name (ianz, cpara, lpara, werte, maxp,  &
                  1)                                                    
                  IF (ier_num.eq.0) THEN 
                     outfile = cpara (1) (1:lpara(1))
                  ENDIF 
               ENDIF 
!                                                                       
!     Reset output 'reset'
!                                                                       
            ELSEIF (str_comp (befehl, 'rese', 2, lbef, 4) ) THEN 
               CALL output_reset
!                                                                       
!     write output file 'run'                                           
!                                                                       
            ELSEIF (str_comp (befehl, 'run ', 2, lbef, 4) ) THEN 
               IF(four_was_run) THEN    ! A fourier has been calculated do output
                  CALL chem_elem(.false.)
                  CALL set_output (linverse) 
                  IF (ityp.eq.0) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.1) THEN 
                     CALL do_post (value, laver) 
                  ELSEIF (ityp.eq.2) THEN 
                     CALL do_pgm (value, laver) 
                  ELSEIF (ityp.eq.3) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.4) THEN 
                     CALL do_ppm (value, laver) 
                  ELSEIF (ityp.eq.5) THEN 
                     CALL powder_out (value)
                  ELSEIF (ityp.eq.6) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.7) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.8) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.9) THEN 
                     CALL do_output (value, laver) 
                  ELSEIF (ityp.eq.10) THEN 
                     CALL nexus_write (value, laver) 
                  ELSEIF (ityp.eq.11) THEN
                     CALL vtk_write ()
                  ELSEIF (ityp.eq.12) THEN
                     CALL mrc_write (value, laver)
                  ELSE 
                     ier_num = - 9 
                     ier_typ = ER_APPL 
                  ENDIF 
               ELSE 
                  ier_num = -118
                  ier_typ = ER_APPL 
                  ier_msg(1) = 'You need to calculate a Fourier / Patterson /'
                  ier_msg(2) = 'Inverse Fourier / Powder / Fourier via Stack'
                  ier_msg(3) = 'first, before an output can be written'
               ENDIF 
!                                                                       
!     Show current settings for output 'show'                           
!                                                                       
            ELSEIF (str_comp (befehl, 'show', 2, lbef, 4) ) THEN 
               WRITE (output_io, 3000) outfile 
               IF (ityp.lt.0.or.8.lt.ityp) THEN 
                  WRITE (output_io, * ) 'ityp undefiniert ', ityp 
               ELSEIF (ityp.eq.5) THEN 
                  WRITE (output_io, 3130) cgraphik (ityp), cpow_form 
               ELSE 
                  WRITE (output_io, 3100) cgraphik (ityp) 
                  IF (laver) THEN 
                     WRITE (output_io, 3110) '<'//cvalue (value) //'>' 
                  ELSE 
                     WRITE (output_io, 3110) cvalue (value) 
                  ENDIF 
               ENDIF 
               WRITE (output_io, 3060) braggmin, braggmax, diffumin,    &
               diffumax, diffuave, diffusig                             
               WRITE (output_io, 3080) 100.0 * ps_high, zmax 
               WRITE (output_io, 3090) 100.0 * ps_low, zmin 
!                                                                       
!-------Operating System Kommandos 'syst'                               
!                                                                       
            ELSEIF (str_comp (befehl, 'syst', 2, lbef, 4) ) THEN 
               IF (zeile.ne.' ') THEN 
                  CALL do_operating (zeile (1:lp), lp) 
               ELSE 
                  ier_num = - 6 
                  ier_typ = ER_COMM 
               ENDIF 
!                                                                       
!     Set threshold for intensity written to bitmaps 'thresh'           
!                                                                       
            ELSEIF (str_comp (befehl, 'thre', 2, lbef, 4) ) THEN 
               CALL get_params (zeile, ianz, cpara, lpara, maxp, lp) 
               IF (ier_num.eq.0) THEN 
                  IF (ianz.eq.2) THEN 
                     IF (str_comp (cpara (1) , 'high', 1, lpara (1) , 4)&
                     ) THEN                                             
                        CALL del_params (1, ianz, cpara, lpara, maxp) 
                        CALL ber_params (ianz, cpara, lpara, werte,     &
                        maxp)                                           
                        IF (ier_num.eq.0) THEN 
                           ps_high = werte (1) * 0.01 
                           zmax = diffumax * ps_high 
                        ENDIF 
                     ELSEIF (str_comp (cpara (1) , 'low', 1, lpara (1) ,&
                     3) ) THEN                                          
                        CALL del_params (1, ianz, cpara, lpara, maxp) 
                        CALL ber_params (ianz, cpara, lpara, werte,     &
                        maxp)                                           
                        IF (ier_num.eq.0) THEN 
                           ps_low = werte (1) * 0.01 
                           zmin = diffumax * ps_low 
                        ENDIF 
                     ELSEIF (str_comp (cpara (1) , 'sigma', 1, lpara (1)&
                     , 5) ) THEN                                        
                        CALL del_params (1, ianz, cpara, lpara, maxp) 
                        CALL ber_params (ianz, cpara, lpara, werte,     &
                        maxp)                                           
                        IF (ier_num.eq.0) THEN 
                           zmin = max (diffumin, diffuave-REAL(werte (1))     &
                           * diffusig)                                  
                           zmax = min (diffumax, diffuave+REAL(werte (1))     &
                           * diffusig)                                  
                           IF (diffumax.ne.0) THEN 
                              ps_high = zmax / diffumax 
                              ps_low = zmin / diffumax 
                           ELSE 
                              ps_high = 0.0 
                              ps_low = 0.0 
                           ENDIF 
                        ENDIF 
                     ELSEIF (str_comp (cpara (1) , 'zmax', 3, lpara (1) &
                     , 4) ) THEN                                        
                        CALL del_params (1, ianz, cpara, lpara, maxp) 
                        CALL ber_params (ianz, cpara, lpara, werte,     &
                        maxp)                                           
                        IF (ier_num.eq.0) THEN 
                           zmax = werte (1) 
                           IF (diffumax.ne.0) THEN 
                              ps_high = zmax / diffumax 
                           ELSE 
                              ps_high = 0.0 
                           ENDIF 
                        ENDIF 
                     ELSEIF (str_comp (cpara (1) , 'zmin', 3, lpara (1) &
                     , 4) ) THEN                                        
                        CALL del_params (1, ianz, cpara, lpara, maxp) 
                        CALL ber_params (ianz, cpara, lpara, werte,     &
                        maxp)                                           
                        IF (ier_num.eq.0) THEN 
                           zmin = werte (1) 
                           IF (diffumax.ne.0) THEN 
                              ps_low = zmin / diffumax 
                           ELSE 
                              ps_low = 0.0 
                           ENDIF 
                        ENDIF 
                     ELSE 
                        ier_num = - 11 
                        ier_typ = ER_APPL 
                     ENDIF 
                  ELSE 
                     ier_num = - 6 
                     ier_typ = ER_COMM 
                  ENDIF 
               ENDIF 
!                                                                       
!     Define output value 'value'                                       
!                                                                       
            ELSEIF (str_comp (befehl, 'valu', 1, lbef, 4) ) THEN 
               CALL get_params (zeile, ianz, cpara, lpara, maxp, lp) 
               IF (ier_num.eq.0) THEN 
!------ ----Check if we want the average values <F> ?                   
                  IF (cpara (1) (1:1) .eq.'<') THEN 
                     ix = 2 
                     laver = .true. 
                  ELSE 
                     ix = 1 
                     laver = .false. 
                  ENDIF 
!     ----Calculate intensity 'intensity'                               
                  IF (cpara (1) (ix:ix + 1) .eq.'in') THEN 
                     value = val_inten
!     ----Calculate amplitude 'amplitude'                               
                  ELSEIF (cpara (1) (ix:ix) .eq.'a') THEN 
                     value = val_ampli
!     ----Calculate phase 'phase'                                       
                  ELSEIF (cpara (1) (ix:ix) .eq.'p') THEN 
                     IF (ianz.eq.1) THEN 
                        value = val_phase
                     ELSEIF (ianz.eq.2.and.cpara (2) (1:1) .eq.'r')     &
                     THEN                                               
                        value = val_ranph
                     ENDIF 
!     ----Calculate real part 'real'                                    
                  ELSEIF (cpara (1) (ix:ix) .eq.'r') THEN 
                     value = val_real
!     ----Calculate imaginary part 'imaginary'                          
                  ELSEIF (cpara (1) (ix:ix + 1) .eq.'im') THEN 
                     value = val_imag
!     ----Calculate I(Q)           'I(Q) =Inte/N'                       
                  ELSEIF (cpara (1) (ix:ix + 3) .eq.'I(Q)') THEN 
                     value = val_iq
!     ----Calculate S(Q)           'S(Q)     '                          
                  ELSEIF (cpara (1) (ix:ix + 3) .eq.'S(Q)') THEN 
                     value = val_sq
!     ----Calculate F(Q)=Q(S(Q)-1) 'F(Q)     '                          
                  ELSEIF (cpara (1) (ix:ix + 3) .eq.'F(Q)') THEN 
                     value = val_fq 
                  ELSEIF (cpara (1) (ix:ix + 5) == 'f2aver') THEN
                     value = val_f2aver
                  ELSEIF (cpara (1) (ix:ix + 5) == 'faver2') THEN
                     value = val_faver2
                  ELSEIF (cpara (1) (ix:ix + 4) == 'faver') THEN
                     value = val_faver
!     ----Calculate S(Q)           'N(Q) = S(Q) without thermal part    '                          
                  ELSEIF (cpara (1) (ix:ix + 2) == 'PDF' ) THEN 
                     value = val_pdf
                  ELSEIF (cpara (1) (ix:ix + 4) == '3DPDF' ) THEN 
                     value = val_3DPDF
                  ELSE 
                     ier_num = - 6 
                     ier_typ = ER_COMM 
                     value = 0 
                  ENDIF 
!------ ----check lots and allowed output                               
                  IF (nlots.ne.1.and..NOT.(value==1 .OR. value==val_3dpdf).and..not.laver) THEN 
                     ier_num = - 60 
                     ier_typ = ER_APPL 
                     value = 0 
                  ENDIF 
               ENDIF 
!                                                                       
!------  -waiting for user input                                        
!                                                                       
            ELSEIF (str_comp (befehl, 'wait', 3, lbef, 4) ) THEN 
               CALL do_input (zeile, lp) 
!                                                                       
!------ no valid subcommand found                                       
!                                                                       
            ELSE 
               ier_num = - 8 
               ier_typ = ER_COMM 
            ENDIF 
         ENDIF 
      ENDIF 
      IF (ier_num.ne.0) THEN 
         CALL errlist 
         IF (ier_sta.ne.ER_S_LIVE) THEN 
            IF (lmakro .OR. lmakro_error) THEN  ! Error within macro or termination errror
               IF(sprompt /= prompt ) THEN
                  ier_num = -10
                  ier_typ = ER_COMM
                  ier_msg(1) = ' Error occured in output menu'
                  prompt_status = PROMPT_ON 
                  prompt = orig_prompt
                  RETURN
               ELSE
                  IF(lmacro_close) THEN
                     CALL macro_close 
                     prompt_status = PROMPT_ON 
                  ENDIF 
               ENDIF 
            ENDIF 
            IF (lblock) THEN 
               ier_num = - 11 
               ier_typ = ER_COMM 
               prompt_status = PROMPT_ON 
               prompt = orig_prompt
               RETURN 
            ENDIF 
            CALL no_error 
            lmakro_error = .FALSE.
            sprompt = ' '
         ENDIF 
      ENDIF 
      IF(linteractive .or. lmakro) THEN
         GOTO 10
      ELSE
         RETURN
      ENDIF
 9999 CONTINUE 
      prompt = orig_prompt
!                                                                       
 1015 FORMAT ( /1x,'Z-MIN = ',G20.6,/,1x,'Z-MAX = ',G20.6,//            &
     &                     1x,'Give new values zmin, zmax    : ')     
 3000 FORMAT( ' Output file                  : ',a) 
 3060 FORMAT(/' Bragg minimum                : ',g12.6/                 &
     &        ' Bragg maximum                : ',g12.6/                 &
     &        ' Diffuse minimum              : ',g12.6/                 &
     &        ' Diffuse maximum              : ',g12.6/                 &
     &        ' Diffuse average intensity    : ',g12.6/                 &
     &        ' Diffuse intensity sigma      : ',g12.6)                 
 3080 FORMAT(/' Maximum value for BITMAP'/                              &
     &        ' in % of highest diffuse value'/                         &
     &        ' and absolute                 : ',2x,f9.4,2x,g12.6)      
 3090 FORMAT( ' Minimum value for BITMAP'/                              &
     &        ' in % of highest diffuse value'/                         &
     &        ' and absolute                 : ',2x,f9.4,2x,g12.6)      
 3100 FORMAT( ' Graphicsformat               : ',A) 
 3130 FORMAT( ' Graphicsformat               : ',A,A) 
 3110 FORMAT( ' Output value                 : ',A) 
      END SUBROUTINE do_niplps                      
!*****7*****************************************************************
      SUBROUTINE do_post (value, laver) 
!-                                                                      
!     Writes a POSTSCRIPT file                                          
!+                                                                      
      USE discus_config_mod 
      USE diffuse_mod 
      USE output_mod 
      USE qval_mod
      USE envir_mod 
      USE errlist_mod 
      IMPLICIT none 
!                                                                       
!                                                                       
      INTEGER maxcol 
      PARAMETER (maxcol = 256) 
!                                                                       
      CHARACTER(6) cout (maxqxy) 
      CHARACTER(6) cfarb (maxcol) 
      INTEGER i, ix, iy, iqqq, k, value 
      LOGICAL lread, laver 
      REAL qqq 
!                                                                       
!     REAL qval 
!                                                                       
!     Check whether data are 2-dimensional                              
!                                                                       
      IF (.not. (out_inc (1) .gt.1.and.out_inc (2) .gt.1) ) THEN 
         ier_num = - 50 
         ier_typ = ER_APPL 
         RETURN 
      ENDIF 
!                                                                       
!-------Farbtabelle einlesen                                            
!                                                                       
      lread = .true. 
      CALL oeffne (2, colorfile, 'old') 
      IF (ier_num.ne.0) return 
      DO i = 1, 255 
      READ (2, 100, end = 20) cfarb (i) 
  100 FORMAT      (1x,a6) 
      ENDDO 
   20 CONTINUE 
      CLOSE (2) 
      cfarb (256) = 'ffffff' 
!                                                                       
      lread = .false. 
      CALL oeffne (2, outfile, 'unknown') 
      IF (ier_num.ne.0) return 
!                                                                       
      WRITE (2, 1111) '%!PS-Adobe-2.0' 
      WRITE (2, 1111) '%%Creator: DISCUS, Version 3.0' 
      WRITE (2, 1111) '50  150 translate' 
      WRITE (2, 1111) '288 288 scale' 
      WRITE (2, 2000) nint (3.0 * out_inc (1) ), out_inc (1), out_inc ( &
      2), i, 8, out_inc (1), 0, 0, out_inc (2), 0, 0                    
!                                                                       
      DO iy = 1, out_inc (2) 
      DO ix = 1, out_inc (1) 
      k = (ix - 1) * out_inc (2) + iy 
      qqq = qval (k, value, ix, iy, laver) 
      IF (qqq.lt.zmin) THEN 
         qqq = zmin 
      ELSEIF (qqq.gt.zmax) THEN 
         qqq = zmax 
      ENDIF 
      iqqq = nint ( (maxcol - 2) * (qqq - zmin) / (zmax - zmin) )       &
      + 1                                                               
      WRITE (cout (ix), 1111) cfarb (iqqq) 
      DO i = 1, 6 
      IF (cout (ix) (i:i) .eq.' '.or.cout (ix) (i:i) .eq.' ') cout (ix) &
      (i:i) = '0'                                                       
      ENDDO 
      ENDDO 
      WRITE (2, 5000) (cout (ix), ix = 1, out_inc (1) ) 
      ENDDO 
      WRITE (2, 1111) 'showpage' 
!                                                                       
      CLOSE (2) 
!                                                                       
 1111 FORMAT (a) 
 2000 FORMAT ('/DataString ',I4,' string def'/3(I3,1X),                 &
     &        ' [ ',6(I3,1X),']'/'{'/                                   &
     &        '  currentfile DataString readhexstring pop'/             &
     &        ' }  false 3 colorimage')                                 
 5000 FORMAT (10A6) 
!                                                                       
      END SUBROUTINE do_post                        
!*****7*****************************************************************
      SUBROUTINE do_pgm (value, laver) 
!-                                                                      
!     Writes the data in a PGM format                                   
!-                                                                      
      USE discus_config_mod 
      USE diffuse_mod 
      USE output_mod 
      USE qval_mod
      USE errlist_mod 
      IMPLICIT none 
!                                                                       
!                                                                       
      INTEGER maxcol 
      PARAMETER (maxcol = 255) 
!                                                                       
      INTEGER iqqq (maxqxy), ncol, ix, iy, k, value 
      LOGICAL lread, laver 
      REAL qqq 
!                                                                       
!     REAL qval 
!                                                                       
!     Check whether data are 2-dimensional                              
!                                                                       
      IF (.not. (out_inc (1) .gt.1.and.out_inc (2) .gt.1) ) THEN 
         ier_num = - 50 
         ier_typ = ER_APPL 
         RETURN 
      ENDIF 
!                                                                       
      lread = .false. 
      ncol = maxcol 
!                                                                       
      CALL oeffne (2, outfile, 'unknown') 
      IF (ier_num.ne.0) return 
!                                                                       
      WRITE (2, 1111) 'P2' 
      WRITE (2, 2000) out_inc (1), out_inc (2), ncol 
!                                                                       
      DO iy = out_inc (2), 1, - 1 
      DO ix = 1, out_inc (1) 
      k = (ix - 1) * out_inc (2) + iy 
      qqq = qval (k, value, ix, iy, laver) 
      IF (qqq.lt.zmin) THEN 
         qqq = zmin 
      ELSEIF (qqq.gt.zmax) THEN 
         qqq = zmax 
      ENDIF 
      iqqq (ix) = nint (REAL(ncol - 1) * (qqq - zmin) / (zmax - zmin) &
      )                                                                 
      ENDDO 
      WRITE (2, 5000) (iqqq (ix), ix = 1, out_inc (1) ) 
      ENDDO 
!                                                                       
      CLOSE (2) 
!                                                                       
 1111 FORMAT     (a) 
 2000 FORMAT    (2(1x,i4)/1x,i8) 
 5000 FORMAT     (7i8) 
!                                                                       
      END SUBROUTINE do_pgm                         
!*****7*****************************************************************
      SUBROUTINE do_ppm (value, laver) 
!+                                                                      
!     Writes the data in a PGM format                                   
!-                                                                      
      USE discus_config_mod 
      USE diffuse_mod 
      USE output_mod 
      USE qval_mod
      USE envir_mod 
      USE errlist_mod 
      IMPLICIT none 
!                                                                       
!                                                                       
      INTEGER maxcol 
      PARAMETER (maxcol = 255) 
!                                                                       
      INTEGER iqqq (maxqxy), ncol, ix, iy, k, value 
      INTEGER icolor (maxcol, 3) 
      INTEGER i, j 
      LOGICAL lread, laver 
      REAL qqq 
!                                                                       
!     REAL qval 
!                                                                       
      CHARACTER(6) cfarb (256) 
!                                                                       
!                                                                       
!     Check whether data are 2-dimensional                              
!                                                                       
      IF (.not. (out_inc (1) .gt.1.and.out_inc (2) .gt.1) ) THEN 
         ier_num = - 50 
         ier_typ = ER_APPL 
         RETURN 
      ENDIF 
!                                                                       
!-------Farbtabelle einlesen                                            
!                                                                       
      CALL set_colorfeld (cfarb) 
      lread = .true. 
      CALL oeffne (2, colorfile, 'old') 
      IF (ier_num.ne.0) return 
      DO i = 1, 255 
      READ (2, 100, end = 20) (icolor (i, j), j = 1, 3) 
  100 FORMAT      (1x,3z2) 
      ENDDO 
   20 CONTINUE 
      CLOSE (2) 
!                                                                       
      icolor (255, 1) = 255 
      icolor (255, 2) = 255 
      icolor (255, 3) = 255 
!                                                                       
      lread = .false. 
      CALL oeffne (2, outfile, 'unknown') 
      IF (ier_num.ne.0) return 
!                                                                       
      ncol = maxcol 
      WRITE (2, 1111) 'P3' 
      WRITE (2, 2000) out_inc (1), out_inc (2), ncol 
!                                                                       
      DO iy = out_inc (2), 1, - 1 
      DO ix = 1, out_inc (1) 
      k = (ix - 1) * out_inc (2) + iy 
      qqq = qval (k, value, ix, iy, laver) 
      IF (qqq.lt.zmin) THEN 
         qqq = zmin 
      ELSEIF (qqq.gt.zmax) THEN 
         qqq = zmax 
      ENDIF 
      iqqq (ix) = nint (REAL(ncol - 1) * (qqq - zmin) / (zmax - zmin) &
      ) + 1                                                             
      ENDDO 
      WRITE (2, 5000) ( (icolor (iqqq (ix), j), j = 1, 3), ix = 1,      &
      out_inc (1) )                                                     
      ENDDO 
!                                                                       
      CLOSE (2) 
!                                                                       
 1111 FORMAT     (a) 
 2000 FORMAT    (1x,2i4/1x,i8) 
 5000 FORMAT     (15i4) 
!                                                                       
      END SUBROUTINE do_ppm                         
!*****7*****************************************************************
      SUBROUTINE set_colorfeld (cfarb) 
!+                                                                      
!     This routine sets the pseudo color color map                      
!-                                                                      
      IMPLICIT NONE
!
      INTEGER, PARAMETER ::maxcol = 256 
!                                                                       
      CHARACTER (LEN=*),DIMENSION(maxcol) :: cfarb !(maxcol) 
      CHARACTER(LEN=20),DIMENSION(maxcol) :: ccc   ! (256) 
      INTEGER,          DIMENSION(3)      :: rgb (3) 
      INTEGER                             :: i,ii,j,ifarb
      REAL                                :: rh, rp, rq, rt, rf
!                                                                       
      cfarb (1) = '000000' 
!                                                                       
      DO ifarb = 2, 256 
      rh = 0.1 + REAL(ifarb - 1) / 283.0 
      rh = 6.0 * rh 
      i = int (rh) 
      rf = rh - REAL(i) 
      rp = 0.0 
      rq = 1.0 - rf 
      rt = (1.0 - (1.0 - rf) ) 
!                                                                       
      IF (rt.gt.1.0) rt = 1.0 
      IF (rp.gt.1.0) rp = 1.0 
      IF (rq.gt.1.0) rq = 1.0 
!                                                                       
      IF (i.eq.0) THEN 
         rgb (1) = int (0.5 + 1. * 255.0) 
         rgb (2) = int (0.5 + rt * 255.0) 
         rgb (3) = int (0.5 + rp * 255.0) 
      ELSEIF (i.eq.1) THEN 
         rgb (1) = int (0.5 + rq * 255.0) 
         rgb (2) = int (0.5 + 1. * 255.0) 
         rgb (3) = int (0.5 + rp * 255.0) 
      ELSEIF (i.eq.2) THEN 
         rgb (1) = int (0.5 + rp * 255.0) 
         rgb (2) = int (0.5 + 1. * 255.0) 
         rgb (3) = int (0.5 + rt * 255.0) 
      ELSEIF (i.eq.3) THEN 
         rgb (1) = int (0.5 + rp * 255.0) 
         rgb (2) = int (0.5 + rq * 255.0) 
         rgb (3) = int (0.5 + 1. * 255.0) 
      ELSEIF (i.eq.4) THEN 
         rgb (1) = int (0.5 + rt * 255.0) 
         rgb (2) = int (0.5 + rp * 255.0) 
         rgb (3) = int (0.5 + 1. * 255.0) 
      ELSEIF (i.eq.5) THEN 
         rgb (1) = int (0.5 + 1. * 255.0) 
         rgb (2) = int (0.5 + rp * 255.0) 
         rgb (3) = int (0.5 + rq * 255.0) 
      ENDIF 
!                                                                       
      WRITE (ccc (ifarb), 1000) (rgb (j), j = 3, 1, - 1) 
      DO ii = 1, 6 
      IF (ccc (ifarb) (ii:ii) .eq.' ') ccc (ifarb) (ii:ii) = '0' 
      ENDDO 
!                                                                       
      WRITE (cfarb (ifarb), 1000) (rgb (j), j = 3, 1, - 1) 
      DO ii = 1, 6 
      IF (cfarb (ifarb) (ii:ii) .eq.' ') cfarb (ifarb) (ii:ii) = '0' 
      ENDDO 
      ENDDO 
      DO ifarb = 256, 2, - 1 
      WRITE (44, 2000) ccc (ifarb) 
      ENDDO 
      CLOSE (44) 
!                                                                       
 1000 FORMAT     (3(z2)) 
 2000 FORMAT    ('#',a6,'00') 
      END SUBROUTINE set_colorfeld                  
!*****7*****************************************************************
      SUBROUTINE do_output (value, laver) 
!-                                                                      
!     Writes output in standard or GNUPLOT format                       
!+                                                                      
      USE discus_config_mod 
      USE crystal_mod 
      USE diffuse_mod 
      USE discus_nipl_header
USE discus_fft_mod
      USE fourier_sup
      USE output_mod 
      USE qval_mod
      USE envir_mod 
      USE errlist_mod 
      USE prompt_mod 
      IMPLICIT none 
!                                                                       
       
!                                                                       
      INTEGER iff 
      PARAMETER (iff = 2) 
!                                                                       
      CHARACTER(LEN=2024) dummy_file
      INTEGER HKLF4, LIST5, LIST9 , ASCII3D
      PARAMETER (HKLF4 = 6, LIST5 = 7, LIST9 = 8, ASCII3D = 9) 
!                                                                       
      INTEGER extr_ima, i, j, k, l, value 
      LOGICAL lread, laver 
      REAL h (3) 
      REAL sq, qq, out_fac 
!                                                                       
      INTEGER shel_inc (2) 
      INTEGER shel_value 
      REAL shel_eck (3, 4) 
      REAL shel_vi (3, 3) 
      REAL shel_000 
      COMPLEX shel_csf 
      COMPLEX shel_acsf 
      REAL shel_dsi 
      COMPLEX shel_tcsf 
      REAL factor
!
      INTEGER                            :: npkt1      ! Points in 1D files standard file format
      INTEGER                            :: npkt2      ! Points in 2D files standard file format
      INTEGER                            :: npkt3      ! Points in 3D files standard file format
      INTEGER                            :: all_status ! Allocation status 
      INTEGER                            :: is_dim     ! dimension of standard output file
      INTEGER                            :: is_axis    ! Axis of standard output file
      INTEGER, DIMENSION(1:3)            :: loop       ! Allows flexible loop index
      INTEGER, DIMENSION(1:3)            :: out_index  ! Index that is written along axis 
      REAL   , DIMENSION(1:4)            :: ranges     ! xmin, xmax, ymin, ymax for NIPL files
      REAL   , DIMENSION(:), ALLOCATABLE :: xwrt  ! 'x' - values for standard 1D files
      REAL   , DIMENSION(:), ALLOCATABLE :: ywrt  ! 'x' - values for standard 1D files
      REAL   , DIMENSION(:,:), ALLOCATABLE :: zwrt  ! 'z' - values for standard 2D files
      REAL   , DIMENSION(:,:), ALLOCATABLE :: znew  ! 'z' - values for 3Dpdf    2D files
INTEGER :: nnew1, nnew2
!
REAL(KIND=PREC_SP), DIMENSION(3, 4)       :: pdf3d_eck
REAL(KIND=PREC_SP), DIMENSION(3, 3)       :: pdf3d_vi
INTEGER           , DIMENSION(3)          :: pdf3d_inc
!
      CHARACTER (LEN=160), DIMENSION(:), ALLOCATABLE :: header_lines
      INTEGER :: nheader
!                                                                       
!     REAL qval 
      INTEGER  len_str
      factor = 0.0
      npkt3  = 1
!                                                                       
!     If output type is shelx, calculate qval(000) for scaling          
!                                                                       
      IF (ityp.eq.HKLF4.or.ityp.eq.LIST5) THEN 
         DO i = 1, 3 
         shel_inc (i) = inc (i) 
         ENDDO 
         DO i = 1, 3 
         DO j = 1, 4 
         shel_eck (i, j) = eck (i, j) 
         ENDDO 
         DO j = 1, 4 
         shel_vi (i, j) = vi (i, j) 
         ENDDO 
         ENDDO 
         shel_tcsf = CMPLX(csf (1),KIND=KIND(0.0)) 
         shel_acsf = CMPLX(acsf (1),KIND=KIND(0.0)) 
         shel_dsi = REAL(dsi (1)) 
         inc (1) = 1 
         inc (2) = 1 
         inc (3) = 1 
         DO i = 1, 3 
         DO j = 1, 4 
         eck (i, j) = 0.0 
         ENDDO 
         DO j = 1, 3 
         vi (i, j) = 0.0 
         ENDDO 
         ENDDO 
         IF (ityp.eq.HKLF4) THEN 
            value = 1 
         ELSEIF (ityp.eq.LIST5) THEN 
            value = 2 
         ENDIF 
         CALL four_run 
         shel_csf = CMPLX(csf (1), KIND=KIND(0.0))
         shel_000 = qval (1, value, 1, 1, laver) 
         qq = qval (1, value, 1, 1, laver) / cr_icc (1) / cr_icc (2)    &
         / cr_icc (3)                                                   
         IF (ityp.eq.HKLF4) THEN 
            factor = max (int (log (qq) / log (10.0) ) - 3, 0) 
         ELSEIF (ityp.eq.LIST5) THEN 
            factor = max (int (log (qq) / log (10.0) ) - 2, 0) 
         ENDIF 
         out_fac = 10** ( - factor) 
         csf (1) = shel_tcsf 
         acsf (1) = shel_acsf 
         dsi (1) = shel_dsi 
         DO i = 1, 3 
         inc (i) = shel_inc (i) 
         ENDDO 
         DO i = 1, 3 
         DO j = 1, 4 
         eck (i, j) = shel_eck (i, j) 
         ENDDO 
         DO j = 1, 3 
         vi (i, j) = shel_vi (i, j) 
         ENDDO 
         ENDDO 
      ENDIF 
!                                                                       
      extr_ima = 6 - out_extr_abs - out_extr_ord 
!                                                                       
IF(ityp.eq.0) THEN      ! A standard file, allocate temporary arrays
!                               Write data to temporary data structure 
!                               This allows to copy to KUPLOT
   IF(    out_inc(2) == 1 .and. out_inc(3) == 1 ) THEN ! 1D file along axis 1
      is_axis = 1  ! Axis is 1
      is_dim  = 1  ! is a 1D file
   ELSEIF(out_inc(1) == 1 .and. out_inc(3) == 1 ) THEN ! 1D file along axis 2
      is_axis = 2  ! Axis is 2
      is_dim  = 1  ! is a 1D file
   ELSEIF(out_inc(1) == 1 .and. out_inc(2) == 1 ) THEN ! 1D file along axis 3
      is_axis = 3  ! Axis is 3
      is_dim  = 1  ! is a 1D file
   ELSEIF(out_inc(3) == 1 ) THEN                       ! 2d Normal to axis 3
      is_axis = 3  ! Axis is 3
      is_dim  = 2  ! is a 2D file
      npkt1   = out_inc(1)
      npkt2   = out_inc(2)
      ranges(1) = out_eck (out_extr_abs, 1)
      ranges(2) = out_eck (out_extr_abs, 2)
      ranges(3) = out_eck (out_extr_ord, 1)
      ranges(4) = out_eck (out_extr_ord, 3)
!  ELSEIF(out_inc(2) == 1 ) THEN                       ! 2d Normal to axis 2
!     is_axis = 2  ! Axis is 2
!     is_dim  = 2  ! is a 2D file
!     npkt1   = out_inc(1)
!     npkt2   = out_inc(3)
!     ranges(1) = out_eck (out_extr_abs, 1)
!     ranges(2) = out_eck (out_extr_abs, 2)
!     ranges(3) = out_eck (out_extr_ord, 1)
!     ranges(4) = out_eck (out_extr_ord, 4)
!  ELSEIF(out_inc(1) == 1 ) THEN                       ! 2d Normal to axis 1
!     is_axis = 1  ! Axis is 1
!     is_dim  = 2  ! is a 2D file
!     npkt1   = out_inc(2)
!     npkt2   = out_inc(3)
!     ranges(1) = out_eck (out_extr_abs, 1)
!     ranges(2) = out_eck (out_extr_abs, 3)
!     ranges(3) = out_eck (out_extr_ord, 1)
!     ranges(4) = out_eck (out_extr_ord, 4)
   ELSE
      is_dim  = 3
      npkt1   = out_inc(1)
      npkt2   = out_inc(2)
      npkt3   = out_inc(3)
      ranges(1) = out_eck (out_extr_abs, 1)
      ranges(2) = out_eck (out_extr_abs, 2)
      ranges(3) = out_eck (out_extr_ord, 1)
      ranges(4) = out_eck (out_extr_ord, 3)
   ENDIF
!
   IF(is_dim==1) THEN                           ! 1D output
      out_index(1) = out_extr_abs
      out_index(2) = out_extr_ord
      out_index(3) =     extr_ima
      npkt1 = out_inc(is_axis)
      ALLOCATE(xwrt(1:npkt1), STAT=all_status)  ! Allocate x-table
      ALLOCATE(ywrt(1:npkt1), STAT=all_status)  ! Allocate y-table
      loop = 1                                  ! Preset all loop indices to 1
      j    = 1
      DO i = 1, out_inc (is_axis)   ! loop along axis is_axis 
         loop(is_axis) = i
         DO k = 1, 3 
            h (k) = out_eck(k,1) + out_vi(k,1) * REAL(loop(1)-1)   &
                                 + out_vi(k,2) * REAL(loop(2)-1)   &
                                 + out_vi(k,3) * REAL(loop(3)-1)  
         ENDDO 
         xwrt(i) = h(out_extr_abs)
         ywrt(i) = qval (i, value, i, j, laver)
      ENDDO 
      CALL output_save_file_1d(outfile, npkt1, xwrt, ywrt)
      DEALLOCATE(xwrt)
      DEALLOCATE(ywrt)
   ELSEIF(is_dim==2) THEN                       ! 2D output
      ALLOCATE(zwrt(1:npkt1,1:npkt2), STAT=all_status)  ! Allocate z-table
      l = 1
      DO j = 1, npkt2
         DO i=1,npkt1
            zwrt(i,j) = (qval ( (i - 1) * out_inc(3)*out_inc (2) +        &
                                (j - 1) * out_inc(3)             + l,     &
                         value,  i, j, laver))
         ENDDO 
      ENDDO 
      nnew1 = NPKT1
      nnew2 = NPKT2
      IF(value==val_3Dpdf) THEN
         nnew1 = 201
         nnew2 = 201
         pdf3d_eck(1,1) = -2.0
         pdf3d_eck(2,1) = -2.0
         pdf3d_eck(3,1) =  0.0
         pdf3d_eck(1,2) =  2.0
         pdf3d_eck(2,2) = -2.0
         pdf3d_eck(3,2) =  0.0
         pdf3d_eck(1,3) = -2.0
         pdf3d_eck(2,3) =  2.0
         pdf3d_eck(3,3) =  0.0
         pdf3d_inc(1) = nnew1
         pdf3d_inc(2) = nnew2
         pdf3d_vi(1,1) = (pdf3d_eck(1,2)-pdf3d_eck(1,1))/REAL(nnew1-1)
         pdf3d_vi(2,1) = (pdf3d_eck(2,2)-pdf3d_eck(2,1))/REAL(nnew1-1)
         pdf3d_vi(3,1) = (pdf3d_eck(3,2)-pdf3d_eck(3,1))/REAL(nnew1-1)
         pdf3d_vi(1,2) = (pdf3d_eck(1,3)-pdf3d_eck(1,1))/REAL(nnew2-1)
         pdf3d_vi(2,2) = (pdf3d_eck(2,3)-pdf3d_eck(2,1))/REAL(nnew2-1)
         pdf3d_vi(3,2) = (pdf3d_eck(3,3)-pdf3d_eck(3,1))/REAL(nnew2-1)
         ALLOCATE(znew(nnew1, nnew2))
         znew(:,:) = 0.0D0
         CALL do_fft_2d_cos(npkt1, npkt2, zwrt, out_eck, out_vi, out_inc, &
                            nnew1, nnew2, znew, pdf3d_eck, pdf3d_vi, pdf3d_inc)
         DEALLOCATE(zwrt)
         ALLOCATE(zwrt(nnew1, nnew2))
         zwrt(:,:) = znew(:,:)
         ranges(1) = pdf3d_eck (1, 1)
         ranges(2) = pdf3d_eck (1, 2)
         ranges(3) = pdf3d_eck (2, 1)
         ranges(4) = pdf3d_eck (2, 3)
      ENDIF
      CALL write_discus_nipl_header(header_lines, nheader, l)
      CALL output_save_file_2d(outfile, ranges, nnew1, nnew2, zwrt,       &
                               header_lines, nheader)
      DEALLOCATE(header_lines)
      DEALLOCATE(zwrt)
   ELSEIF(is_dim==3) THEN                       ! 3D output into standard slices
      ALLOCATE(zwrt(1:npkt1,1:npkt2), STAT=all_status)  ! Allocate z-table
      DO l = 1, npkt3                           ! For all layers along 3rd axis
         CALL write_discus_nipl_header(header_lines, nheader, l)
         WRITE(dummy_file, 7777) outfile(1:len_str(outfile)),l  ! Modify file name
7777 FORMAT(a,'.PART_',i4.4)
         DO j = 1, npkt2                        ! Loop over points in 2D
            DO i=1,npkt1                        ! and copy into intensity file
               zwrt(i,j) = (qval ( (i - 1) * out_inc(3)*out_inc (2) +        &
                                   (j - 1) * out_inc(3)             + l,     &
                            value,  i, j, laver))
            ENDDO 
         ENDDO 
         CALL output_save_file_2d(dummy_file, ranges, npkt1, npkt2, zwrt,    &
                                  header_lines, nheader)
         DEALLOCATE(header_lines)
      ENDDO 
      DEALLOCATE(zwrt)
   ENDIF
ELSE      ! Data types ityp==0 or ELSE ! Block for all but standard file formats
      lread = .false. 
      IF(.not.(out_inc(3) > 1 .and. ityp.eq.0) ) THEN   ! NOT multiple layers in standard file type
         CALL oeffne (iff, outfile, 'unknown') 
      ENDIF
      IF (ier_num.eq.0) THEN 
         IF (out_inc (1) .gt.1.and.out_inc (2) .gt.1) THEN  ! 2D or 3D data
            IF (ityp.eq.0) THEN                             ! Standard file format
!               DO l=1, out_inc(3)
!                  IF(out_inc(3) > 1) THEN
!                     WRITE(dummy_file, 7777) outfile(1:len_str(outfile)),l
!7777 FORMAT(a,'.PART_',i4.4)
!                     CALL oeffne (iff, dummy_file, 'unknown') 
!                  ENDIF
!               WRITE (iff, * ) out_inc (1), out_inc(2)
!               WRITE (iff, * ) out_eck (out_extr_abs, 1), out_eck (out_extr_abs, 2), &
!                               out_eck (out_extr_ord, 1), out_eck (out_extr_ord, 3)
!               DO j = 1, out_inc (2) 
!               WRITE (iff, 4) (qval ( (i - 1) * out_inc(3)*out_inc (2) +        &
!                                      (j - 1) * out_inc(3)             + l,     &
!                                      value,  i, j, laver), i = 1, out_inc (1) )
!               WRITE (iff, 100) 
!               ENDDO 
!                  IF(out_inc(3) > 1) THEN
!                     CLOSE(iff)
!                  ENDIF
!               ENDDO 
            ELSEIF (ityp.eq.ASCII3D) THEN                   ! 3D "NIPL" file
               WRITE (iff, * ) out_inc (1), out_inc(2), out_inc(3)
               WRITE (iff, * ) out_eck (out_extr_abs, 1), out_eck (out_extr_abs, 2), &
                               out_eck (out_extr_ord, 1), out_eck (out_extr_ord, 3), &
                               out_eck (out_extr_top, 1), out_eck (out_extr_top, 4)
               DO l=1, out_inc(3)
                  DO j = 1, out_inc (2) 
                  WRITE (iff, 4) (qval ( (i - 1) * out_inc(3)*out_inc (2) +        &
                                         (j - 1) * out_inc(3)             + l,     &
                                         value,  i, j, laver), i = 1, out_inc (1) )
                  WRITE (iff, 100) 
                  ENDDO 
                  IF(out_inc(3) > 1) THEN
                     CLOSE(iff)
                  ENDIF
               ENDDO 
            ELSEIF (ityp.eq.HKLF4) THEN                     ! SHELXS HKL File
               DO l = 1, out_inc (3) 
               DO j = 1, out_inc (2) 
               DO i = 1, out_inc (1) 
               DO k = 1, 3 
               h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)   &
                                      + out_vi (k, 2) * REAL(j - 1)   &
                                      + out_vi (k, 3) * REAL(l - 1)
               ENDDO 
            IF( (INT(h(1)))**2 + (INT(h(2)))**2 + (INT(h(3)))**2 /= 0 ) THEN
!              k  = (i - 1) * out_inc (2) + j 
               k  = (i - 1) * out_inc (3) * out_inc (2) + (j-1) * out_inc (3) + l 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (2) / cr_icc (3) * out_fac
               sq = sqrt (qq) 
               WRITE (iff, 7) int (h (1) ), int (h (2) ), int (h (3) ), qq, sq
            ENDIF
               ENDDO 
               ENDDO 
               ENDDO 
            ELSEIF (ityp.eq.LIST5) THEN                     ! SHELXS HKL Fobs Fcalc File
               shel_value = 3 
               DO l = 1, out_inc (3) 
               DO j = 1, out_inc (2) 
               DO i = 1, out_inc (1) 
               DO k = 1, 3 
               h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)   &
                                      + out_vi (k, 2) * REAL(j - 1)   &
                                      + out_vi (k, 3) * REAL(l - 1)
               ENDDO 
            IF( (INT(h(1)))**2 + (INT(h(2)))**2 + (INT(h(3)))**2 /= 0 ) THEN
               k  = (i - 1) * out_inc (3) * out_inc (2) + (j-1) * out_inc (3) + l 
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (2) / cr_icc (3) * out_fac
               shel_value = 3 
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 8) int (h (1) ), int (h (2) ), int (h (3) ), qq, qq, sq
            ENDIF
               ENDDO 
               ENDDO 
               ENDDO 
            ELSEIF (ityp.eq.LIST9) THEN                     ! SHELXS File
               shel_value = 3 
               DO l = 1, out_inc (3) 
               DO j = 1, out_inc (2) 
               DO i = 1, out_inc (1) 
               DO k = 1, 3 
               h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)   &
                                      + out_vi (k, 2) * REAL(j - 1)   &
                                      + out_vi (k, 3) * REAL(l - 1)
               ENDDO 
            IF( (INT(h(1)))**2 + (INT(h(2)))**2 + (INT(h(3)))**2 /= 0 ) THEN
               k  = (i - 1) * out_inc (3) * out_inc (2) + (j-1) * out_inc (3) + l 
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (2) / cr_icc (3)
               shel_value = 3 
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 9) h (1), h (2), h (3), qq, qq, sq 
            ENDIF
               ENDDO 
               ENDDO 
               ENDDO 
            ELSE             ! Should be GNU type == 3      ! Standard 2D File
               DO j = 1, out_inc (2) 
               DO i = 1, out_inc (1) 
               DO k = 1, 3 
               h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)   &
               + out_vi (k, 2) * REAL(j - 1)                          
               ENDDO 
               k = (i - 1) * out_inc (2) + j 
               WRITE (iff, 5) h (out_extr_abs), h (out_extr_ord),       &
               qval (k, value, i, j, laver), h (extr_ima)               
               ENDDO 
               WRITE (iff, 100) 
               ENDDO 
            ENDIF 
         ELSEIF (out_inc (1) .eq.1) THEN                    ! 1D Files
            IF(ityp /= 0) THEN                              ! All BUT standard files
            i = 1 
            DO j = 1, out_inc (2) 
            DO k = 1, 3 
            h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)      &
            + out_vi (k, 2) * REAL(j - 1)                             
            ENDDO 
            k = (i - 1) * out_inc (2) + j 
            IF( (INT(h(1)))**2 + (INT(h(2)))**2 + (INT(h(3)))**2 /= 0 ) THEN
            IF (ityp.eq.HKLF4) THEN                         ! SHELXS HKL INTENSITY
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3) * out_fac                                
               sq = sqrt (qq) 
               WRITE (iff, 7) int (h (1) ), int (h (2) ), int (h (3) ), &
               qq, sq                                                   
            ELSEIF (ityp.eq.LIST5) THEN                     ! SHELXS Fobs Fcalc
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3) * out_fac                                
               shel_value = 3 
!              sq = qval (k, shel_value, i, j, laver) / cr_icc (1)      &
!              / cr_icc (2) / cr_icc (3) * out_fac                      
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 8) int (h (1) ), int (h (2) ), int (h (3) ), &
               qq, qq, sq                                               
            ELSEIF (ityp.eq.LIST9) THEN                     ! SHELXS
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3)                                          
               shel_value = 3 
!              sq = qval (k, shel_value, i, j, laver) / cr_icc (1)      &
!              / cr_icc (2) / cr_icc (3)                                
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 9) h (1), h (2), h (3), qq, qq, sq 
            ENDIF 
            ENDIF 
               ENDDO 
            ELSE     ! Should be GNU type == 3              ! Standard File
               i = 1 
               DO j = 1, out_inc (2) 
                  DO k = 1, 3 
                     h(k) = out_eck(k,1) + out_vi(k,1) * REAL(i-1)    &
                                         + out_vi(k,2) * REAL(j-1)
                  ENDDO 
                  k       = (i - 1) * out_inc (2) + j 
                  WRITE(iff,6) h(out_extr_ord), qval(k,value,i,j,laver)
                  xwrt(i) = h(out_extr_ord)
                  ywrt(i) = qval (k, value, i, j, laver)
               ENDDO 
            ENDIF 
         ELSEIF (out_inc (2) .eq.1) THEN 
            IF(ityp /= 0) THEN                              ! All BUT standard files
            j = 1 
            DO i = 1, out_inc (1) 
            DO k = 1, 3 
            h (k) = out_eck (k, 1) + out_vi (k, 1) * REAL(i - 1)      &
            + out_vi (k, 2) * REAL(j - 1)                             
            ENDDO 
            k = (i - 1) * out_inc (2) + j 
            IF( (INT(h(1)))**2 + (INT(h(2)))**2 + (INT(h(3)))**2 /= 0 ) THEN
            IF (ityp.eq.HKLF4) THEN                         ! SHELXS Intensity
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3) * out_fac                                
               sq = sqrt (qq) 
               WRITE (iff, 7) int (h (1) ), int (h (2) ), int (h (3) ), &
               qq, sq                                                   
            ELSEIF (ityp.eq.LIST5) THEN                     ! SHELS Fobs Fcalc
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3) * out_fac                                
               shel_value = 3 
!              sq = qval (k, shel_value, i, j, laver) / cr_icc (1)      &
!              / cr_icc (2) / cr_icc (3) * out_fac                      
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 8) int (h (1) ), int (h (2) ), int (h (3) ), &
               qq, qq, sq                                               
            ELSEIF (ityp.eq.LIST9) THEN                     ! SHELS File
               shel_value = 2 
               qq = qval (k, value, i, j, laver) / cr_icc (1) / cr_icc (&
               2) / cr_icc (3)                                          
               shel_value = 3 
!              sq = qval (k, shel_value, i, j, laver) / cr_icc (1)      &
!              / cr_icc (2) / cr_icc (3)                                
               sq = qval (k, shel_value, i, j, laver) 
               IF(sq < 0.0 ) sq = sq + 360.0
               WRITE (iff, 9) h (1), h (2), h (3), qq, qq, sq 
            ENDIF 
            ENDIF 
            ENDDO 
            ELSE                                            ! Standard File
!              j = 1 
!              DO i = 1, out_inc (1) 
!                 DO k = 1, 3 
!                    h (k) = out_eck(k,1) + out_vi(k,1) * REAL(i-1)   &
!                                         + out_vi(k,2) * REAL(j-1)
!                 ENDDO 
!                 k = (i - 1) * out_inc (2) + j 
!                 WRITE(iff,6) h(out_extr_abs), qval(k,value,i,j,laver)
!              ENDDO 
            ENDIF 
         ENDIF 
      ENDIF 
!     if(ier_num.ne.0) THEN                                             
!       call errlist                                                    
!     endif                                                             
      IF (ityp.eq.HKLF4.or.ityp.eq.LIST5) THEN 
         WRITE (output_io, 1000) out_fac 
      ENDIF 
      CLOSE (iff) 
      ENDIF       ! DATA TYPES ityp == 0 or else 
      IF(ALLOCATED(xwrt)) DEALLOCATE(xwrt,STAT=all_status)
      IF(ALLOCATED(ywrt)) DEALLOCATE(ywrt,STAT=all_status)
!                                                                       
    4 FORMAT (5(1x,e11.5)) 
    5 FORMAT (4(1x,e11.5)) 
    6 FORMAT (2(1x,e11.5)) 
    7 FORMAT (3i4,2f8.2) 
    8 FORMAT (3i4,2f10.2,f7.2) 
    9 FORMAT (3(f10.6,1x),2(e11.5,1x),f7.2) 
  100 FORMAT () 
 1000 FORMAT    (' Data have been scaled by ',g17.8e3) 
!100      format(/)                                                     
!                                                                       
      END SUBROUTINE do_output                      
!*****7*****************************************************************
      SUBROUTINE set_output (linverse) 
!-                                                                      
!     Sets the proper output values for either Fourier or               
!     inverse Fourier and Patterson                                     
!+                                                                      
      USE discus_config_mod 
      USE diffuse_mod 
      USE output_mod 
      USE patters_mod 
      IMPLICIT none 
!                                                                       
!                                                                       
      LOGICAL linverse 
!                                                                       
      INTEGER i, j 
!                                                                       
      IF (linverse) THEN 
         out_extr_abs = rho_extr_abs 
         out_extr_ord = rho_extr_ord 
!                                                                       
         DO i = 1, 3 
            DO j = 1, 3 
               out_eck (i, j) = rho_eck (i, j) 
            ENDDO 
         ENDDO 
!                                                                       
         DO i = 1, 2 
            DO j = 1, 3 
               out_vi (j, i) = rho_vi (j, i) 
            ENDDO 
            out_inc (i) = rho_inc (i) 
         ENDDO 
         out_inc(3) = 1
      ELSE 
         out_extr_abs = extr_abs 
         out_extr_ord = extr_ord 
         out_extr_top = extr_top 
!                                                                       
         DO i = 1, 3 
         DO j = 1, 4 
         out_eck (i, j) = eck (i, j) 
         ENDDO 
         ENDDO 
!                                                                       
         DO i = 1, 3 
         DO j = 1, 3 
         out_vi (j, i) = vi (j, i) 
         ENDDO 
         out_inc (i) = inc (i) 
         ENDDO 
      ENDIF 
!
      END SUBROUTINE set_output                     
!
!*******************************************************************************
!
SUBROUTINE output_reset
!
USE output_mod
!
IMPLICIT NONE
!
outfile      = 'fcalc.dat'
ityp         = 0
extr_abs     = 1
extr_ord     = 2
extr_top     = 3
rho_extr_abs = 1
rho_extr_ord = 2
out_extr_abs = 1
out_extr_ord = 2
out_extr_top = 3
out_inc(:)   = (/121, 121, 1/)
out_eck      = reshape((/ 0.0, 0.0,  0.0, &
                          5.0, 0.0,  0.0, &
                          0.0, 5.0,  0.0, &
                          0.0, 0.0,  0.0/),shape(out_eck))
out_vi       = reshape((/0.05, 0.00, 0.00, &
                         0.0 , 0.05, 0.00, &
                         0.00, 0.00, 0.00/),shape(out_vi))
cpow_form    = 'tth'
out_user_limits = .false.
out_user_values(:) = (/1.0, 10.0, 0.01/)
!
END SUBROUTINE output_reset
!
!*******************************************************************************
!
END MODULE output_menu
