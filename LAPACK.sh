#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
set -x                          # Output commands
set -e                          # Abort on errors



################################################################################
# Search
################################################################################

if [ -z "${LAPACK_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "LAPACK selected, but LAPACK_DIR not set. Checking some places..."
    echo "END MESSAGE"
    
    FILES="liblapack.a liblapack.so"
    DIRS="/usr/lib /usr/local/lib ${HOME}"
    for file in $FILES; do
        for dir in $DIRS; do
            if test -r "$dir/$file"; then
                LAPACK_DIR="$dir"
                break
            fi
        done
    done
    
    if [ -z "$LAPACK_DIR" ]; then
        echo "BEGIN MESSAGE"
        echo "LAPACK not found"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Found LAPACK in ${LAPACK_DIR}"
        echo "END MESSAGE"
    fi
fi



################################################################################
# Build
################################################################################

if [ -z "${LAPACK_DIR}" -o "${LAPACK_DIR}" = 'BUILD' ]; then
    echo "BEGIN MESSAGE"
    echo "Building LAPACK..."
    echo "END MESSAGE"
    
    # Set locations
    THORN=LAPACK
    NAME=lapack-3.2.2
    SRCDIR=$(dirname $0)
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    LAPACK_DIR=${INSTALL_DIR}
    
(
    exec >&2                    # Redirect stdout to stderr
    set -x                      # Output commands
    set -e                      # Abort on errors
    cd ${SCRATCH_BUILD}
    if [ -e ${DONE_FILE} -a ${DONE_FILE} -nt ${SRCDIR}/dist/${NAME}.tar.gz \
                         -a ${DONE_FILE} -nt ${SRCDIR}/LAPACK.sh ]
    then
        echo "LAPACK: The enclosed LAPACK library has already been built; doing nothing"
    else
        echo "LAPACK: Building enclosed LAPACK library"
        
        # Should we use gmake or make?
        MAKE=$(gmake --help > /dev/null 2>&1 && echo gmake || echo make)
        # Should we use gtar or tar?
        TAR=$(gtar --help > /dev/null 2> /dev/null && echo gtar || echo tar)
        
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
        ${TAR} xzf ${SRCDIR}/dist/${NAME}.tgz
        
        echo "LAPACK: Configuring..."
        cd ${NAME}/SRC
        
        echo "LAPACK: Building..."
        if echo ${F77} | grep -i xlf > /dev/null 2>&1; then
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
    fi
)

    if (( $? )); then
        echo 'BEGIN ERROR'
        echo 'Error while building LAPACK. Aborting.'
        echo 'END ERROR'
        exit 1
    fi

fi



################################################################################
# Configure Cactus
################################################################################

# Set options
if [ "${LAPACK_DIR}" != '/usr' -a "${LAPACK_DIR}" != '/usr/local' ]; then
    LAPACK_INC_DIRS=
    LAPACK_LIB_DIRS="${LAPACK_DIR}"
fi
: ${LAPACK_LIBS='lapack'}

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "HAVE_LAPACK     = 1"
echo "LAPACK_DIR      = ${LAPACK_DIR}"
echo "LAPACK_INC_DIRS = ${LAPACK_INC_DIRS}"
echo "LAPACK_LIB_DIRS = ${LAPACK_LIB_DIRS}"
echo "LAPACK_LIBS     = ${LAPACK_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(LAPACK_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(LAPACK_LIB_DIRS)'
echo 'LIBRARY           $(LAPACK_LIBS)'
