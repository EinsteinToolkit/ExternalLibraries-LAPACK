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
    echo "LAPACK selected, but LAPACK_DIR not set.  Checking some places..."
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

if [ -z "${LAPACK_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Building LAPACK..."
    echo "END MESSAGE"
    
    # Set locations
    NAME=lapack-3.2.1
    SRCDIR=$(dirname $0)
    INSTALL_DIR=${SCRATCH_BUILD}
    LAPACK_DIR=${INSTALL_DIR}/${NAME}

    # Clean up environment
    unset LIBS
    unset MAKEFLAGS
    
(
    exec >&2                    # Redirect stdout to stderr
    set -x                      # Output commands
    set -e                      # Abort on errors
    cd ${INSTALL_DIR}
    if [ -e done-${NAME} -a done-${NAME} -nt ${SRCDIR}/dist/${NAME}.tgz \
                         -a done-${NAME} -nt ${SRCDIR}/LAPACK.sh ]
    then
        echo "LAPACK: The enclosed LAPACK library has already been built; doing nothing"
    else
        echo "LAPACK: Building enclosed LAPACK library"
        
        echo "LAPACK: Unpacking archive..."
        rm -rf build-${NAME}
        mkdir build-${NAME}
        pushd build-${NAME}
        # Should we use gtar or tar?
        TAR=$(gtar --help > /dev/null 2> /dev/null && echo gtar || echo tar)
        ${TAR} xzf ${SRCDIR}/dist/${NAME}.tgz
        popd
        
        echo "LAPACK: Configuring..."
        rm -rf ${NAME}
        mkdir ${NAME}
        pushd build-${NAME}/${NAME}/SRC
        
        echo "LAPACK: Building..."
        ${F77} ${F77FLAGS} -c *.f
        ${AR} ${ARFLAGS} lapack.a *.o
	if [ ${USE_RANLIB} = 'yes' ]; then
	    ${RANLIB} ${RANLIBFLAGS} lapack.a
        fi
        
        echo "LAPACK: Installing..."
        cp lapack.a ${LAPACK_DIR}
        popd
        
        echo 'done' > done-${NAME}
        echo "LAPACK: Done."
    fi
)

    if (( $? )); then
        echo 'BEGIN ERROR'
        echo 'Error while building LAPACK.  Aborting.'
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
