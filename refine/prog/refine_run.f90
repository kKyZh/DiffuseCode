MODULE refine_run_mod
!
USE refine_mac_mod
!
IMPLICIT NONE
!
REAL, DIMENSION(:,:  ), ALLOCATABLE :: refine_calc     ! Calculated (ix, iy)
REAL, DIMENSION(:,:  ), ALLOCATABLE :: refine_temp     ! Calculated (ix, iy) for derivs
REAL, DIMENSION(:,:,:), ALLOCATABLE :: refine_derivs   ! Derivativs (ix, iy, parameter)
!
CONTAINS
!
!*******************************************************************************
!
SUBROUTINE refine_run(line, length)
!
! Main Routine to perform the fit
!
USE refine_control_mod
USE refine_data_mod
USE refine_fit_erg
USE refine_params_mod
USE refine_show_mod
!
USE doact_mod
USE ber_params_mod
USE errlist_mod
USE get_params_mod
USE precision_mod
USE prompt_mod
USE take_param_mod
!
IMPLICIT NONE
!
CHARACTER(LEN=*), INTENT(INOUT) :: line          ! Input command line
INTEGER         , INTENT(INOUT) :: length        ! length of input command line
!
INTEGER, PARAMETER :: MAXW = 20
!
CHARACTER(LEN=1024), DIMENSION(MAXW) :: cpara    ! Parameter strings
INTEGER            , DIMENSION(MAXW) :: lpara    ! length of each parameter strign
REAL(KIND=PREC_DP) , DIMENSION(MAXW) :: werte    ! Parameter values
!
INTEGER                              :: i        ! Dummy loop parameter
INTEGER                              :: ndata    ! number of data points
INTEGER                              :: ianz     ! number of parameters
LOGICAL                              :: lexist   ! File exists yes/no
CHARACTER(LEN=1024)                  :: plmac    ! optional plot macro
LOGICAL                              :: ref_do_plot ! Do plot yes/no
LOGICAL                              :: linit       ! Initialize mrq
!
INTEGER, PARAMETER :: NOPTIONAL = 2
INTEGER, PARAMETER :: OPLOT     = 1
INTEGER, PARAMETER :: OINIT     = 2
CHARACTER(LEN=1024), DIMENSION(NOPTIONAL) :: oname   !Optional parameter names
CHARACTER(LEN=1024), DIMENSION(NOPTIONAL) :: opara   !Optional parameter strings returned
INTEGER            , DIMENSION(NOPTIONAL) :: loname  !Lenght opt. para name
INTEGER            , DIMENSION(NOPTIONAL) :: lopara  !Lenght opt. para name returned
LOGICAL            , DIMENSION(NOPTIONAL) :: lpresent  !opt. para present
REAL(KIND=PREC_DP) , DIMENSION(NOPTIONAL) :: owerte   ! Calculated values
INTEGER, PARAMETER                        :: ncalc = 0 ! Number of values to calculate
!
DATA oname  / 'plot' , 'init' /
DATA loname /  4     ,  4     /
opara  =  (/ '        ', 'no      '  /)
lopara =  (/ 8         ,  8          /)
owerte =  (/  0.000000 ,   0.0000000 /)
!
CALL get_params(line, ianz, cpara, lpara, MAXW, length)
IF(ianz<1) THEN                   ! Macro file name is needed
   ier_num = -6
   ier_typ = ER_FORT
   RETURN
ENDIF
CALL get_optional(ianz, MAXW, cpara, lpara, NOPTIONAL,  ncalc, &
                  oname, loname, opara, lopara, lpresent, owerte)
IF(ier_num/=0) RETURN
!
linit = refine_init .OR. opara(OINIT)=='yes'
!
IF(.NOT.ALLOCATED(ref_x)) THEN
   ier_num = -1
   ier_typ = ER_APPL
   ier_msg(1) = 'Check if data file was not loaded '
   RETURN
ENDIF
!
refine_mac   = cpara(1)
refine_mac_l = lpara(1)
INQUIRE(FILE=cpara(1)(1:lpara(1)), EXIST=lexist)
IF(.NOT.lexist) THEN              ! Macro does not exist
   ier_num = -2
   ier_typ = ER_APPL
   ier_msg(1) = 'Check if macro name was spelled correctly'
   RETURN
ENDIF
!
ref_do_plot = .FALSE.
plmac       = ' '
IF(opara(OPLOT) /= ' ') THEN
  ref_do_plot = .TRUE.
  plmac       = opara(OPLOT)
ENDIF
!
ALLOCATE(refine_calc  (ref_dim(1), ref_dim(2)))
ALLOCATE(refine_temp  (ref_dim(1), ref_dim(2)))
ALLOCATE(refine_derivs(ref_dim(1), ref_dim(2), refine_par_n))
IF(linit) THEN
  IF(ALLOCATED(refine_cl)) DEALLOCATE(refine_cl)
  ALLOCATE(refine_cl(refine_par_n, refine_par_n))
  IF(ALLOCATED(refine_alpha)) DEALLOCATE(refine_alpha)
  ALLOCATE(refine_alpha(refine_par_n, refine_par_n))
  IF(ALLOCATED(refine_beta )) DEALLOCATE(refine_beta )
  ALLOCATE(refine_beta (refine_par_n              ))
  refine_cl    = 0.0
  refine_alpha = 0.0
  refine_beta  = 0.0
ENDIF
!
! Call main refinement routine
!
CALL refine_mrq(linit, REF_MAXPARAM, refine_par_n, refine_cycles, ref_kupl,            &
                refine_params, ref_dim, ref_data, ref_sigma, ref_x, ref_y,      &
                conv_dp_sig, conv_dchi2, conv_chi2, conv_conf, lconvergence,    &
                refine_chisqr, refine_conf, refine_lamda, refine_lamda_s,       &
                refine_lamda_d, refine_lamda_u, refine_rval,                    &
                refine_rexp, refine_p, refine_range, refine_shift, refine_nderiv,&
                refine_dp, refine_cl, refine_alpha, refine_beta, ref_do_plot, plmac)
main:IF(ier_num==0) THEN
   refine_init = .FALSE.
!
! Copy fixed parameters for output
!
   DO i=1, refine_fix_n
      cpara(1) = refine_fixed(i)
      lpara(1) = LEN_TRIM(refine_fixed(i))
      ianz = 1
      CALL ber_params(ianz, cpara, lpara, werte, MAXW)
      IF(ier_num/=0) EXIT main
      refine_f(i) = werte(1)
   ENDDO
   ndata = ref_dim(1)*ref_dim(2)
   CALL show_fit_erg(output_io, REF_MAXPARAM, REF_MAXPARAM_FIX, refine_par_n, refine_fix_n,   &
                     ndata, refine_mac, refine_mac_l, ref_load, ref_kload,         &
                     ref_csigma, ref_ksigma, .FALSE., refine_chisqr, refine_conf,  &
                     refine_lamda, refine_rval, refine_rexp, refine_params,        &
                     refine_p, refine_dp, refine_range, refine_cl, refine_fixed,   &
                        refine_f,                                                     &
                     conv_dp_sig, conv_dchi2, conv_chi2, conv_conf                )
!
ENDIF main
DEALLOCATE(refine_calc)      ! Clean up temporary files
DEALLOCATE(refine_temp)
DEALLOCATE(refine_derivs)
!
lmacro_close = .TRUE.        ! Do close macros in do-loops
!
END SUBROUTINE refine_run
!
!*******************************************************************************
!
SUBROUTINE refine_theory(MAXP, ix, iy, xx, yy, NPARA, p, par_names,  &
                         prange,  p_shift, p_nderiv, &
                         data_dim, & !data_data, data_sigma, data_x, data_y, &
                         kupl_last, &
                         f, df, LDERIV)
!
! Calculates the "theoretical" value through the user macro
! Only if ix and iy == 1 the macro is actually called, otherwise
! the lookup values will be used
!
USE refine_random_mod
USE refine_set_param_mod
!
USE errlist_mod
USE matrix_mod
USE precision_mod
!
IMPLICIT NONE
!
INTEGER                                              , INTENT(IN)  :: MAXP    ! Parameter array sizes
INTEGER                                              , INTENT(IN)  :: ix      ! Point number along x
INTEGER                                              , INTENT(IN)  :: iy      ! Point number along y
REAL                                                 , INTENT(IN)  :: xx      ! Point value  along x
REAL                                                 , INTENT(IN)  :: yy      ! Point value  along y
INTEGER                                              , INTENT(IN)  :: NPARA   ! Number of refined parameters
REAL            , DIMENSION(MAXP )                   , INTENT(IN)  :: p       ! Parameter values
CHARACTER(LEN=*), DIMENSION(MAXP)                    , INTENT(IN)  :: par_names    ! Parameter names
REAL            , DIMENSION(MAXP, 2                 ), INTENT(IN)  :: prange      ! Allowed parameter range
REAL            , DIMENSION(MAXP )                   , INTENT(IN)  :: p_shift   ! Parameter shift for deriv
INTEGER         , DIMENSION(MAXP )                   , INTENT(IN)  :: p_nderiv  ! Number of points for derivative
INTEGER         , DIMENSION(2)                       , INTENT(IN)  :: data_dim     ! Data array dimensions
!REAL            , DIMENSION(data_dim(1), data_dim(2)), INTENT(IN)  :: data_data    ! Data array
!REAL            , DIMENSION(data_dim(1), data_dim(2)), INTENT(IN)  :: data_sigma  ! Data sigmas
!REAL            , DIMENSION(data_dim(1))             , INTENT(IN)  :: data_x       ! Data coordinates x
!REAL            , DIMENSION(data_dim(1))             , INTENT(IN)  :: data_y       ! Data coordinates y
INTEGER                                              , INTENT(IN)  :: kupl_last    ! Last KUPLOT DATA that are needed
REAL                                                 , INTENT(OUT) :: f       ! Function value at (ix,iy)
REAL            , DIMENSION(NPARA)                   , INTENT(OUT) :: df      ! Function derivatives at (ix,iy)
LOGICAL                                              , INTENT(IN)  :: LDERIV  ! TRUE if derivative is needed
!
!REAL, PARAMETER      :: SCALEF = 0.005! Scalefactor for parameter modification 0.01 is good?
!
INTEGER              :: k, iix, iiy, l, j2, j3 ! Dummy loop variable
INTEGER              :: nder          ! Numper of points for derivative
REAL(KIND=PREC_DP)                 :: delta         ! Shift to calculate derivatives
REAL(KIND=PREC_DP)                 :: p_d           ! Shifted  parameter
!REAL(KIND=PREC_DP), DIMENSION(5)   :: p_vals        ! Parameter at P, P+delta and P-delta
REAL(KIND=PREC_DP), DIMENSION(-2:2):: dvec          ! Parameter at P-2delta, P-delta, P, P+delta and P+2delta
LOGICAL           , DIMENSION(-2:2):: lvec          ! Calculate at P-2delta, P-delta, P, P+delta and P+2delta
REAL(KIND=PREC_DP), DIMENSION(3)   :: yvec          ! Chisquared at P, P+delta and P-delta
REAL(KIND=PREC_DP), DIMENSION(3)   :: avec          ! Params for derivative y = a + bx + cx^2
REAL(KIND=PREC_DP), DIMENSION(3,3) :: xmat          ! Rows are : 1, P, P^2
REAL(KIND=PREC_DP), DIMENSION(3,3) :: imat          ! Inverse to xmat
!
REAL, DIMENSION(:,:,:), ALLOCATABLE :: refine_tttt     ! Calculated (ix, iy) for derivs
!
IF(ix==1 .AND. iy==1) THEN            ! Initial point, call user macro
!
   DO k=1, NPARA                      ! Update user defined parameter variables
      CALL refine_set_param(NPARA, par_names(k), k, p(k))
   ENDDO 
!
   CALL refine_save_seeds             ! Save current random number seeds
   CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
                     data_dim, refine_calc)
!
   IF(ier_num /= 0) RETURN
!
!  Loop over all parameters to derive derivatives
!
   IF(LDERIV) THEN
      DO k=1, NPARA
         ALLOCATE(refine_tttt(1:data_dim(1), 1:data_dim(2), -p_nderiv(k)/2:p_nderiv(k)/2))
         nder = 1                     ! First point is at P(k)
         dvec(:) = 0.0
         lvec(:) = .FALSE.
         dvec(0) = p(k)               ! Store parameter value
         IF(p(k)/=0.0) THEN
            delta = ABS(p(k)*p_shift(k))  ! A multiplicative variation of the parameter seems best
         ELSE
            delta = 1.0D-4
         ENDIF
!                                     ! Test at P + DELTA
         IF(prange(k,1)<=prange(k,2)) THEN     ! User provided parameter range
            IF(p(k)==prange(k,1)) THEN         ! At lower limit, use +delta +2delta
               delta = MIN(ABS(delta), 0.5D0*(ABS(prange(k,2) - p(k)))) ! Make sure +2Delta fits
               dvec(1) = p(k) + delta
               dvec(2) = p(k) + 2.0D0*delta
               lvec(1) = .TRUE.
               lvec(2) = .TRUE.
               nder = 3
            ELSEIF(p(k)==prange(k,2)) THEN         ! At upper limit, use -delta -2delta
               delta = MIN(ABS(delta), 0.5D0*(ABS(p(k) - prange(k,1)))) ! Make sure -2Delta fits
               dvec(-2) = p(k) - 2.0D0*delta
               dvec(-1) = p(k) - 1.0D0*delta
               lvec(-2) = .TRUE.
               lvec(-1) = .TRUE.
               nder = 3
            ELSE                               ! within range, use +-delta or +2delta
               IF(p_nderiv(k)==3) THEN         ! Three point derivative
                  dvec(-1) = MIN(prange(k,2),MAX(prange(k,1),p(k)+REAL(delta))) ! +delta
                  dvec( 1) = MIN(prange(k,2),MAX(prange(k,1),p(k)-REAL(delta))) ! -delta
                  lvec(-1) = .TRUE.
                  lvec( 1) = .TRUE.
                  nder = 3
               ELSEIF(p_nderiv(k)==5) THEN     ! Five point derivative
                  delta = MIN(delta, 0.5D0*(ABS(prange(k,2) - p(k))),  &
                                     0.5D0*(ABS(p(k) - prange(k,1))) ) ! Make sure +-2delta fits
                  dvec(-2) = p(k) - 2.0D0*delta
                  dvec(-1) = p(k) - 1.0D0*delta
                  dvec( 1) = p(k) + 1.0D0*delta
                  dvec( 2) = p(k) + 2.0D0*delta
                  lvec(-2) = .TRUE.
                  lvec(-1) = .TRUE.
                  lvec( 1) = .TRUE.
                  lvec( 2) = .TRUE.
                  nder = 5
               ENDIF
            ENDIF
!           p_d     = MIN(prange(k,2),MAX(prange(k,1),p(k)+REAL(delta)))
         ELSE
            IF(p_nderiv(k)==3) THEN         ! Three point derivative
               dvec(-1) = p(k) - 1.0D0*delta
               dvec( 1) = p(k) + 1.0D0*delta
               lvec(-1) = .TRUE.
               lvec( 1) = .TRUE.
               nder = 3
            ELSEIF(p_nderiv(k)==5) THEN     ! Five point derivative
               dvec(-2) = p(k) - 2.0D0*delta
               dvec(-1) = p(k) - 1.0D0*delta
               dvec( 1) = p(k) + 1.0D0*delta
               dvec( 2) = p(k) + 2.0D0*delta
               lvec(-2) = .TRUE.
               lvec(-1) = .TRUE.
               lvec( 1) = .TRUE.
               lvec( 2) = .TRUE.
               nder = 5
            ENDIF
!           p_d     = p(k) + delta
         ENDIF
         DO l = -2, 2
            IF(lvec(l)) THEN
            CALL refine_set_param(NPARA, par_names(k), k, REAL(dvec(l)) )  ! Set modified value
            CALL refine_restore_seeds
            CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
                              data_dim, refine_temp)
            IF(ier_num /= 0) THEN
               DEALLOCATE(refine_tttt)
               RETURN
            ENDIF
            DO iiy=1, data_dim(2)
               DO iix=1, data_dim(1)
                  refine_tttt(iix,iiy,l) =  refine_temp(iix,iiy)
               ENDDO
            ENDDO
            ENDIF
         ENDDO
!        p_d = p(k) + delta
!        IF(p(k)/=p_d) THEN           ! Parameter is not at edge of range
!           nder = nder + 1
!           dvec(2) = p_d            ! Store parameter value at P+DELTA
!           CALL refine_set_param(NPARA, par_names(k), k, REAL(p_d) )  ! Set modified value
!           CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
!                             data_dim, refine_temp)
!           IF(ier_num /= 0) THEN
!              DEALLOCATE(refine_tttt)
!              RETURN
!           ENDIF
!           DO iiy=1, data_dim(2)
!              DO iix=1, data_dim(1)
!                 refine_tttt(iix,iiy,1) =  refine_temp(iix,iiy)
!              ENDDO
!           ENDDO
!        ENDIF
!                                     ! Test at P - DELTA
!        IF(prange(k,1)<=prange(k,2)) THEN
!           p_d     = MIN(prange(k,2),MAX(prange(k,1),p(k)-REAL(delta)))
!        ELSE
!           p_d     = p(k) - delta
!        ENDIF
!        p_d = p(k) - delta
!        IF(p(k)/=p_d) THEN           ! Parameter is not at edge of range
!           nder = nder + 1
!           dvec(3) = p_d            ! Store parameter value at P-DELTA
!           CALL refine_set_param(NPARA, par_names(k), k, REAL(p_d) )  ! Set modified value
!           CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
!                             data_dim, refine_temp)
!           IF(ier_num /= 0) THEN
!              DEALLOCATE(refine_tttt)
!              RETURN
!           ENDIF
!           DO iiy=1, data_dim(2)
!              DO iix=1, data_dim(1)
!                 refine_tttt(iix,iiy,-1) =  refine_temp(iix,iiy)
!              ENDDO
!           ENDDO
!
!        ENDIF
!                                     ! Test at P + DELTA
!        IF(p_nderiv(k)==5) THEN
!        IF(prange(k,1)<=prange(k,2)) THEN     ! User provided parameter range
!           p_d     = MIN(prange(k,2),MAX(prange(k,1),p(k)+REAL(2.*delta)))
!        ELSE
!           p_d     = p(k) + 2.*delta
!        ENDIF
!        p_d = p(k) + delta
!        IF(p(k)/=p_d) THEN           ! Parameter is not at edge of range
!           nder = nder + 1
!           dvec(2) = p_d            ! Store parameter value at P+DELTA
!           CALL refine_set_param(NPARA, par_names(k), k, REAL(p_d) )  ! Set modified value
!           CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
!                             data_dim, refine_temp)
!           IF(ier_num /= 0) THEN
!              DEALLOCATE(refine_tttt)
!              RETURN
!           ENDIF
!           DO iiy=1, data_dim(2)
!              DO iix=1, data_dim(1)
!                 refine_tttt(iix,iiy,2) =  refine_temp(iix,iiy)
!              ENDDO
!           ENDDO
!        ENDIF
!                                     ! Test at P - DELTA
!        IF(prange(k,1)<=prange(k,2)) THEN
!           p_d     = MIN(prange(k,2),MAX(prange(k,1),p(k)-REAL(2.*delta)))
!        ELSE
!           p_d     = p(k) - 2.*delta
!        ENDIF
!        p_d = p(k) - delta
!        IF(p(k)/=p_d) THEN           ! Parameter is not at edge of range
!           nder = nder + 1
!           dvec(3) = p_d            ! Store parameter value at P-DELTA
!           CALL refine_set_param(NPARA, par_names(k), k, REAL(p_d) )  ! Set modified value
!           CALL refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, par_names, p, &
!                             data_dim, refine_temp)
!           IF(ier_num /= 0) THEN
!              DEALLOCATE(refine_tttt)
!              RETURN
!           ENDIF
!           DO iiy=1, data_dim(2)
!              DO iix=1, data_dim(1)
!                 refine_tttt(iix,iiy,-2) =  refine_temp(iix,iiy)
!              ENDDO
!           ENDDO
!
!        ENDIF
!        ENDIF
         CALL refine_set_param(NPARA, par_names(k), k, p(k))  ! Return to original value
!
         IF(nder==5) THEN             ! Got all five  points for derivative
            DO iiy=1, data_dim(2)
               DO iix=1, data_dim(1)
                  refine_derivs(iix, iiy, k) = (-1.0*refine_tttt(iix,iiy, 2)   &
                                                +8.0*refine_tttt(iix,iiy, 1)   &
                                                -8.0*refine_tttt(iix,iiy,-1)   &
                                                +1.0*refine_tttt(iix,iiy,-2))/ &
                                               (12.*delta)
               ENDDO
            ENDDO
         ELSEIF(nder==3) THEN             ! Got all three points for derivative
            xmat(:,1) =  1.0
            xmat(1,2) =  dvec(0) !p(k)
            IF(lvec(2)) THEN              ! +delta, + 2delta
              j2 =  1
              j3 =  2
            ELSEIF(lvec(-2)) THEN         ! -delta, - 2delta
              j2 = -1
              j3 = -2
            ELSE
              j2 = -1
              j3 =  1
            ENDIF
              xmat(2,2) =  dvec(j2)       ! p(k) - delta
              xmat(3,2) =  dvec(j3)       ! p(k) + delta
              xmat(2,3) = (dvec(j2))**2   ! (p(k) - delta ) **2
              xmat(3,3) = (dvec(j3))**2   ! (p(k) + delta ) **2
!           xmat(2,2) =  dvec(2) !p(k) + delta
!           xmat(3,2) =  dvec(3) !p(k) - delta
!           xmat(1,3) = (dvec(0))**2 !(p(k)        ) **2
!           xmat(2,3) = (dvec(2))**2 !(p(k) + delta) **2
!           xmat(3,3) = (dvec(3))**2 !(p(k) - delta) **2
            CALL matinv3(xmat, imat)
            IF(ier_num/=0) RETURN
            DO iiy=1, data_dim(2)
               DO iix=1, data_dim(1)
!
!              Derivative is calculated as a fit of a parabola at P, P+delta, P-delta
                  yvec(1) = refine_calc  (iix, iiy)
                  yvec(2) = refine_tttt  (iix, iiy,j2)
                  yvec(3) = refine_tttt  (iix, iiy,j3)
                  avec = MATMUL(imat, yvec)
!
                  refine_derivs(iix, iiy, k) = avec(2) + 2.*avec(3)*p(k)
               ENDDO
            ENDDO
!        ELSEIF(nder==2) THEN
!           IF(dvec(2)==0) THEN          ! P + Delta failed
!              DO iiy=1, data_dim(2)
!                 DO iix=1, data_dim(1)
!                    refine_derivs(iix, iiy, k) = (refine_temp  (iix, iiy)-refine_calc  (iix, iiy))/ &
!                                                 (dvec(3)-dvec(1))
!                 ENDDO
!              ENDDO
!           ELSEIF(dvec(3)==0) THEN      ! P - Delta failed
!              DO iiy=1, data_dim(2)
!                 DO iix=1, data_dim(1)
!                    refine_derivs(iix, iiy, k) = (refine_derivs(iix, iiy,k)-refine_calc  (iix, iiy))/ &
!                                                 (dvec(2)-dvec(1))
!                 ENDDO
!              ENDDO
!           ENDIF
!
         ELSE
            ier_num = -9
            ier_typ = ER_APPL
            ier_msg(1) = par_names(k)
            DEALLOCATE(refine_tttt)
            RETURN
         ENDIF
         DEALLOCATE(refine_tttt)
!
      ENDDO
   ENDIF
!
ENDIF
!
f = refine_calc(ix, iy)           ! Function value to be returned
IF(LDERIV) THEN                   ! Derivatives are needed
   DO k=1, NPARA
      df(k) = refine_derivs(ix, iy, k)
   ENDDO
ENDIF
!
END SUBROUTINE refine_theory
!
!*******************************************************************************
!
SUBROUTINE refine_macro(MAXP, refine_mac, refine_mac_l, NPARA, kupl_last, refine_params, p, &
                        dimen, array)
!
!   Runs the user defined macro to calculate the cost value
!
USE refine_fit_set_sub_mod
USE refine_setup_mod
!
USE doact_mod
USE do_if_mod
USE do_set_mod
USE errlist_mod
USE prompt_mod
USE set_sub_generic_mod
USE sup_mod
!
IMPLICIT NONE
!
INTEGER                           , INTENT(IN)    :: MAXP          ! Parameter array size
CHARACTER(LEN=*)                  , INTENT(INOUT) :: refine_mac    ! Macro name
INTEGER                           , INTENT(INOUT) :: refine_mac_l  ! length of macro name
INTEGER                           , INTENT(IN)    :: NPARA         ! Nmber of parameters
INTEGER                           , INTENT(IN)    :: kupl_last     ! Last dat set needed in KUPLOT
CHARACTER(LEN=*), DIMENSION(MAXP ), INTENT(IN)    :: refine_params ! parameter names
REAL            , DIMENSION(MAXP ), INTENT(IN)    :: p             ! parameter values
INTEGER         , DIMENSION(2    ), INTENT(IN)    :: dimen         ! Data array dimensions
REAL            , DIMENSION(dimen(1), dimen(2)), INTENT(OUT) :: array  ! The actual data

CHARACTER(LEN=1024) :: string           ! dumy string variable
CHARACTER(len=1024) :: zeile            ! dummy string
CHARACTER(LEN=4   ) :: befehl           ! Command verb
INTEGER             :: lbef             ! length   of        befehl
INTEGER             :: lp               ! length   of        befehl
INTEGER             :: length           ! Length of a parameter name
INTEGER             :: ier_number, ier_type ! Local error status
LOGICAL             :: lend             ! TRUE if macro is finished
LOGICAL             :: l_prompt_restore
!
INTERFACE
   SUBROUTINE refine_mache_kdo (line, lend, length)
!                                                                       
   CHARACTER (LEN= *  ), INTENT(INOUT) :: line
   LOGICAL             , INTENT(  OUT) :: lend
   INTEGER             , INTENT(INOUT) :: length
!
   END SUBROUTINE refine_mache_kdo
END INTERFACE
!
CALL file_kdo(refine_mac, refine_mac_l)
lmacro_close = .FALSE.       ! Do not close macros in do-loops, return instead
!
CALL refine_kupl_last(kupl_last)   ! Set last data set needed in KUPLOT
!                            ! Turn off output
lturn_off = .true.
!lturn_off = .false.
l_prompt_restore = .FALSE.
IF(output_status == OUTPUT_SCREEN .AND.lturn_off) THEN
   l_prompt_restore = .TRUE.
   string = 'prompt, off, off, save'
   length = 22
   CALL do_set(string, length)
ENDIF
!
CALL refine_fit_set_sub
main: DO
   CALL get_cmd (string, length, befehl, lbef, zeile, lp, prompt)
   IF (ier_num == 0) THEN
      IF (string == ' '.OR.string (1:1)  == '#' .OR. string=='!') CYCLE main
      IF (befehl (1:3)  == 'do '.OR.befehl (1:2)  == 'if') THEN
         CALL do_loop (string, lend, length) !, kuplot_mache_kdo)
         IF(ier_num/=0) EXIT main
      ELSE
         CALL refine_fit_mache_kdo(string, lend, length)
      ENDIF
      IF(lend .OR. ier_num/=0) EXIT main
   ELSE
      EXIT main
   ENDIF
ENDDO main
!
ier_number = 0
ier_type   = 0
IF(ier_num==-9 .AND. ier_typ==1) THEN   ! Error condition in macro
   ier_number = -6
   ier_type   =  ER_APPL
   ier_msg(1) = 'check performance of user macro'
   ier_num = 0
   ier_typ = 0
ELSEIF(ier_num /= 0) THEN         ! Back up error status
   ier_number = ier_num
   ier_type   = ier_typ
   CALL errlist
   ier_number = -6
   ier_type   =  ER_APPL
   ier_msg(1) = 'Check performance of user macro'
   ier_num = 0
   ier_typ = 0
ENDIF
CALL macro_terminate
p_mache_kdo   => refine_mache_kdo
lmacro_close = .TRUE.       ! Do close macros in do-loops
!
!
IF(ier_number == 0 .AND. IER_NUM == 0) THEN
   CALL refine_load_calc(dimen, array)
   IF(ier_num/=0) RETURN
ENDIF
!
IF(l_prompt_restore) THEN
   string = 'prompt, on,on'
   length = 13
   CALL do_set(string, length)
ENDIF
!
IF(ier_number /= 0) THEN    ! If necessary restore error status
!  CALL refine_set_sub
   ier_num = ier_number
   ier_typ = ier_type
ENDIF
CALL refine_fit_un_sub
!
END SUBROUTINE refine_macro
!
!*******************************************************************************
!
SUBROUTINE refine_do_plot(plmac)
!
USE do_set_mod
USE set_sub_generic_mod
!
USE class_macro_internal
!
IMPLICIT NONE
!
CHARACTER(LEN=1024), INTENT(IN) :: plmac     ! optional plot macro
!
CHARACTER(LEN=1024)             :: string
CHARACTER(LEN=1024)             :: kline
INTEGER                         :: lcomm, length
!
string = 'prompt, off, off, save'
length = 22
CALL do_set(string, length)
kline = 'kuplot -macro ' // plmac(1:LEN_TRIM(plmac))
lcomm = LEN_TRIM(kline)
CALL p_branch (kline, lcomm, .FALSE.)
string = 'prompt, on,on'
length = 13
CALL do_set(string, length)
!
END SUBROUTINE refine_do_plot
!
!*******************************************************************************
!
SUBROUTINE refine_kupl_last(kupl_last)   ! Set last data set needed in KUPLOT
!
USE kuplot_mod
!
IMPLICIT NONE
!
INTEGER, INTENT(IN) :: kupl_last     ! Last dat set needed in KUPLOT
!
iz = kupl_last + 1
!
END SUBROUTINE refine_kupl_last
!
!*******************************************************************************
!
SUBROUTINE refine_load_calc(dimen, array)
!
! Transfer calculated data from last KUPLOT data set
! 
USE kuplot_mod
!
USE errlist_mod
!
IMPLICIT NONE
!
INTEGER, DIMENSION(2)                 , INTENT(IN)  :: dimen  ! Array dimensions
REAL   , DIMENSION(dimen(1), dimen(2)), INTENT(OUT) :: array  ! The actual data
!
INTEGER :: ndata    ! Data set to be loaded
INTEGER :: ix, iy   ! loop variables
!
IF(iz<1) THEN
   ier_num = -3
   ier_typ = ER_APPL
   ier_msg(1) = 'KUPLOT does not have any data sets'
   ier_msg(2) = 'Load calculated data into KUPLOT, '
   ier_msg(3) = 'or remove a ''reset'' from KUPLOT section'
   RETURN
ENDIF
!
ndata = iz-1                           ! Always last data set in KUPLOT
!
IF(lni(ndata)) THEN                    ! 2D data set
   IF(dimen(1)/=nx(ndata).OR.dimen(2)/=ny(ndata)) THEN
      ier_num = -4
      ier_typ = ER_APPL
      ier_msg(1) = 'Check x/y limits for data calculation '
      RETURN
   ENDIF
!
   DO iy=1,dimen(2)
      DO ix=1,dimen(1)
         array(ix,iy)  = z(offz(ndata - 1) + (ix - 1)*ny(ndata) + iy)
      ENDDO
   ENDDO
ELSE
   IF(dimen(1)/=len(ndata)) THEN
      ier_num = -4
      ier_typ = ER_APPL
      ier_msg(1) = 'Check x/y limits for data calculation '
      RETURN
   ENDIF
!
   DO ix=1,dimen(1)
      array(ix,1)   = y(offxy(ndata - 1) + ix)
   ENDDO
ENDIF
!
END SUBROUTINE refine_load_calc
!
!*******************************************************************************
!
SUBROUTINE refine_mrq(linit, MAXP, NPARA, ncycle, kupl_last, par_names, data_dim, &
                      data_data, data_sigma, data_x, data_y, conv_dp_sig,         &
                      conv_dchi2, conv_chi2, conv_conf, lconvergence,             &
                      chisq, conf, lamda_fin, lamda_s, lamda_d, lamda_u,  rval,   &
                      rexp, p, prange, p_shift, p_nderiv, dp, cl, alpha, beta,    &
                      ref_do_plot, plmac)
!+                                                                      
!   This routine runs the refinement cycles, interfaces with the 
!   Levenberg-Marquardt routine modified after Numerical Recipes
!-                                                                      
!
USE refine_set_param_mod
!
USE errlist_mod
USE ber_params_mod
USE calc_expr_mod
USE gamma_mod
USE param_mod 
USE precision_mod
USE prompt_mod 
!                                                                       
IMPLICIT NONE
!
LOGICAL                                              , INTENT(IN)  :: linit       ! Initialize MRQ
INTEGER                                              , INTENT(IN)  :: MAXP        ! Parameter array size
INTEGER                                              , INTENT(IN)  :: NPARA       ! Number of parameters
INTEGER                                              , INTENT(IN)  :: ncycle      ! maximum cycle number
INTEGER                                              , INTENT(IN)  :: kupl_last   ! Last KUPLOT DATA that are needed
CHARACTER(LEN=*), DIMENSION(MAXP)                    , INTENT(IN)  :: par_names   ! Parameter names
INTEGER         , DIMENSION(2)                       , INTENT(IN)  :: data_dim    ! Data array dimensions
REAL            , DIMENSION(data_dim(1), data_dim(2)), INTENT(IN)  :: data_data   ! Data array
REAL            , DIMENSION(data_dim(1), data_dim(2)), INTENT(IN)  :: data_sigma ! Data sigmas
REAL            , DIMENSION(data_dim(1))             , INTENT(IN)  :: data_x      ! Data coordinates x
REAL            , DIMENSION(data_dim(1))             , INTENT(IN)  :: data_y      ! Data coordinates y
REAL                                                 , INTENT(IN)  :: conv_dp_sig ! Max parameter shift
REAL                                                 , INTENT(IN)  :: conv_dchi2  ! Max Chi^2     shift
REAL                                                 , INTENT(IN)  :: conv_chi2   ! Min Chi^2     value 
REAL                                                 , INTENT(IN)  :: conv_conf   ! Min confidence level
LOGICAL                                              , INTENT(INOUT) :: lconvergence ! Convergence criteria were reached
REAL                                                 , INTENT(OUT) :: chisq       ! Chi^2 value
REAL                                                 , INTENT(OUT) :: conf        ! Confidence test from Gamma function
REAL                                                 , INTENT(OUT) :: lamda_fin   ! Final Marquardt lamda
REAL                                                 , INTENT(IN)    :: lamda_s    ! Start value lamda
REAL                                                 , INTENT(IN)    :: lamda_d    ! Multiplier_down
REAL                                                 , INTENT(IN)    :: lamda_u    ! Multiplier_up
REAL                                                 , INTENT(OUT) :: rval        ! Weighted R-value
REAL                                                 , INTENT(OUT) :: rexp        ! Expected R-value
!
REAL            , DIMENSION(MAXP)                    , INTENT(INOUT) :: p         ! Parameter array
REAL            , DIMENSION(MAXP,2)                  , INTENT(INOUT) :: prange    ! Parameter range
REAL            , DIMENSION(MAXP )                   , INTENT(IN)    :: p_shift   ! Parameter shift for deriv
INTEGER         , DIMENSION(MAXP )                   , INTENT(IN)    :: p_nderiv  ! Number of derivative points needed
REAL            , DIMENSION(MAXP)                    , INTENT(INOUT) :: dp        ! Parameter sigmas
REAL            , DIMENSION(NPARA, NPARA)            , INTENT(INOUT) :: cl        ! Covariance matrix
REAL            , DIMENSION(NPARA, NPARA)            , INTENT(INOUT) :: alpha
REAL            , DIMENSION(NPARA       )            , INTENT(INOUT) :: beta
LOGICAL                                              , INTENT(IN)    :: ref_do_plot ! Do plot yes/no
CHARACTER(LEN=1024)                                  , INTENT(IN)    :: plmac     ! optional plot macro
!
INTEGER :: icyc
INTEGER :: k
INTEGER :: last_i, prev_i
REAL, SAVE    :: alamda
!
INTEGER :: MAXW
INTEGER :: ianz
!
CHARACTER(LEN=1024), DIMENSION(:), ALLOCATABLE :: cpara
INTEGER            , DIMENSION(:), ALLOCATABLE :: lpara
REAL(KIND=PREC_DP) , DIMENSION(:), ALLOCATABLE :: werte
!
LOGICAL                             :: lsuccess  ! Ture if cycle improved CHI^2
LOGICAL            , DIMENSION(3)   :: lconv     ! Convergence criteria
REAL               , DIMENSION(0:3) :: last_chi
REAL               , DIMENSION(0:3) :: last_shift
REAL               , DIMENSION(0:3) :: last_conf 
REAL               , DIMENSION(:,:), ALLOCATABLE :: last_p 
INTEGER :: last_ind
!REAL :: shift
!
IF(linit) THEN        ! INITIALIZE MRQ 
   alamda     = -0.01    ! Negative lamda initializes MRQ routine
   rval       = 0.0
   rexp       = 0.0
   chisq      = 0.0
   last_chi(:)   = HUGE(0.0)
   last_shift(:) = -1.0
   last_conf(:)  = HUGE(0.0)
   last_i        = 0
ENDIF
!
! Set initial parameter values
!
MAXW = NPARA
ALLOCATE(cpara(MAXW))
ALLOCATE(lpara(MAXW))
ALLOCATE(werte(MAXW))
DO k = 1, NPARA                  ! Copy parameter names to prepare calculation
   cpara(k) = par_names(k)
   lpara(k) = LEN_TRIM(par_names(k))
ENDDO
ianz = NPARA
CALL ber_params(ianz, cpara, lpara, werte, MAXW)
DO k = 1, NPARA                  ! Copy values of the parameters
   p(k) = werte(k)
ENDDO
!
ALLOCATE(last_p(0:2,NPARA))
last_p(2,:) = p(1:NPARA)
prev_i = 2
!
WRITE(output_io,'(a,10x,a,7x,a,6x,a)') 'Cyc Chi^2/(N-P)   MAX(dP/sig) Par   Conf',&
                                       'Lambda', 'wRvalue', 'Rexp'
!
lconvergence = .FALSE.
icyc = 0
cycles:DO
!write(*,*) ' data_sigma', data_sigma(1,1), data_sigma(data_dim(1),data_dim(2)), MINVAL(data_sigma), MAXVAL(data_sigma)
   CALL mrqmin(MAXP, data_dim, data_data, data_sigma, data_x, data_y, p, NPARA, &
               par_names, prange, p_shift, p_nderiv, kupl_last, cl, alpha, beta, chisq, alamda,     &
               lamda_s, lamda_d, lamda_u, lsuccess, dp)
!
   IF(lsuccess) THEN
      IF(ref_do_plot) THEN
         CALL refine_do_plot(plmac)
      ENDIF
   ENDIF
!
   IF(ier_num/=0) EXIT cycles
   IF(lsuccess .OR. rval == 0.0) CALL refine_rvalue(rval, rexp, NPARA)
   last_shift(:) = -1.0                                             ! Set parameter shift / sigma to negative
   DO k=1, NPARA
      CALL refine_set_param(NPARA, par_names(k), k, p(k))   ! Updata parameters
      IF(ier_num/=0) EXIT cycles
      last_p(last_i,k) = p(k)
      IF(cl(k,k)/= 0.0) THEN
!        last_shift(last_i) = MAX(last_shift(last_i), ABS((p(k)-last_p(prev_i,k))/SQRT(cl(k,k)))) !/SQRT(cl(k,k))))
         IF(ABS((p(k)-last_p(prev_i,k))/SQRT(cl(k,k))) > last_shift(last_i)) THEN
            last_ind = k
            last_shift(last_i) = ABS((p(k)-last_p(prev_i,k))/SQRT(cl(k,k)))
         ENDIF
      ENDIF
   ENDDO
   conf = gammaq(REAL(data_dim(1)*data_dim(2)-2)*0.5, chisq*0.5)
   last_chi( last_i) = chisq/(data_dim(1)*data_dim(2)-NPARA)        ! Store Chi^2/(NDATA-NPARA)
   last_conf(last_i) = conf
   WRITE(*,'(i3,2g13.5e2,i4,4g13.5e2)') icyc,chisq/(data_dim(1)*data_dim(2)-NPARA), &
         last_shift(last_i), last_ind, conf, alamda, rval, rexp
!write(*,'((g13.5e2,1x))') dp(1:NPARA)
!
!  CALL refine_rvalue(rval, rexp, NPARA)
!  DO k = 1, NPARA
!     dp(k) = SQRT(ABS(cl(k,k)))
!  ENDDO
   CALL refine_best(rval)                                              ! Write best macro
   lconv(1) = (ABS(last_chi( last_i)-last_chi(prev_i))<conv_dchi2 .AND.   &
                   last_shift(last_i) < conv_dp_sig               .AND.   &
                   last_conf(last_i)  > conv_conf)
   lconv(2) = (last_shift(last_i)>0.0 .AND.                               &
               ABS(last_chi(last_i)-last_chi(prev_i))<conv_dchi2)
   lconv(3) = last_chi(last_i)  < conv_chi2
!  lconv(2) =   last_chi( last_i)  < conv_chi2
   IF(lconv(1) .OR. lconv(2) .OR. lconv(3)) THEN
!  IF(ABS(last_chi( last_i)-last_chi(prev_i))<conv_dchi2 .AND.   &
!     last_shift(last_i) < conv_dp_sig                   .AND.   &
!     last_conf(last_i)  > conv_conf                     .OR.    &
!     last_chi( last_i)  < conv_chi2                   ) THEN
      WRITE(output_io, '(/,a)') 'Convergence reached '        
      lconvergence = .TRUE.
      EXIT cycles
   ENDIF
   IF(alamda > 0.5*HUGE(0.0)) THEN
      lconvergence = .FALSE.
      EXIT cycles
   ENDIF
   prev_i = last_i
   last_i = MOD(last_i+1, 3)
   icyc   = icyc + 1
   IF(icyc==ncycle) EXIT cycles
ENDDO cycles
!
IF(.NOT. lconvergence) THEN
   IF(icyc==ncycle) THEN
      WRITE(output_io,'(/,a)') ' Maximum cycle is reached without convergence'
   ELSEIF(alamda > 0.5*HUGE(0.0)) THEN
      WRITE(output_io,'(/,a)') ' MRQ Parameter reached infinity'
   ENDIF
ENDIF
!
! Make a final call with lamda = 0 to ensure that model is up to date
!
IF(ier_num==0) THEN
   lamda_fin = alamda
   alamda = 0.0
!
   CALL mrqmin(MAXP, data_dim, data_data, data_sigma, data_x, data_y, p, NPARA, &
               par_names, prange, p_shift, p_nderiv, kupl_last, cl, alpha, beta, chisq, alamda,     &
               lamda_s, lamda_d, lamda_u, lsuccess, dp)
   CALL refine_rvalue(rval, rexp, NPARA)
!   DO k = 1, NPARA
!      dp(k) = SQRT(ABS(cl(k,k)))
!   ENDDO
   CALL refine_best(rval)                                              ! Write best macro
   alamda = lamda_fin
ENDIF
!
DEALLOCATE(cpara)
DEALLOCATE(lpara)
DEALLOCATE(werte)
DEALLOCATE(last_p)
!
END SUBROUTINE refine_mrq
!
!*******************************************************************************
!
SUBROUTINE mrqmin(MAXP, data_dim, data_data, data_sigma, data_x, data_y, a, NPARA, &
    par_names, &
    prange, p_shift, p_nderiv, kupl_last, covar, alpha, beta, chisq, alamda, lamda_s, lamda_d, lamda_u, &
    lsuccess, dp)
!
!  Least squares routine adapted from Numerical Recipes Chapter 14
!  p 526
!
USE refine_constraint_mod
USE errlist_mod
USE gaussj_mod
!
IMPLICIT NONE
!
INTEGER                                             , INTENT(IN)    :: MAXP        ! Array size for parameters
INTEGER         , DIMENSION(2)                      , INTENT(IN)    :: data_dim    ! no of ata points along x, y
REAL            , DIMENSION(data_dim(1),data_dim(2)), INTENT(IN)    :: data_data   ! Data values
REAL            , DIMENSION(data_dim(1),data_dim(2)), INTENT(IN)    :: data_sigma ! Data sigmas
REAL            , DIMENSION(data_dim(1)           ) , INTENT(IN)    :: data_x      ! Actual x-coordinates
REAL            , DIMENSION(data_dim(2)           ) , INTENT(IN)    :: data_y      ! Actual y-coordinates
INTEGER                                             , INTENT(IN)    :: NPARA       ! number of parameters
REAL            , DIMENSION(MAXP, 2              )  , INTENT(IN)    :: prange      ! Allowed parameter range
REAL            , DIMENSION(MAXP )                  , INTENT(IN)    :: p_shift   ! Parameter shift for deriv
INTEGER         , DIMENSION(MAXP )                  , INTENT(IN)    :: p_nderiv  ! Number of derivative points needed
INTEGER                                             , INTENT(IN)    :: kupl_last   ! Last KUPLOT DATA that are needed
REAL            , DIMENSION(MAXP)                   , INTENT(INOUT) :: a           ! Parameter values
CHARACTER(LEN=*), DIMENSION(MAXP)                   , INTENT(IN)    :: par_names   ! Parameter names
REAL            , DIMENSION(NPARA, NPARA)           , INTENT(OUT)   :: covar       ! Covariance matrix
REAL            , DIMENSION(NPARA, NPARA)           , INTENT(INOUT) :: alpha       ! Temp arrays
REAL            , DIMENSION(NPARA     )             , INTENT(INOUT) :: beta        ! Temp arrays
REAL                                                , INTENT(INOUT) :: chisq       ! Chi Squared
REAL                                                , INTENT(INOUT) :: alamda      ! Levenberg parameter
REAL                                                , INTENT(IN)    :: lamda_s    ! Start value for lamda
REAL                                                , INTENT(IN)    :: lamda_d    ! Multiplier_down
REAL                                                , INTENT(IN)    :: lamda_u    ! Multiplier_up
LOGICAL                                             , INTENT(OUT)   :: lsuccess   ! True if improved
REAL            , DIMENSION(MAXP)                   , INTENT(OUT)   :: dp          ! Parameter sigmas
!
INTEGER                         :: j     = 0
INTEGER                         :: k     = 0
REAL   , DIMENSION(MAXP)        :: atry != 0.0
REAL   , DIMENSION(NPARA)       :: da != 0.0
REAL   , DIMENSION(NPARA,NPARA) :: cl != 0.0
REAL                            :: ochisq = 0.0
LOGICAL, PARAMETER              :: LDERIV = .TRUE.
LOGICAL, PARAMETER              :: NDERIV = .FALSE.
!integer, save :: icyy = 0
!
ochisq = chisq
IF(alamda < 0) THEN                   ! Initialization
   alamda = lamda_s
   CALL mrqcof(MAXP, data_dim, data_data, data_sigma, data_x, data_y, a, &
               NPARA, par_names, prange, p_shift, p_nderiv, kupl_last, alpha, beta, &
               chisq, LDERIV) !, funcs)
   IF(ier_num/=0) THEN
      RETURN
   ENDIF
   ochisq = chisq
   DO j=1, NPARA
      IF(prange(j,1)<=prange(j,2)) THEN
         atry(j) = MIN(prange(j,2),MAX(prange(j,1),a(j)))
      ELSE
         atry(j) = a(j)
      ENDIF
   ENDDO
ENDIF
!
DO j=1, NPARA
   DO k=1, NPARA
      covar(j,k) = alpha(j,k)
   ENDDO
   covar(j,j) = alpha(j,j)*(1.0+alamda)       ! Adjust by Levenberg-Marquard algorithm
   da(j) = beta(j)
ENDDO
!
CALL gausj(NPARA, covar, da)
IF(ier_num/=0) THEN
   RETURN
ENDIF
!
cl(:,:) = covar(:,:)       ! Back up of covariance
DO j=1,npara
  dp(j) = SQRT(ABS(cl(j,j)))
ENDDO
IF(alamda==0) THEN
!
!  Last call to update the structure, no derivative is needed
!
   CALL mrqcof(MAXP, data_dim, data_data, data_sigma, data_x, data_y, a, &
               NPARA, par_names, prange, p_shift, p_nderiv, kupl_last, covar, da, chisq, NDERIV) !, funcs)
   IF(ier_num/=0) THEN
      RETURN
   ENDIF
   covar(:,:) = cl(:,:)       ! Restore    covariance
   RETURN
ENDIF
!
!open(78,file='shift.dat', status='unknown', position='append')
!if(icyy==0) write(78, '(15a)') 'cyc', (par_names(j),j=1,npara)
!icyy = icyy+1
!write(78,'(i3,14g15.6e3)') icyy,da(1:npara)
!close(78)
CALL refine_constrain_fwhm_in(MAXP, NPARA, a, da, ier_num, ier_typ)
IF(ier_num/=0) THEN
   RETURN
ENDIF
DO j=1,NPARA
   IF(prange(j,1)<=prange(j,2)) THEN
      atry(j) = MIN(prange(j,2),MAX(prange(j,1),a(j)+da(j)))
   ELSE
      atry(     (j)) = a(     (j)) + da(j)
   ENDIF
ENDDO
!
CALL mrqcof(MAXP, data_dim, data_data, data_sigma, data_x, data_y, atry, &
            NPARA, par_names, prange, p_shift, p_nderiv, kupl_last, covar, da, chisq, LDERIV) !, funcs)
IF(ier_num/=0) THEN
   RETURN
ENDIF
!
!do j=1, npara
!write(*,'(a5,3(f20.8,2x))') 'ond ', a(j), atry(j), -(a(j)-atry(j))
!enddo
!
!write(*,*) ' PAR ', params(1:npara)
!write(*,*) ' dP  ', da    (1:npara)
!write(*,*) 'c, d, u', alamda, lamda_d, lamda_u
IF(chisq < ochisq) THEN            ! Success, accept solution
   alamda = lamda_d*alamda         ! Decrease alamda by facror lamda_u (down)
   ochisq = chisq
   DO j=1,NPARA
      DO k=1,NPARA
         alpha(j,k) = covar(j,k)
      ENDDO
      beta(j) = da(j)
      a(     (j)) = atry(     (j))
   ENDDO
   lsuccess = .TRUE.
ELSE                               ! Failure, reject, keep old params and 
   alamda =  lamda_u*alamda        ! increment alamda by factor lamda_u (up)
   chisq = ochisq                  ! Keep old chis squared
   lsuccess = .FALSE.
ENDIF
!
!covar(:,:) = cl(:,:)       ! Restore    covariance
!
END SUBROUTINE mrqmin
!
!*******************************************************************************
!
SUBROUTINE mrqcof(MAXP, data_dim, data_data, data_sigma, data_x, data_y, &
                  params, NPARA, par_names, prange, p_shift, p_nderiv, kupl_last,  &
                  alpha, beta, chisq, LDERIV)
!
! Modified after NumRec 14.4
! Version for 2-d data
!
USE errlist_mod
!
IMPLICIT NONE
!
INTEGER                                             , INTENT(IN)  :: MAXP        ! Maximum parameter number
INTEGER         , DIMENSION(2)                      , INTENT(IN)  :: data_dim    ! Data dimensions
REAL            , DIMENSION(data_dim(1),data_dim(2)), INTENT(IN)  :: data_data   ! Observables
REAL            , DIMENSION(data_dim(1),data_dim(2)), INTENT(IN)  :: data_sigma ! Observables
REAL            , DIMENSION(data_dim(1)           ) , INTENT(IN)  :: data_x      ! x-coordinates
REAL            , DIMENSION(data_dim(2)           ) , INTENT(IN)  :: data_y      ! y-coordinates
INTEGER                                             , INTENT(IN)  :: NPARA       ! Number of refine parameters
REAL            , DIMENSION(MAXP)                   , INTENT(IN)  :: params      ! Current parameter values
CHARACTER(LEN=*), DIMENSION(MAXP)                   , INTENT(IN)  :: par_names   ! Parameter names
REAL            , DIMENSION(MAXP, 2              )  , INTENT(IN)  :: prange      ! Allowed parameter range
REAL            , DIMENSION(MAXP )                  , INTENT(IN)  :: p_shift   ! Parameter shift for deriv
INTEGER         , DIMENSION(MAXP )                  , INTENT(IN)  :: p_nderiv  ! Number of derivative points needed
INTEGER                                             , INTENT(IN)  :: kupl_last   ! Last KUPLOT DATA that are needed
REAL            , DIMENSION(NPARA, NPARA)           , INTENT(OUT) :: alpha
REAL            , DIMENSION(NPARA)                  , INTENT(OUT) :: beta
REAL                                                , INTENT(OUT) :: chisq
LOGICAL                                             , INTENT(IN)  :: LDERIV      ! Derivatives are needed?
!
!
INTEGER                  :: j
INTEGER                  :: k
INTEGER                  :: ix, iy
!
REAL                     :: xx    = 0.0     ! current x-coordinate
REAL                     :: yy    = 0.0     ! current y-coordinate
REAL                     :: ymod  = 0.0     ! zobs(calc)
REAL, DIMENSION(1:NPARA) :: dyda            ! Derivatives
REAL                     :: sig2i = 0.0     ! sigma squared
REAL                     :: dy    = 0.0     ! Difference zobs(obs) - zobs(calc)
REAL                     :: wt    = 0.0     ! Weight 
!
alpha(:,:) = 0.0
beta(:)    = 0.0
chisq      = 0.0
!
loopix: do ix=1, data_dim(1)
   xx = data_x(ix)
   loopiy: do iy=1, data_dim(2)
      yy = data_y(iy)
!
      CALL refine_theory(MAXP, ix, iy, xx, yy, NPARA, params, par_names,   &
                         prange, p_shift, p_nderiv, &
                         data_dim, & ! data_data, data_sigma, data_x, data_y, &
                         kupl_last, &
                         ymod, dyda, LDERIV)
      IF(ier_num/=0) THEN
         RETURN
      ENDIF
!
      sig2i =1./(data_sigma(ix,iy)*data_sigma(ix,iy))
      dy = data_data(ix,iy) - ymod
      DO j=1, NPARA
         wt = dyda(j)*sig2i
         DO k=1, j
            alpha(j,k) = alpha(j,k) + wt*dyda(k)
         ENDDO
         beta(j) = beta(j) + dy*wt
      ENDDO
      chisq = chisq + dy*dy*sig2i
!
   ENDDO loopiy
ENDDO loopix
!
DO j=2, NPARA                   ! Fill in upper diagonal
   DO k=1,j-1
      alpha(k,j) = alpha(j,k)
   ENDDO
ENDDO
!
END SUBROUTINE mrqcof
!
!*******************************************************************************
!
SUBROUTINE refine_rvalue(rval, rexp, npar)
!
USE refine_data_mod
!
IMPLICIT NONE
!
REAL   , INTENT(OUT) :: rval
REAL   , INTENT(OUT) :: rexp
INTEGER, INTENT(IN)  :: npar
INTEGER :: iix, iiy
REAL    :: sumz
REAL    :: sumn
REAL    :: wght
!
sumz = 0.0
sumn = 0.0
!
DO iiy = 1, ref_dim(2)
   DO iix = 1, ref_dim(1)
      IF(ref_sigma(iix,iiy)/=0.0) THEN
         wght = 1./(ref_sigma(iix,iiy))**2
      ELSE
         wght = 1.0
      ENDIF
      sumz = sumz + wght*(ref_data(iix,iiy)-refine_calc(iix,iiy))**2
      sumn = sumn + wght*(ref_data(iix,iiy)                     )**2
   ENDDO
ENDDO
IF(sumn/=0.0) THEN
   rval = SQRT(sumz/sumn)
   rexp = SQRT((ref_dim(1)*ref_dim(2)-npar)/sumn)
ELSE
   rval = -1.0
   rexp = -1.0
ENDIF
!
END SUBROUTINE refine_rvalue
!
!*******************************************************************************
!
SUBROUTINE refine_best(rval)
!
USE refine_params_mod
USE refine_data_mod
!
USE ber_params_mod
USE precision_mod
!
IMPLICIT NONE
!
REAL, INTENT(IN) :: rval   ! Current R-value
!
INTEGER, PARAMETER :: IWR=11
!
CHARACTER(LEN=15), PARAMETER :: ofile='refine_best.mac'
INTEGER             :: i
!
INTEGER :: MAXW
INTEGER :: ianz
REAL    :: step
!
CHARACTER(LEN=1024), DIMENSION(:), ALLOCATABLE :: cpara
INTEGER            , DIMENSION(:), ALLOCATABLE :: lpara
REAL(KIND=PREC_DP) , DIMENSION(:), ALLOCATABLE :: werte
!
OPEN(UNIT=IWR, FILE=ofile, STATUS='unknown')
WRITE(IWR, '(a)') '#@ HEADER'
WRITE(IWR, '(a)') '#@ NAME         refine_best.mac'
WRITE(IWR, '(a)') '#@ '
WRITE(IWR, '(a)') '#@ KEYWORD      refine, best fit'
WRITE(IWR, '(a)') '#@ '
WRITE(IWR, '(a)') '#@ DESCRIPTION  This macro contains the parameters for the current best'
WRITE(IWR, '(a)') '#@ DESCRIPTION  fit status.'
WRITE(IWR, '(a)') '#@ DESCRIPTION  '
WRITE(IWR, '(a)') '#@'
WRITE(IWR, '(a)') '#@ PARAMETER    $0, 0'
WRITE(IWR, '(a)') '#@'
WRITE(IWR, '(a)') '#@ USAGE        @refine_best.mac'
WRITE(IWR, '(a)') '#@'
WRITE(IWR, '(a)') '#@ END'
WRITE(IWR, '(a)') '#'
!
IF(ref_LOAD/= ' ') THEN           ! Data set was loaded 
   WRITE(IWR, '(a)') 'kuplot'
   WRITE(IWR, '(a)') 'rese'
   WRITE(IWR, '(a,a)') 'load ',ref_load(1:LEN_TRIM(ref_load))
   WRITE(IWR, '(a)') 'exit'
   WRITE(IWR, '(a)') '#'
ENDIF
!
IF(ref_csigma/= ' ') THEN           ! sigma set was loaded 
   WRITE(IWR, '(a)') 'kuplot'
   WRITE(IWR, '(a)') 'rese'
   WRITE(IWR, '(a,a)') 'load ',ref_csigma(1:LEN_TRIM(ref_csigma))
   WRITE(IWR, '(a)') 'exit'
   WRITE(IWR, '(a)') '#'
ENDIF
WRITE(IWR, '(a)') 'refine'
WRITE(IWR, '(a)') '#'
!
WRITE(IWR,'(a)') 'variable real, Rvalue'
!
WRITE(IWR,'(a)') 'variable integer, F_DATA'
WRITE(IWR,'(a)') 'variable real, F_XMIN'
WRITE(IWR,'(a)') 'variable real, F_XMAX'
WRITE(IWR,'(a)') 'variable real, F_YMIN'
WRITE(IWR,'(a)') 'variable real, F_YMAX'
WRITE(IWR,'(a)') 'variable real, F_XSTP'
WRITE(IWR,'(a)') 'variable real, F_YSTP'
DO i=1, refine_fix_n            ! Make sure each fixed parameter is defined as a variable
   WRITE(IWR,'(a,a)') 'variable real, ',refine_fixed(i)
ENDDO
DO i=1, refine_par_n            ! Make sure each parameter is defined as a variable
   WRITE(IWR,'(a,a)') 'variable real, ',refine_params(i)
ENDDO
WRITE(IWR,'(a,G20.8E3)') 'Rvalue           = ', rval
WRITE(IWR,'(a,I15    )') 'F_DATA           = ', ref_kupl
WRITE(IWR,'(a,G20.8E3)') 'F_XMIN           = ', ref_x(1)
WRITE(IWR,'(a,G20.8E3)') 'F_XMAX           = ', ref_x(ref_dim(1))
WRITE(IWR,'(a,G20.8E3)') 'F_YMIN           = ', ref_y(1)
WRITE(IWR,'(a,G20.8E3)') 'F_YMAX           = ', ref_y(ref_dim(2))
step = (ref_x(ref_dim(1))-ref_x(1))/FLOAT(MAX(1,ref_dim(1)-1))
WRITE(IWR,'(a,G20.8E3)') 'F_XSTP           = ', step
step = (ref_y(ref_dim(2))-ref_y(1))/FLOAT(MAX(1,ref_dim(2)-1))
WRITE(IWR,'(a,G20.8E3)') 'F_YSTP           = ', step
!
! Set fixed parameter values
!
MAXW = refine_fix_n
ALLOCATE(cpara(MAXW))
ALLOCATE(lpara(MAXW))
ALLOCATE(werte(MAXW))
DO i = 1, refine_fix_n                  ! Copy parameter names to prepare calculation
   cpara(i) = refine_fixed(i)
   lpara(i) = LEN_TRIM(refine_fixed(i))
ENDDO
ianz = refine_fix_n
CALL ber_params(ianz, cpara, lpara, werte, MAXW)
DO i=1, refine_fix_n            ! Make sure each parameter is defined as a variable
   WRITE(IWR,'(a,a,G20.8E3)') refine_fixed(i), ' = ', werte(i)
ENDDO
!
! Write refined values
!
DO i=1, refine_par_n            ! Write values for all refined parametersWrite values for all refined parameters
   WRITE(IWR,'(a,a,G20.8E3,a, G20.8E3)') refine_params(i), ' = ', refine_p(i) , ' ! +- ', refine_dp(i)
ENDDO
!
WRITE(IWR, '(a)') '#'
WRITE(IWR, '(a,a)') '@',refine_mac(1:LEN_TRIM(refine_mac))
WRITE(IWR, '(a)') '#'
WRITE(IWR, '(a)') 'exit'
!
CLOSE(UNIT=IWR)
!
DEALLOCATE(cpara)
DEALLOCATE(lpara)
DEALLOCATE(werte)
!
END SUBROUTINE refine_best
!
!*******************************************************************************
!
END MODULE refine_run_mod
