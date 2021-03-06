!###############################################################
!     PROGRAM  : BATH
!     TYPE     : Module
!     PURPOSE  : Constructs some functions used in other places. 
!     AUTHORS  : Adriano Amaricci
!     LAST UPDATE: 07/2009
!###############################################################
module BATH
  USE VARS_GLOBAL
  implicit none
  private
  integer,parameter                :: Lw=2048 !# of frequencies
  real(8),allocatable,dimension(:) :: bath_dens,wfreq
  public                           :: get_thermostat_bath

contains
  !+-------------------------------------------------------------------+
  !PURPOSE  : Build the Bath part of the system using exclusively time
  !dependent formalism. The bath is not interacting so it is 
  ! time translation invariant.
  !+-------------------------------------------------------------------+
  subroutine get_thermostat_bath()
    integer          :: iw,i,j
    real(8)          :: en,w,dw,wfin,wini
    complex(8)       :: peso
    real(8)          :: ngtr,nless,arg

    call msg("Get Bath. Type: "//bold_green(trim(adjustl(trim(bath_type))))//" dissipative bath",id=0)
    call create_data_dir("Bath")
    allocate(bath_dens(Lw),wfreq(Lw))

    select case(trim(adjustl(trim(bath_type))))
    case("bethe")
       wfin  = 2.d0*Wbath ; wini=-wfin
       wfreq = linspace(wini,wfin,Lw,mesh=dw)
       call get_bath_bethe_dos()

    case("gaussian")
       wfin = 4.d0*Wbath ; wini=-wfin
       wfreq= linspace(wini,wfin,Lw,mesh=dw)
       call get_bath_gaussian_dos()

    case ("constant")
       wfin  = 2.d0*Wbath ; wini=-wfin
       wfreq = linspace(wini,wfin,Lw,mesh=dw)
       call get_bath_constant_dos()

    case default
       call abort("Bath type:"//trim(adjustl(trim(bath_type)))//" not supported. Accepted values are: constant,gaussian,bethe.")

    end select


    S0=zero
    do iw=1,Lw
       en   = wfreq(iw)
       nless= fermi0(en,beta)
       ngtr = fermi0(en,beta)-1.d0 !it absorbs the minus sign of the greater functions
       do i=0,nstep
          do j=0,nstep
             peso=exp(-xi*(t(i)-t(j))*en)
             S0%less(i,j)=S0%less(i,j)+ xi*Vpd**2*nless*peso*bath_dens(iw)*dw
             S0%gtr(i,j) =S0%gtr(i,j) + xi*Vpd**2*ngtr*peso*bath_dens(iw)*dw
          enddo
       enddo
    enddo

    if(mpiID==0)then
       call write_keldysh_contour_gf(S0,"Bath/S0")
       call splot("Bath/DOSbath.lattice",wfreq,bath_dens)
       if(plot3D)call plot_keldysh_contour_gf(S0,t(0:),"PLOT/S0")
    endif

  end subroutine get_thermostat_bath



  !********************************************************************
  !********************************************************************
  !********************************************************************



  !+-----------------------------------------------------------------+
  !PURPOSE  : Build constant BATH 
  !+-----------------------------------------------------------------+
  subroutine get_bath_constant_dos()
    integer    :: i
    real(8)    :: w

    do i=1,Lw
       w=wfreq(i)
       bath_dens(i)= heaviside(Wbath-abs(w))/(2.d0*Wbath)
    enddo

  end subroutine get_bath_constant_dos



  !********************************************************************
  !********************************************************************
  !********************************************************************





  !+-----------------------------------------------------------------+
  !PURPOSE  : Build BATH dispersion arrays \epsilon_bath(\ka) = bath_epski(i)
  !+-----------------------------------------------------------------+
  subroutine get_bath_gaussian_dos()
    integer    :: i,ik
    real(8)    :: w,sig,alpha
    complex(8) :: gf,zeta

    bath_dens = exp(-0.5d0*(wfreq/Wbath)**2)/(sqrt(pi2)*Wbath) !standard Gaussian
    !bath_dens = exp(-((wfreq+xmu)/Wbath)**2)/(sqrt(pi)*Wbath) !Camille's choice

    !    !!w/ erf in frquency space: coded from Abramowitz-Stegun
    ! do i=-Lw,Lw
    !    !w=wfreq(i)
    !    !zeta=cmplx(w+xmu,eps,8)
    !    !sig=aimag(zeta)/abs(dimag(zeta))
    !    !gf=-sig*xi*sqrt(pi)*wfun(zeta/Wbath)/Wbath
    !    !bath_dens(i)=-aimag(gf)/pi
    ! enddo
  end subroutine get_bath_gaussian_dos




  !********************************************************************
  !********************************************************************
  !********************************************************************




  !+-----------------------------------------------------------------+
  !PURPOSE  : Build BATH dispersion arrays \epsilon_bath(\ka) = bath_epski(i)
  !+-----------------------------------------------------------------+
  subroutine get_bath_bethe_dos()
    integer    :: i,ik
    real(8)    :: w,sig,alpha
    complex(8) :: gf,zeta

    do i=1,Lw
       w=wfreq(i)+xmu
       zeta=cmplx(w,eps,8)
       gf=gfbether(w,zeta,wbath/2.d0)
       bath_dens(i)=-aimag(gf)/pi
    enddo

  end subroutine get_bath_bethe_dos
  !********************************************************************
  !********************************************************************
  !********************************************************************









  ! !+-------------------------------------------------------------------+
  ! !PURPOSE  : Build the Bath part of the system using frequency domain
  ! !formalism. 
  ! !COMMENT  : Construct the Bath-Sigma functions from freq. domain
  ! !(that is 'cause you know the analytic expression, same
  ! !procedure as in IPTkeldysh @equilibrium)
  ! !This turns out to be the same provided one takes 
  ! !the limit \eta\goto 0.d0
  ! !+-------------------------------------------------------------------+
  ! subroutine get_Bath_w
  !   integer :: i,im
  !   real(8) :: A,An,w
  !   complex(8) :: iw,fg
  !   complex(8),dimension(-nstep:nstep) :: gb0fless,gb0fgtr
  !   complex(8),dimension(-nstep:nstep) :: gb0tgtr,gb0tless
  !   print '(A)',"Get Bath:"

  !   do i=-nstep,nstep
  !      w = wr(i) ;iw= cmplx(w,eps,8)
  !      fg=zero
  !      do im=0,Lmu
  !         fg=fg + de*bath_dens(im)/(iw-bath_epsik(im))!/dble(Lmu)
  !      enddo
  !      A = -aimag(fg)/pi
  !      An= A*fermi0(w,beta)
  !      gb0fless(i)= pi2*xi*An
  !      gb0fgtr(i) = pi2*xi*(An-A)
  !   enddo
  !   call fftgf_rw2rt(gb0fless,gb0tless,nstep)  ; gb0tless=fmesh/pi2*gb0tless
  !   call fftgf_rw2rt(gb0fgtr, gb0tgtr,nstep)   ; gb0tgtr =fmesh/pi2*gb0tgtr
  !   gb0tgtr =exa*gb0tgtr
  !   gb0tless=exa*gb0tless
  !   !Get the Self-energy contribution of the bath:
  !   !=================================================
  !   S0gtr=zero
  !   S0less=zero
  !   S0less=Vpd**2*gb0tless
  !   S0gtr =Vpd**2*gb0tgtr
  !   call system("mkdir BATH")   
  !   call splot("BATH/bathG0less_t.ipt",t(-nstep:nstep),gb0tless)
  !   call splot("BATH/bathG0gtr_t.ipt",t(-nstep:nstep),gb0tgtr)
  !   call splot("BATH/S0less_t.ipt",t(-nstep:nstep),S0less)
  !   call splot("BATH/S0gtr_t.ipt",t(-nstep:nstep),S0gtr)
  !   print '(A)',"" 
  !   return
  ! end subroutine Get_Bath_w



  !********************************************************************
  !********************************************************************
  !********************************************************************




end module BATH

