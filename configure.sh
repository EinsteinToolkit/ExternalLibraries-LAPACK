#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors

. $CCTK_HOME/lib/make/bash_utils.sh

################################################################################
# Search
################################################################################

# Take care of requests to build the library in any case
LAPACK_DIR_INPUT=$LAPACK_DIR
if [ "$(echo "${LAPACK_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    LAPACK_BUILD=yes
    LAPACK_DIR=
else
    LAPACK_BUILD=
fi

# Try to find the library if build isn't explicitly requested
if [ -z "${LAPACK_BUILD}" ]; then
    for pkgname in lapack lapack-openblas lapack-atlas lapack-netlib ; do
        find_lib LAPACK $pkgname 1 "" "lapack" "" "${LAPACK_DIR}"
        if [ -n "${LAPACK_DIR}" ]; then
            break
        fi
    done
fi

################################################################################
# Build
################################################################################

if [ -n "$LAPACK_BUILD" -o -z "${LAPACK_DIR}" ]
then
    echo "BEGIN MESSAGE"
    echo "Using bundled LAPACK..."
    echo "END MESSAGE"
    
    # check for required tools. Do this here so that we don't require them when
    # using the system library
    if [ x$TAR = x ] ; then
      echo 'BEGIN ERROR'
      echo 'Could not find tar command. Please make sure that (gnu) tar is present'
      echo 'and that the TAR variable is set to its location.'
      echo 'END ERROR'
      exit 1
    fi
    #if [ x$PATCH = x ] ; then
    #  echo 'BEGIN ERROR'
    #  echo 'Could not find patch command. Please make sure that (gnu) tar is present'
    #  echo 'and that the PATCH variable is set to its location.'
    #  echo 'END ERROR'
    #  exit 1
    #fi

    # Set locations
    THORN=LAPACK
    NAME=lapack-3.9.0
    SRCDIR="$(dirname $0)"
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${LAPACK_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing LAPACK into ${LAPACK_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${LAPACK_INSTALL_DIR}
    fi
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    LAPACK_DIR=${INSTALL_DIR}
    LAPACK_LIBS='lapack'
    LAPACK_INC_DIRS=
    LAPACK_LIB_DIRS=${LAPACK_DIR}/lib

    if [ "${F77}" = "none" ]; then
        echo 'BEGIN ERROR'
        echo "Building LAPACK requires a fortran compiler, but there is none configured: F77 = $F77. Aborting."
        echo 'END ERROR'
        exit 1
    fi
    
    if [ -e ${DONE_FILE} -a ${DONE_FILE} -nt ${SRCDIR}/dist/${NAME}.tgz \
                         -a ${DONE_FILE} -nt ${SRCDIR}/configure.sh ]
    then
        echo "BEGIN MESSAGE"
        echo "LAPACK has already been built; doing nothing"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Building LAPACK"
        echo "END MESSAGE"
        
        # Build in a subshell
        (
        exec >&2                # Redirect stdout to stderr
        if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
            set -x              # Output commands
        fi
        set -e                  # Abort on errors
        cd ${SCRATCH_BUILD}
        
        # Set up environment
        unset LIBS
	if [ ${USE_RANLIB} != 'yes' ]; then
            RANLIB=': ranlib'
        fi
        
        echo "LAPACK: Preparing directory structure..."
        mkdir build external done 2> /dev/null || true
        rm -rf ${BUILD_DIR} ${INSTALL_DIR}
        mkdir ${BUILD_DIR} ${INSTALL_DIR}
        
        echo "LAPACK: Unpacking archive..."
        pushd ${BUILD_DIR}
        ${TAR?} xzf ${SRCDIR}/dist/${NAME}.tgz
        
        echo "LAPACK: Configuring..."
        cd ${NAME}/SRC
        
        echo "LAPACK: Building..."
        #if echo ${F77} | grep -i xlf > /dev/null 2>&1; then
        #    FIXEDF77FLAGS=-qfixed
        #fi
        if ${F77} -qversion 2>/dev/null | grep -q 'IBM XL Fortran'; then
            FIXEDF77FLAGS=-qfixed
        fi
        #${F77} ${F77FLAGS} ${FIXEDF77FLAGS} -c *.f ../INSTALL/dlamch.f ../INSTALL/ilaver.f ../INSTALL/lsame.f ../INSTALL/slamch.f
        #${AR} ${ARFLAGS} liblapack.a *.o
	#if [ ${USE_RANLIB} = 'yes' ]; then
	#    ${RANLIB} ${RANLIBFLAGS} liblapack.a
        #fi
        cat > make.cactus <<EOF
SRCS = $(echo *.f) ../INSTALL/dlamch.f ../INSTALL/ilaver.f ../INSTALL/lsame.f ../INSTALL/slamch.f
liblapack.a: \$(SRCS:%.f=%.o)
	${AR} ${ARFLAGS} \$@ \$^
	${RANLIB} ${RANLIBFLAGS} \$@
%.o: %.f
	${F77} ${F77FLAGS} ${FIXEDF77FLAGS} -c \$*.f -o \$*.o
EOF
        ${MAKE} -f make.cactus
        
        echo "LAPACK: Installing..."
        cp liblapack.a ${LAPACK_DIR}
        popd
        
        echo "LAPACK: Cleaning up..."
        rm -rf ${BUILD_DIR}
        
        date > ${DONE_FILE}
        echo "LAPACK: Done."
        )
        
        if (( $? )); then
            echo 'BEGIN ERROR'
            echo 'Error while building LAPACK. Aborting.'
            echo 'END ERROR'
            exit 1
        fi
    fi
    
fi



################################################################################
# Configure Cactus
################################################################################

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "LAPACK_DIR      = ${LAPACK_DIR}"
echo "LAPACK_INC_DIRS = ${LAPACK_INC_DIRS}"
echo "LAPACK_LIB_DIRS = ${LAPACK_LIB_DIRS}"
echo "LAPACK_LIBS     = ${LAPACK_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(LAPACK_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(LAPACK_LIB_DIRS)'
echo 'LIBRARY           $(LAPACK_LIBS)'
