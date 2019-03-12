    !------------------------------------------------------------------------------
    !        IST/MARETEC, Water Modelling Group, Mohid modelling system
    !------------------------------------------------------------------------------
    !
    ! TITLE         : Mohid Model
    ! PROJECT       : Mohid Lagrangian Tracer
    ! MODULE        : geometry
    ! URL           : http://www.mohid.com
    ! AFFILIATION   : IST/MARETEC, Marine Modelling Group
    ! DATE          : March 2018
    ! REVISION      : Canelas 0.2
    !> @author
    !> Ricardo Birjukovs Canelas
    !
    ! DESCRIPTION:
    !> Module that defines geometry classes and related methods.
    !------------------------------------------------------------------------------

    module geometry_mod

    use vecfor_r8p
    !use vecfor_r4p
    use stringifor
    use simulation_precision_mod
    use simulation_logger_mod
    use simulation_globals_mod
    use utilities_mod

    implicit none
    private

    !Update with any new additions as they are added
    type :: geometry_class
        type(string), allocatable, dimension(:) :: list !< String list with the name of possible geometry types.
    contains
    procedure :: initialize => allocatelist !<Builds the geometry list, possible geometry types (new types must be manually added)
    procedure :: inlist                     !<checks if a given geometry is defined as a derived type (new types must be manually added)
    procedure :: allocateShape              !< Returns allocated Shape with a specific shape given a name
    procedure :: fillsize                   !<Gets the number of points that fill a geometry (based on GLOBALS::dp)
    procedure :: fill                       !<Gets the list of points that fill a geometry (based on GLOBALS::dp)
    procedure :: getCenter                  !<Function that retuns the shape baricenter
    procedure :: getPoints                  !<Function that retuns the points (vertexes) that define the geometrical shape
    procedure :: getnumPoints               !<Function that returns the number of points (vertexes) that define the geometrical shape
    procedure :: print => printGeometry     !<prints the geometry type and contents
    end type geometry_class

    type :: shape                      !<Type - extendable shape class
        type(vector) :: pt              !< Coordinates of a point
    end type

    type, extends(shape) :: point   !<Type - point class
    end type

    type, extends(shape) :: line    !<Type - line class
        type(vector) :: last            !< Coordinates of the end point
    end type

    type, extends(shape) :: sphere  !<Type - sphere class
        real(prec) :: radius            !< Sphere radius (m)
    end type

    type, extends(shape) :: box     !<Type - point class
        type(vector) :: size            !< Box size (m)
    end type

    type(geometry_class) :: Geometry

    public :: shape, point, line, sphere, box
    public :: Geometry

    contains

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> Returns allocated Shape with a specific shape given a name
    !> @param[in] self, name, shape_obj
    !---------------------------------------------------------------------------
    subroutine allocateShape(self, name, shape_obj)
    class(geometry_class), intent(in) :: self
    type(string), intent(in) :: name
    class(shape), allocatable, intent(inout) :: shape_obj
    type(string) :: outext
    select case (name%chars())
    case ('point')
        allocate(point::shape_obj)
    case ('sphere')
        allocate(sphere::shape_obj)
    case ('box')
        allocate(box::shape_obj)
    case ('line')
        allocate(line::shape_obj)
    case default
        outext='[Geometry::allocateShape]: unexpected type for geometry object "'//name//'", stoping'
        call Log%put(outext)
        stop
    end select
    end subroutine allocateShape

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> Public routine to allocate the possible geometry name list
    !---------------------------------------------------------------------------
    subroutine allocatelist(self)
    implicit none
    class(geometry_class), intent(inout) :: self
    allocate(self%list(4))
    self%list(1) ='point'
    self%list(2) ='line'
    self%list(3) ='box'
    self%list(4) ='sphere'
    end subroutine allocatelist

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> Public function that returns a logical if the input geometry name is valid
    !> @param[in] self, geomname
    !---------------------------------------------------------------------------
    logical function inlist(self, geomname) result(tf)
    implicit none
    class(geometry_class), intent(in) :: self
    type(string), intent(in) :: geomname
    integer :: i
    tf = .false.
    do i=1, size(self%list)
        if (geomname == self%list(i)) then
            tf = .true.
        endif
    enddo
    end function inlist

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method to get the number of points that fill a given geometry
    !> @param[in] self, shapetype, dp
    !---------------------------------------------------------------------------
    function fillsize(self, shapetype, dp)
    implicit none
    class(geometry_class), intent(in) :: self
    class(shape), intent(in) :: shapetype
    real(prec), intent(in) :: dp
    integer :: fillsize
    type(vector) :: temp
    type(string) :: outext
    select type (shapetype)
    type is (shape)
    class is (box)
        fillsize = max((int(shapetype%size%x/dp)+1)*(int(shapetype%size%y/dp)+1)*(int(shapetype%size%z/dp)+1),1)
    class is (point)
        fillsize = 1
    class is (line)
        temp = shapetype%pt - shapetype%last
        temp = Utils%geo2m(temp, shapetype%pt%y)
        fillsize = max(int(temp%normL2()/dp),1)
    class is (sphere)
        fillsize = sphere_np_count(dp, shapetype%radius)
        class default
        outext='[geometry::fillsize] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    end function fillsize

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method to get the list of points that fill a given geometry
    !> @param[in] self, shapetype, dp, fillsize, ptlist
    !---------------------------------------------------------------------------
    subroutine fill(self, shapetype, dp, fillsize, ptlist)
    implicit none
    class(geometry_class), intent(in) :: self
    class(shape) :: shapetype
    real(prec), intent(in) :: dp
    integer, intent(in) :: fillsize
    type(vector), intent(out) :: ptlist(fillsize)
    type(vector) :: temp
    type(string) :: outext
    select type (shapetype)
    type is (shape)
    class is (box)
        call box_grid(dp, shapetype%size, fillsize, ptlist)
    class is (point)
        ptlist(1)=0
    class is (line)
        call line_grid(dp, Utils%geo2m(shapetype%last-shapetype%pt, shapetype%pt%y), fillsize, ptlist)
    class is (sphere)
        call sphere_grid(dp, shapetype%radius, fillsize, ptlist)
        class default
        outext='[geometry::fill] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    end subroutine fill

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method to get the baricenter of a given geometry
    !> @param[in] self, shapetype
    !---------------------------------------------------------------------------
    function getCenter(self, shapetype) result(center)
    implicit none
    class(geometry_class), intent(in) :: self
    class(shape), intent(in) :: shapetype
    type(vector) :: center
    type(string) :: outext
    select type (shapetype)
    type is (shape)
    class is (box)
        center = shapetype%pt + Utils%m2geo(shapetype%size, shapetype%pt%y)/2.0
    class is (point)
        center = shapetype%pt
    class is (line)
        center = shapetype%pt + (shapetype%last-shapetype%pt)/2.0
    class is (sphere)
        center = shapetype%pt
        class default
        outext='[geometry::getCenter] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    end function getCenter

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method that returns the points defining a given geometry
    !> @param[in] self, shapetype
    !---------------------------------------------------------------------------
    function getPoints(self, shapetype) result(pts)
    class(geometry_class), intent(in) :: self
    class(shape), intent(in) :: shapetype
    type(vector), allocatable :: pts(:)
    type(string) :: outext
    integer :: n
    type(vector) :: temp
    select type (shapetype)
    type is (shape)
    class is (box)
        n=8
        allocate(pts(n))
        temp = shapetype%size
        pts(1) = shapetype%pt
        pts(2) = shapetype%pt + temp%y*ey
        pts(3) = pts(2) + temp%z*ez
        pts(4) = shapetype%pt + temp%z*ez
        pts(5) = shapetype%pt + temp%x*ex
        pts(6) = pts(5) + temp%y*ey
        pts(7) = shapetype%pt + temp
        pts(8) = pts(5) + temp%z*ez
    class is (point)
        n=1
        allocate(pts(n))
        pts(1) = shapetype%pt
    class is (line)
        n=2
        allocate(pts(n))
        pts(1) = shapetype%pt
        pts(2) = shapetype%last
    class is (sphere)
        n=1
        allocate(pts(n))
        pts(1) = shapetype%pt
        class default
        outext='[geometry::getPoints] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    end function getPoints

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method the points defining a given geometry
    !> @param[in] self, shapetype
    !---------------------------------------------------------------------------
    function getnumPoints(self, shapetype) result(n)
    class(geometry_class), intent(in) :: self
    class(shape), intent(in) :: shapetype
    integer :: n
    type(string) :: outext
    select type (shapetype)
    type is (shape)
    class is (box)
        n=8
    class is (point)
        n=1
    class is (line)
        n=2
    class is (sphere)
        n=1
        class default
        outext='[geometry::getnumPoints] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    end function getnumPoints

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> method to print the details of a given geometry
    !> @param[in] self, shapetype
    !---------------------------------------------------------------------------
    subroutine printGeometry(self, shapetype)
    implicit none
    class(geometry_class), intent(in) :: self
    class(shape) :: shapetype

    type(vector) :: temp(2)
    type(string) :: temp_str(6)
    type(string) :: outext

    temp_str(1) = shapetype%pt%x
    temp_str(2) = shapetype%pt%y
    temp_str(3) = shapetype%pt%z
    select type (shapetype)
    type is (shape)
    class is (box)
        temp_str(4) = shapetype%size%x
        temp_str(5) = shapetype%size%y
        temp_str(6) = shapetype%size%z
        outext='      Box at '//temp_str(1)//' '//temp_str(2)//' '//temp_str(3)//new_line('a')//&
            '       with '//temp_str(4)//' X '//temp_str(5)//' X '//temp_str(6)
    class is (point)
        outext='      Point at '//temp_str(1)//' '//temp_str(2)//' '//temp_str(3)
    class is (line)
        temp_str(4) = shapetype%last%x
        temp_str(5) = shapetype%last%y
        temp_str(6) = shapetype%last%z
        outext='      Line from '//temp_str(1)//' '//temp_str(2)//' '//temp_str(3)//new_line('a')//&
            '       to '//temp_str(4)//' X '//temp_str(5)//' X '//temp_str(6)
    class is (sphere)
        temp_str(4) = shapetype%radius
        outext='      Sphere at '//temp_str(1)//' '//temp_str(2)//' '//temp_str(3)//new_line('a')//&
            '       with radius '//temp_str(4)
        class default
        outext='[geometry::print] : unexpected type for geometry object, stoping'
        call Log%put(outext)
        stop
    end select
    call Log%put(outext,.false.)

    end subroutine printGeometry

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> private function that returns the number of points distributed on a grid
    !> with spacing dp inside a sphere
    !> @param[in] dp, r
    !---------------------------------------------------------------------------
    function sphere_np_count(dp, r) result(np)
    implicit none
    real(prec), intent(in) :: dp
    real(prec), intent(in) :: r
    integer :: np
    integer :: i, j, k, n
    type(vector) :: pts
    np=0
    n=int(3*r/dp)
    do i=1, n
        do j=1, n
            do k=1, n
                pts = dp*(ex*(i-1)+ey*(j-1)+ez*(k-1)) - r*(ex+ey+ez)
                if (pts%normL2() .le. r) then
                    np=np+1
                end if
            end do
        end do
    end do
    if (np == 0) then !Just the center point
        np=1
    end if
    end function

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> private routine that returns the points distributed on a grid
    !> with spacing dp inside a sphere
    !> @param[in] dp, r, np, ptlist
    !---------------------------------------------------------------------------
    subroutine sphere_grid(dp, r, np, ptlist)
    implicit none
    real(prec), intent(in) :: dp
    real(prec), intent(in) :: r
    integer, intent(in)::  np
    type(vector), intent(out) :: ptlist(np)
    integer :: i, j, k, p, n
    type(vector) :: pts
    n=int(3*r/dp)
    p=0
    do i=1, n
        do j=1, n
            do k=1, n
                pts = dp*(ex*(i-1)+ey*(j-1)+ez*(k-1)) - r*(ex+ey+ez)
                if (pts%normL2() .le. r) then
                    p=p+1
                    ptlist(p)=pts
                end if
            end do
        end do
    end do
    if (np == 1) then !Just the center point
        ptlist(1)= 0*ex + 0*ey +0*ez
    end if

    end subroutine

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> private routine that returns the points distributed on a grid
    !> with spacing dp inside a box
    !> @param[in] dp, size, np, ptlist
    !---------------------------------------------------------------------------
    subroutine box_grid(dp, size, np, ptlist)
    implicit none
    real(prec), intent(in) :: dp
    type(vector), intent(in) :: size
    integer, intent(in)::  np
    type(vector), intent(out) :: ptlist(np)
    integer :: i, j, k, p
    p=0
    do i=1, int(size%x/dp)+1
        do j=1, int(size%y/dp)+1
            do k=1, int(size%z/dp)+1
                p=p+1
                ptlist(p) = dp*(ex*(i-1) + ey*(j-1) + ez*(k-1))
            end do
        end do
    end do
    if (np == 1) then !Just the origin
        ptlist(1)= 0*ex + 0*ey +0*ez
    end if
    end subroutine

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> private routine that returns the points distributed on a grid
    !> with spacing dp along a line
    !> @param[in] dp, dist, np, ptlist
    !---------------------------------------------------------------------------
    subroutine line_grid(dp, dist, np, ptlist)
    implicit none
    real(prec), intent(in) :: dp
    type(vector), intent(in) :: dist
    integer, intent(in)::  np
    type(vector), intent(out) :: ptlist(np)
    integer :: i, j, k, p

    do p=1, np
        ptlist(p) = dist*(p-1)/np
    end do
    if (np == 1) then !Just the origin
        ptlist(1)= 0*ex + 0*ey +0*ez
    end if
    end subroutine

    end module geometry_mod