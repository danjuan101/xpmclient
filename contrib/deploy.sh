#!/bin/bash
set -e
VERSION="10.6.1"


CUDA10_INSTALLER="cuda_11.8.0_522.06_windows.exe"

if docker inspect --type=image xpmclient-$VERSION > /dev/null 2> /dev/null; then
  echo "xpmclient-$VERSION image already exists"
else
  echo "FROM nvidia/cuda:11.8.0-devel-ubuntu18.04" > xpmclient.Dockerfile
  echo "ENV DEBIAN_FRONTEND=noninteractive" >> xpmclient.Dockerfile

  # For debugging purposes, use apt-cacher-ng at localhost
  # echo "RUN echo \"Acquire::http::Proxy \\\"http://172.17.0.1:3142\\\";\" > /etc/apt/apt.conf.d/00aptproxy"  >> xpmclient.Dockerfile

  echo "RUN apt-get update && apt-get --no-install-recommends -y install g++-mingw-w64-x86-64 cmake p7zip-full lzip automake autoconf libtool nano zip" >> xpmclient.Dockerfile
  echo "RUN update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix" >> xpmclient.Dockerfile

  # Extract nvrtc to /usr/local/cuda-win32
  echo "COPY $CUDA10_INSTALLER /tmp" >> xpmclient.Dockerfile
  echo "RUN mkdir /usr/local/cuda-win32" >> xpmclient.Dockerfile
  echo "RUN 7z -o/tmp x '-i!cuda_nvrtc*' '-i!cuda_cudart*' /tmp/$CUDA10_INSTALLER"  >> xpmclient.Dockerfile
  echo "RUN cp -r /tmp/cuda_nvrtc/nvrtc/bin /usr/local/cuda-win32/bin" >> xpmclient.Dockerfile
  echo "RUN cp -r /tmp/cuda_nvrtc/nvrtc_dev/include /usr/local/cuda-win32/include" >> xpmclient.Dockerfile
  echo "RUN cp -r /tmp/cuda_nvrtc/nvrtc_dev/lib /usr/local/cuda-win32/lib" >> xpmclient.Dockerfile
  echo "RUN cp -r /tmp/cuda_cudart/cudart/include/* /usr/local/cuda-win32/include/" >> xpmclient.Dockerfile
  echo "RUN cp -r /tmp/cuda_cudart/cudart/lib/* /usr/local/cuda-win32/lib/" >> xpmclient.Dockerfile
  echo "RUN rm -rf /tmp/$CUDA10_INSTALLER /tmp/cuda_nvrtc /tmp/cuda_cudart" >> xpmclient.Dockerfile

  echo "RUN useradd -ms /bin/bash -U user" >> xpmclient.Dockerfile
  echo "RUN chown -R user /usr/local/cuda-win32" >> xpmclient.Dockerfile
  echo "USER user:user" >> xpmclient.Dockerfile
  echo "WORKDIR /home/user" >> xpmclient.Dockerfile  

  echo "CMD [\"sleep\", \"infinity\"]" >> xpmclient.Dockerfile
  docker build --pull -f xpmclient.Dockerfile -t xpmclient-$VERSION .
fi

# Create container and upload sources
CONTAINER=`docker run -d xpmclient-$VERSION`
if [ $? != 0 ];
then
  echo "Docker: container create error"
  exit 1
fi

# Download dependencies: gmp zmq protobuf
if [ ! -f gmp-6.1.2.tar.lz ]; then
  wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.lz
fi
if [ ! -f zeromq-4.3.1.tar.gz ]; then
  wget https://github.com/zeromq/libzmq/releases/download/v4.3.1/zeromq-4.3.1.tar.gz
fi
if [ ! -f protobuf-cpp-3.6.1.tar.gz ]; then
  wget https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/protobuf-cpp-3.6.1.tar.gz
fi
if [ ! -f libsodium-1.0.17.tar.gz ]; then
  wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.17.tar.gz
fi
if [ ! -f libsodium-1.0.17.tar.gz ]; then
  wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.17.tar.gz
fi
if [ ! -d CLRX-mirror ]; then
  git clone https://github.com/CLRX/CLRX-mirror
  cd CLRX-mirror && git checkout c5f9dd2ce7f9667715c74ae875bb52df6bbbf0ad && cd ..
fi

docker exec $CONTAINER mkdir /home/user/build
docker exec $CONTAINER mkdir /home/user/build/deps-linux
docker exec $CONTAINER mkdir /home/user/build/deps-win32
docker exec $CONTAINER mkdir /home/user/build/xpmclient
docker cp gmp-6.1.2.tar.lz $CONTAINER:/home/user/build
docker cp zeromq-4.3.1.tar.gz $CONTAINER:/home/user/build
docker cp protobuf-cpp-3.6.1.tar.gz $CONTAINER:/home/user/build
docker cp libsodium-1.0.17.tar.gz $CONTAINER:/home/user/build
docker cp CLRX-mirror $CONTAINER:/home/user/build
docker cp ../src $CONTAINER:/home/user/build/xpmclient

# Run build
docker cp build.sh $CONTAINER:/home/user/build
docker exec $CONTAINER chmod +x /home/user/build/build.sh
docker exec $CONTAINER /home/user/build/build.sh

# Grab artifacts
rm -rf distr && mkdir distr && cd distr
docker cp $CONTAINER:/home/user/build/xpmclient/x86_64-Linux/xpmclient-opencl-$VERSION-linux.tar.gz .
docker cp $CONTAINER:/home/user/build/xpmclient/x86_64-Linux/xpmclient-cuda-$VERSION-linux.tar.gz .
docker cp $CONTAINER:/home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-opencl-$VERSION-win64.zip .
docker cp $CONTAINER:/home/user/build/xpmclient/x86_64-w64-mingw32/xpmclient-cuda-$VERSION-win64.zip .
docker cp $CONTAINER:/home/user/build/xpmclient/xpmclient-$VERSION-sha256.txt .
