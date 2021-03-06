! (C) Copyright 2018-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module fv3jedi_linvarcha_c2a_mod

! fckit
use fckit_configuration_module, only: fckit_configuration

! fv3jedi
use fv3jedi_fieldfail_mod, only: field_fail
use fv3jedi_field_mod,     only: copy_subset, field_clen
use fv3jedi_geom_mod,      only: fv3jedi_geom
use fv3jedi_increment_mod, only: fv3jedi_increment
use fv3jedi_kinds_mod,     only: kind_real
use fv3jedi_state_mod,     only: fv3jedi_state

use pressure_vt_mod
use temperature_vt_mod
use moisture_vt_mod
use wind_vt_mod

implicit none
private

public :: fv3jedi_linvarcha_c2a
public :: create
public :: delete
public :: multiply
public :: multiplyadjoint
public :: multiplyinverse
public :: multiplyinverseadjoint

!> Fortran derived type to hold configuration data for the B mat variable change
type :: fv3jedi_linvarcha_c2a
 real(kind=kind_real), allocatable :: ttraj(:,:,:)
 real(kind=kind_real), allocatable :: tvtraj(:,:,:)
 real(kind=kind_real), allocatable :: qtraj(:,:,:)
 real(kind=kind_real), allocatable :: qsattraj(:,:,:)
end type fv3jedi_linvarcha_c2a

! --------------------------------------------------------------------------------------------------

contains

! --------------------------------------------------------------------------------------------------

subroutine create(self, geom, bg, fg, conf)

implicit none
type(fv3jedi_linvarcha_c2a), intent(inout) :: self
type(fv3jedi_geom), target,  intent(in)    :: geom
type(fv3jedi_state), target, intent(in)    :: bg
type(fv3jedi_state), target, intent(in)    :: fg
type(fckit_configuration),   intent(in)    :: conf

real(kind=kind_real), pointer :: t   (:,:,:)
real(kind=kind_real), pointer :: q   (:,:,:)
real(kind=kind_real), pointer :: delp(:,:,:)

!> Pointers to the background state
call bg%get_field('t'   , t)
call bg%get_field('sphum'   , q)
call bg%get_field('delp', delp)

!> Virtual temperature trajectory
allocate(self%tvtraj   (geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz))
call T_to_Tv(geom,t,q,self%tvtraj)

!> Temperature trajectory
allocate(self%ttraj   (geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz))
self%ttraj = t

!> Specific humidity trajecotory
allocate(self%qtraj   (geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz))
self%qtraj = q

!> Compute saturation specific humidity for q to RH transform
allocate(self%qsattraj(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz))

!> Compute saturation specific humidity
call get_qsat(geom,delp,t,q,self%qsattraj)

end subroutine create

! --------------------------------------------------------------------------------------------------

subroutine delete(self)

implicit none
type(fv3jedi_linvarcha_c2a), intent(inout) :: self

if (allocated(self%tvtraj)) deallocate(self%tvtraj)
if (allocated(self%ttraj)) deallocate(self%ttraj)
if (allocated(self%qtraj)) deallocate(self%qtraj)
if (allocated(self%qsattraj)) deallocate(self%qsattraj)

end subroutine delete

! --------------------------------------------------------------------------------------------------

subroutine multiply(self, geom, dxc, dxa)

implicit none
type(fv3jedi_linvarcha_c2a), intent(in)    :: self
type(fv3jedi_geom),          intent(inout) :: geom
type(fv3jedi_increment),     intent(in)    :: dxc
type(fv3jedi_increment),     intent(inout) :: dxa

integer :: f
character(len=field_clen), allocatable :: fields_to_do(:)
real(kind=kind_real), pointer :: field_ptr(:,:,:)

! Winds
logical :: have_uava
real(kind=kind_real), pointer,     dimension(:,:,:) :: psip
real(kind=kind_real), pointer,     dimension(:,:,:) :: chip
real(kind=kind_real), allocatable, dimension(:,:,:) :: psi
real(kind=kind_real), allocatable, dimension(:,:,:) :: chi
real(kind=kind_real), allocatable, dimension(:,:,:) :: ua
real(kind=kind_real), allocatable, dimension(:,:,:) :: va

! Specific humidity
logical :: have_q
real(kind=kind_real), pointer,     dimension(:,:,:) :: rh
real(kind=kind_real), allocatable, dimension(:,:,:) :: q

! Temperature
logical :: have_t
real(kind=kind_real), pointer,     dimension(:,:,:) :: tv
real(kind=kind_real), allocatable, dimension(:,:,:) :: t

! Identity part of the change of fields
! -------------------------------------
call copy_subset(dxc%fields, dxa%fields, fields_to_do)

! If variable change is the identity early exit
! ---------------------------------------------
if (.not.allocated(fields_to_do)) return

! Winds
! -----
have_uava = .false.
if (dxc%has_field('psi') .and. dxc%has_field('chi')) then
  call dxc%get_field('psi', psip)
  call dxc%get_field('chi', chip)
  allocate(psi(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
  allocate(chi(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
  psi = 0.0_kind_real
  chi = 0.0_kind_real
  psi(geom%isc:geom%iec,geom%jsc:geom%jec,:) = psip(geom%isc:geom%iec,geom%jsc:geom%jec,:)
  chi(geom%isc:geom%iec,geom%jsc:geom%jec,:) = chip(geom%isc:geom%iec,geom%jsc:geom%jec,:)
  allocate(ua(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  allocate(va(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  call psichi_to_uava(geom, psi, chi, ua, va)
  have_uava = .true.
endif

! Specific humidity
!------------------
have_q = .false.
if (dxc%has_field('rh')) then
  call dxc%get_field('rh', rh)
  allocate(q(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  call rh_to_q_tl(geom, self%qsattraj, rh, q)
  have_q = .true.
endif

! Temperature
! -----------
have_t = .false.
if (dxc%has_field('t')) then
  call dxc%get_field('t', t)
  have_t = .true.
elseif (dxc%has_field('tv') .and. have_q) then
  call dxc%get_field('tv', tv)
  allocate(t(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  call Tv_to_T_tl(geom, self%tvtraj, tv, self%qtraj, q, t)
  have_t = .true.
endif


! Loop over the fields not found in the input state and work through cases
! ------------------------------------------------------------------------
do f = 1, size(fields_to_do)

  call dxa%get_field(trim(fields_to_do(f)),  field_ptr)

  select case (trim(fields_to_do(f)))

  case ("ua")

    if (.not. have_uava) call field_fail(fields_to_do(f))
    field_ptr(geom%isc:geom%iec,geom%jsc:geom%jec,:) = ua(geom%isc:geom%iec,geom%jsc:geom%jec,:)

  case ("va")

    if (.not. have_uava) call field_fail(fields_to_do(f))
    field_ptr(geom%isc:geom%iec,geom%jsc:geom%jec,:) = va(geom%isc:geom%iec,geom%jsc:geom%jec,:)

  case ("t")

    if (.not. have_t) call field_fail(fields_to_do(f))
    field_ptr = t

  case ("sphum")

    if (.not. have_q) call field_fail(fields_to_do(f))
    field_ptr = q

  case default

    call abor1_ftn("fv3jedi_lvc_model2geovals_mod.multiply unknown field: "//trim(fields_to_do(f)) &
                   //". Not in input field and no transform case specified.")

  end select

enddo

! Copy calendar infomation
! ------------------------
dxa%calendar_type = dxc%calendar_type
dxa%date_init = dxc%date_init

end subroutine multiply

! --------------------------------------------------------------------------------------------------

subroutine multiplyadjoint(self,geom,dxa,dxc)

implicit none
type(fv3jedi_linvarcha_c2a), intent(in)    :: self
type(fv3jedi_geom),          intent(inout) :: geom
type(fv3jedi_increment),     intent(inout) :: dxa
type(fv3jedi_increment),     intent(inout) :: dxc

integer :: f
character(len=field_clen), allocatable :: fields_to_do(:)
real(kind=kind_real), pointer :: field_ptr(:,:,:)

! Winds
logical :: have_psichi
real(kind=kind_real), pointer,     dimension(:,:,:) :: ua
real(kind=kind_real), pointer,     dimension(:,:,:) :: va
real(kind=kind_real), allocatable, dimension(:,:,:) :: psi
real(kind=kind_real), allocatable, dimension(:,:,:) :: chi

! Relative humidity
logical :: have_rh
real(kind=kind_real), pointer,     dimension(:,:,:) :: q
real(kind=kind_real), allocatable, dimension(:,:,:) :: rh

! Virtual temperature
logical :: have_tv
real(kind=kind_real), pointer,     dimension(:,:,:) :: t
real(kind=kind_real), allocatable, dimension(:,:,:) :: tv

! Zero output
! -----------
call dxc%zero()

! Identity part of the change of fields
! -------------------------------------
call copy_subset(dxa%fields, dxc%fields, fields_to_do)

! If variable change is the identity early exit
! ---------------------------------------------
if (.not.allocated(fields_to_do)) return

! Virtual temperature
! -------------------
have_tv = .false.
if (dxa%has_field('t') .and. dxa%has_field('sphum')) then
  call dxa%get_field('t', t)
  call dxa%get_field('sphum', q)
  allocate(tv(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  tv = 0.0_kind_real
  call Tv_to_T_ad(geom, self%tvtraj, tv, self%qtraj, q, t)
  have_tv = .true.
endif

! Relative humidity
!------------------
have_rh = .false.
if (dxa%has_field('sphum')) then
  call dxa%get_field('sphum', q)
  allocate(rh(geom%isc:geom%iec,geom%jsc:geom%jec,geom%npz))
  rh = 0.0_kind_real
  call rh_to_q_ad(geom, self%qsattraj, rh, q)
  have_rh = .true.
endif

! Winds
! -----
have_psichi = .false.
if (dxa%has_field('ua') .and. dxa%has_field('va')) then
  call dxa%get_field('ua', ua)
  call dxa%get_field('va', va)
  allocate(psi(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
  allocate(chi(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
  psi = 0.0_kind_real
  chi = 0.0_kind_real
  call psichi_to_uava_adm(geom, psi, chi, ua, va)
  have_psichi = .true.
endif

! Loop over the fields not found in the input state and work through cases
! ------------------------------------------------------------------------
do f = 1, size(fields_to_do)

  call dxc%get_field(trim(fields_to_do(f)),  field_ptr)

  select case (trim(fields_to_do(f)))

  case ("psi")

    if (.not. have_psichi) call field_fail(fields_to_do(f))
    field_ptr(geom%isc:geom%iec,geom%jsc:geom%jec,:) = psi(geom%isc:geom%iec,geom%jsc:geom%jec,:)

  case ("chi")

    if (.not. have_psichi) call field_fail(fields_to_do(f))
    field_ptr(geom%isc:geom%iec,geom%jsc:geom%jec,:) = chi(geom%isc:geom%iec,geom%jsc:geom%jec,:)

  case ("tv")

    if (.not. have_tv) call field_fail(fields_to_do(f))
    field_ptr = tv

  case ("rh")

    if (.not. have_rh) call field_fail(fields_to_do(f))
    field_ptr = rh

  case default

    call abor1_ftn("fv3jedi_lvc_model2geovals_mod.multiplyadjoint unknown field: "//trim(fields_to_do(f)) &
                   //". Not in input field and no transform case specified.")

  end select

enddo

! Copy calendar infomation
! ------------------------
dxc%calendar_type = dxa%calendar_type
dxc%date_init = dxa%date_init

end subroutine multiplyadjoint

! --------------------------------------------------------------------------------------------------

subroutine multiplyinverse(self,geom,dxa,dxc)

implicit none
type(fv3jedi_linvarcha_c2a), intent(in)    :: self
type(fv3jedi_geom),          intent(inout) :: geom
type(fv3jedi_increment),     intent(in)    :: dxa
type(fv3jedi_increment),     intent(inout) :: dxc

integer :: f

! Forced identity
! ---------------
do f = 1, size(dxc%fields)
  dxc%fields(f)%array = dxa%fields(f)%array
enddo

! Copy calendar infomation
! ------------------------
dxc%calendar_type = dxa%calendar_type
dxc%date_init = dxa%date_init

end subroutine multiplyinverse

! --------------------------------------------------------------------------------------------------

subroutine multiplyinverseadjoint(self,geom,dxc,dxa)

implicit none
type(fv3jedi_linvarcha_c2a), intent(in)    :: self
type(fv3jedi_geom),          intent(inout) :: geom
type(fv3jedi_increment),     intent(in)    :: dxc
type(fv3jedi_increment),     intent(inout) :: dxa

integer :: f

! Forced identity
! ---------------
do f = 1, size(dxc%fields)
  dxa%fields(f)%array = dxc%fields(f)%array
enddo

! Copy calendar infomation
! ------------------------
dxa%calendar_type = dxc%calendar_type
dxa%date_init = dxc%date_init

end subroutine multiplyinverseadjoint

! --------------------------------------------------------------------------------------------------

subroutine control_to_analysis_tlm(geom,psi, chi, tv, rh, &
                                        ua , va , t , q, &
                                   tvt, qt, qsat)

 implicit none
 type(fv3jedi_geom), intent(inout) :: geom

 !Input: control variables
 real(kind=kind_real), intent(in)    ::  psi(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Stream function
 real(kind=kind_real), intent(in)    ::  chi(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Velocity potential
 real(kind=kind_real), intent(in)    ::   tv(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Virtual temp
 real(kind=kind_real), intent(in)    ::   rh(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity

 !Output: analysis variables
 real(kind=kind_real), intent(inout) ::   ua(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !A-grid winds (ua)
 real(kind=kind_real), intent(inout) ::   va(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !A-grid winds (va)
 real(kind=kind_real), intent(inout) ::    t(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Dry temperature
 real(kind=kind_real), intent(inout) ::    q(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity

 !Trajectory for virtual temperature to temperature
 real(kind=kind_real), intent(in)    ::  tvt(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !VTemperature traj
 real(kind=kind_real), intent(in)    ::   qt(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity traj
 real(kind=kind_real), intent(in)    :: qsat(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Sat spec hum

 real(kind=kind_real), allocatable, dimension(:,:,:) :: psi_dom, chi_dom

 ua = 0.0_kind_real
 va = 0.0_kind_real
 t  = 0.0_kind_real
 q  = 0.0_kind_real

 !psi and chi to A-grid u and v
 !-----------------------------
 allocate(psi_dom(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
 allocate(chi_dom(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
 psi_dom = 0.0_kind_real
 chi_dom = 0.0_kind_real

 psi_dom(geom%isc:geom%iec,geom%jsc:geom%jec,:) = psi
 chi_dom(geom%isc:geom%iec,geom%jsc:geom%jec,:) = chi

 call psichi_to_uava(geom,psi_dom,chi_dom,ua,va)

 deallocate(psi_dom, chi_dom)

 !Relative humidity to specific humidity
 !--------------------------------------
 call rh_to_q_tl(geom,qsat,rh,q)

 !Virtual temperature to temperature
 !----------------------------------
 call Tv_to_T_tl(geom,Tvt,Tv,qt,q,T)

endsubroutine control_to_analysis_tlm

! --------------------------------------------------------------------------------------------------

!> Control variables to state variables - Adjoint

subroutine control_to_analysis_adm(geom,psi, chi, tv, rh, &
                                        ua , va , t , q, &
                                   tvt, qt, qsat)

 implicit none
 type(fv3jedi_geom), intent(inout) :: geom

 !Output: control variables
 real(kind=kind_real), intent(inout) ::  psi(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Stream function
 real(kind=kind_real), intent(inout) ::  chi(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Velocity potential
 real(kind=kind_real), intent(inout) ::   tv(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Virtual temp
 real(kind=kind_real), intent(inout) ::   rh(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity

 !Input: analysis variables
 real(kind=kind_real), intent(inout) ::   ua(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Dgrid winds (u)
 real(kind=kind_real), intent(inout) ::   va(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Dgrid winds (v)
 real(kind=kind_real), intent(inout) ::    t(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Dry temperature
 real(kind=kind_real), intent(inout) ::    q(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity

 !Trajectory for virtual temperature to temperaturc
 real(kind=kind_real), intent(in)    ::  tvt(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !VTemperature traj
 real(kind=kind_real), intent(in)    ::   qt(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Specific humidity traj
 real(kind=kind_real), intent(in)    :: qsat(geom%isc:geom%iec,geom%jsc:geom%jec,1:geom%npz) !Sat spec hum

 real(kind=kind_real), allocatable, dimension(:,:,:) :: psi_dom, chi_dom

 psi = 0.0_kind_real
 chi = 0.0_kind_real
 tv  = 0.0_kind_real
 rh  = 0.0_kind_real

 !Virtual temperature to temperature
 !----------------------------------
 call Tv_to_T_ad(geom,Tvt,Tv,qt,q,T)

 !Relative humidity to specific humidity
 !--------------------------------------
 call rh_to_q_ad(geom,qsat,rh,q)

 !psi and chi to D-grid u and v
 !-----------------------------
 allocate(psi_dom(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
 allocate(chi_dom(geom%isd:geom%ied,geom%jsd:geom%jed,1:geom%npz))
 psi_dom = 0.0_kind_real
 chi_dom = 0.0_kind_real

 call psichi_to_uava_adm(geom,psi_dom,chi_dom,ua,va)

 psi = psi_dom(geom%isc:geom%iec,geom%jsc:geom%jec,:)
 chi = chi_dom(geom%isc:geom%iec,geom%jsc:geom%jec,:)

 deallocate(psi_dom, chi_dom)

endsubroutine control_to_analysis_adm

! --------------------------------------------------------------------------------------------------

end module fv3jedi_linvarcha_c2a_mod
