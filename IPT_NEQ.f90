!###############################################################
!     PURPOSE  : A non-equilibrium IPT solver module. 
!     AUTHORS  : Adriano Amaricci
!###############################################################
module IPT_NEQ
  USE VARS_GLOBAL
  implicit none
  private

  public  :: neq_init_run
  public  :: neq_solve_ipt



contains

  !+-------------------------------------------------------------------+
  !PURPOSE  : Initialize the run guessing/reading self-energy
  !+-------------------------------------------------------------------+
  subroutine neq_init_run()
    logical :: init

    init = inquire_kbm_contour_gf(trim(irdFILE))
    if(init)then
       call msg(bold("Reading components of the input Self-energy"))
       call read_kbm_contour_gf(Sigma,trim(irdFILE))
    else
       call msg(bold("Start from the Hartree-Fock self-energy"))
       Sigma=zero
    endif
  end subroutine neq_init_run




  !+-------------------------------------------------------------------+
  !PURPOSE  : BUild the 2^nd IPT sigma functions:
  !comments : !reintroducing wrong sign here, check vs. KADANOFFBAYM.f90/GFstep
  !+-------------------------------------------------------------------+
  subroutine neq_solve_ipt()
    integer      :: i,j,itau
    real(8),dimension(0:nstep)            :: nt             !occupation(time)
    real(8),dimension(0:Ltau) :: eqG0tau,eqStau
    call msg("Get Sigma(t,t')")

    forall(i=0:Ltau)eq_Stau(i)=(U**2)*(eq_G0tau(i)**2)*eq_G0tau(Ltau-i)
    forall(i=1:Ltau)eq_Stau(-i)=-eq_Stau(Ltau-i)
    call fftgf_tau2iw(eq_Stau(0:),eq_Siw,beta)                   !Get S(iw) from S(tau)

    forall(i=0:Ltau,j=0:Ltau)Sigma%mats(i,j)=eq_Stau(i-j)        !get Sigma^M(tau,tau`)

    forall(i=0:nstep,j=0:nstep)
       Sigma%less(i,j) = (U**2)*(G0%less(i,j)**2)*G0%gtr(j,i)    !get Sigma^<(t,t`)
       Sigma%gtr (i,j) = (U**2)*(G0%gtr(i,j)**2)*G0%less(j,i)    !get Sigma^>(t,t`)
    end forall

    forall(i=0:nstep,itau=0:Ltau)&
         Sigma%lmix(i,itau)=(U**2)*(G0%lmix(i,itau)**2)*G0%gmix(itau,i) !get Sigma^\lmix(t,tau`)
    forall(j=0:Ltau)Sigma%gmix(j,:)=conjg(Sigma%lmix(:,Ltau-j))    !get Sigma^\gmix(tau,t`)

    !Save data:
    if(mpiID==0)then
       call write_kbm_contour_gf(Sigma,trim(data_dir)//"/Sigma")
       if(plot3D)call plot_kbm_contour_gf(Sigma,t(0:),tau(0:),trim(plot_dir)//"/Sigma")
       call splot("eq_Sigma_tau.ipt",tau,eq_Stau,append=.true.)
       call splot("eq_Sigma_iw.ipt",wm,eq_Siw,append=.true.)
       call splot("Sigma_less_t0.ipt",t(0:),Sigma%less(0:,0))
       call splot("Sigma_lmix_tau0.ipt",t(0:),Sigma%lmix(0:,0))
       call splot("Sigma_lmix_t0_tau.ipt",tau(0:),Sigma%lmix(0,0:))
       forall(i=0:nstep)nt(i)=-xi*Sigma%less(i,i)
       call splot("nsVStime.ipt",t(0:),nt(0:),append=TT)
    endif

  end subroutine neq_solve_ipt



  !********************************************************************
  !********************************************************************
  !********************************************************************






end module IPT_NEQ
