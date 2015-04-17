MODULE set_sub_generic_mod
!
!  sets generic interfaces for the functions/subroutines
!  in DISCUS/DIFFEV/KUPLOT/MIXSCAT that are referenced 
!  within lib_f90 under identical name 
!  A procedure pointer is defined for eah to allow flexible 
!  switching between the routines
!
!  SUBROUTINE mache_kdo
!  SUBROUTINE ersetz_para
!  SUBROUTINE upd_para 
!  SUBROUTINE calc_intr_spec
!  SUBROUTINE validate_var_spec
!
!
INTERFACE
   SUBROUTINE mache_kdo (line, lend, length)
!                                                                       
   CHARACTER (LEN= *  ), INTENT(INOUT) :: line
   LOGICAL             , INTENT(  OUT) :: lend
   INTEGER             , INTENT(INOUT) :: length
!
   END SUBROUTINE mache_kdo
END INTERFACE
!
INTERFACE
   SUBROUTINE errlist_appl
   END SUBROUTINE errlist_appl
END INTERFACE
!
INTERFACE
   SUBROUTINE ersetz_para (ikl, iklz, string, ll, ww, maxw, ianz)
!
   CHARACTER (LEN= * )  , INTENT(INOUT) :: string
   INTEGER              , INTENT(IN   ) :: ikl
   INTEGER              , INTENT(IN   ) :: iklz
   INTEGER              , INTENT(INOUT) :: ll
   INTEGER              , INTENT(IN   ) :: maxw
   INTEGER              , INTENT(IN   ) :: ianz
   REAL, DIMENSION(MAXW), INTENT(IN   ) :: ww
!
   END SUBROUTINE ersetz_para
END INTERFACE
!
INTERFACE
   SUBROUTINE upd_para (ctype, ww, maxw, wert, ianz)
!
   CHARACTER (LEN=* ), INTENT(IN   )    :: ctype
   INTEGER           , INTENT(IN   )    :: maxw
   INTEGER           , INTENT(IN   )    :: ianz
   INTEGER           , INTENT(IN   )    :: ww (maxw)
   REAL              , INTENT(IN   )    :: wert
!
   END SUBROUTINE upd_para 
END INTERFACE
!
INTERFACE
   SUBROUTINE calc_intr_spec (string, line, ikl, iklz, ww, laenge, lp)
!
   CHARACTER (LEN= * ), INTENT(INOUT) :: string
   CHARACTER (LEN= * ), INTENT(INOUT) :: line
   INTEGER            , INTENT(IN   ) :: ikl
   INTEGER            , INTENT(IN   ) :: iklz
   REAL               , INTENT(INOUT) :: ww
   INTEGER            , INTENT(INOUT) :: laenge
   INTEGER            , INTENT(INOUT) :: lp
!
   END SUBROUTINE calc_intr_spec
END INTERFACE
!
INTERFACE
   SUBROUTINE validate_var_spec (string, lp)
!
   CHARACTER (LEN= * ), INTENT(IN   ) :: string
   INTEGER            , INTENT(IN   ) :: lp
!
   END SUBROUTINE validate_var_spec
END INTERFACE
!
INTERFACE
   SUBROUTINE execute_cost( repeat,    &
                            prog  ,  prog_l , &
                            mac   ,  mac_l  , &
                            direc ,  direc_l, &
                            kid   ,  indiv  , &
                            rvalue, l_rvalue, &
                            output, output_l, &
                            generation, member, &
                            children, parameters, &
                            trial_v, NTRIAL, &
                            ierr )
!
   IMPLICIT NONE
   LOGICAL                , INTENT(IN) :: repeat
   INTEGER                , INTENT(IN) :: prog_l
   INTEGER                , INTENT(IN) :: mac_l
   INTEGER                , INTENT(IN) :: direc_l
   INTEGER                , INTENT(IN) :: output_l
   CHARACTER(LEN=prog_l  ), INTENT(IN) :: prog
   CHARACTER(LEN=mac_l   ), INTENT(IN) :: mac
   CHARACTER(LEN=direc_l ), INTENT(IN) :: direc
   INTEGER                , INTENT(IN) :: kid
   INTEGER                , INTENT(IN) :: indiv
   CHARACTER(LEN=output_l), INTENT(IN) :: output
   REAL                   , INTENT(OUT):: rvalue
   LOGICAL                , INTENT(OUT):: l_rvalue
   INTEGER                , INTENT(IN) :: generation
   INTEGER                , INTENT(IN) :: member
   INTEGER                , INTENT(IN) :: children
   INTEGER                , INTENT(IN) :: parameters
   INTEGER                , INTENT(IN) :: NTRIAL
   REAL,DIMENSION(1:NTRIAL),INTENT(IN) :: trial_v
   INTEGER                , INTENT(OUT):: ierr
!
   END SUBROUTINE execute_cost
END INTERFACE
!
INTERFACE
   SUBROUTINE branch(zeile, length)
!
CHARACTER (LEN=*), INTENT(IN) :: zeile
INTEGER          , INTENT(IN) :: length
!
   END SUBROUTINE branch
END INTERFACE
!
!
PROCEDURE(mache_kdo     )   , POINTER :: p_mache_kdo      => NULL()
PROCEDURE(errlist_appl  )   , POINTER :: p_errlist_appl   => NULL()
PROCEDURE(ersetz_para   )   , POINTER :: p_ersetz_para    => NULL()
PROCEDURE(upd_para      )   , POINTER :: p_upd_para       => NULL()
PROCEDURE(calc_intr_spec)   , POINTER :: p_calc_intr_spec => NULL()
PROCEDURE(validate_var_spec), POINTER :: p_validate_var_spec => NULL()
PROCEDURE(execute_cost  )   , POINTER :: p_execute_cost   => NULL()
PROCEDURE(branch        )   , POINTER :: p_branch         => NULL()
!
END MODULE set_sub_generic_mod
