FROM alpine:3.12 as compiling
MAINTAINER docker@chabs.name

ENV UPNP_VERSION 1.14.0
ENV WX_VERSION 3.0.5.1
# ENV PNG_VERSION 1.6.35
ENV CRYPTOPP_VERSION CRYPTOPP_8_2_0

RUN apk --update add gd geoip libpng libwebp pwgen sudo zlib bash && \
    apk --update add --virtual build-dependencies alpine-sdk automake \
        autoconf bison g++ gcc gd-dev geoip-dev \
        gettext gettext-dev git libpng-dev libwebp-dev \
        libtool libsm-dev make musl-dev wget \
        flex zlib-dev zlib-static \
        asio-dev boost-static libpng-static

# Build libupnp
RUN mkdir -p /opt \
    && cd /opt \
    && wget "http://downloads.sourceforge.net/sourceforge/pupnp/libupnp-${UPNP_VERSION}.tar.bz2" \
    && tar xvfj libupnp-${UPNP_VERSION}.tar.bz2 \
    && cd libupnp-${UPNP_VERSION} \
    && ./configure --prefix=/usr \
    && make \
    && make install

# Build wxWidgets
RUN mkdir -p /opt \
    && cd /opt \
    && wget "https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2" \
    && tar xvfj wxWidgets-${WX_VERSION}.tar.bz2 \
    && cd wxWidgets-${WX_VERSION} \
    && ./configure --prefix=/usr \
		--enable-unicode \
		--disable-debug \
		--enable-static \
        --disable-shared \
    && make \
    && make install

# Build libpng
# RUN mkdir -p /opt \
    # && cd /opt \
    # && wget "https://github.com/glennrp/libpng/archive/v${PNG_VERSION}.tar.gz" \
    # && tar xvf v${PNG_VERSION}.tar.gz \
    # && cd libpng-${PNG_VERSION} \
    # && ./configure --prefix=/usr \
        # --enable-static \
    # && make \
    # && make install

# Build crypto++
RUN mkdir -p /opt && cd /opt \
    && git clone --branch ${CRYPTOPP_VERSION} --single-branch "https://github.com/weidai11/cryptopp" /opt/cryptopp \
    && cd /opt/cryptopp \
    && sed -i -e 's/^CXXFLAGS/#CXXFLAGS/' GNUmakefile \
    && export CXXFLAGS="${CXXFLAGS} -DNDEBUG -fPIC" \
    && make -f GNUmakefile \
    && make libcryptopp.so \
    && install -Dm644 libcryptopp.* /usr/lib/ \
    && mkdir -p /usr/include/cryptopp \
    && install -m644 *.h /usr/include/cryptopp/

# Build amule from source
RUN mkdir -p /opt/amule \
    && git clone --depth 1 https://github.com/persmule/amule-dlp.git /opt/amule \
    && cd /opt/amule \
	&& sed -i "s/UpnpInit/UpnpInit2/g" src/UPnPBase.cpp \
    && ./autogen.sh \
    && ./configure \
        --disable-gui \
        --disable-amule-gui \
        --disable-wxcas \
        --disable-alc \
        --disable-plasmamule \
        --disable-kde-in-home \
        --prefix=/usr \
        --mandir=/usr/share/man \
        --enable-unicode \
        --without-subdirs \
        --without-expat \
        --enable-amule-daemon \
        --enable-amulecmd \
        --enable-webserver \
        --enable-cas \
        --enable-alcc \
        --enable-fileview \
        --enable-geoip \
        --with-geoip-static \
        --enable-mmap \
        --enable-optimize \
        --enable-upnp \
        --with-boost \
        --enable-static-boost \
        --disable-debug \
        # --enable-static \
    && make \
    && make install \
    && make DESTDIR=/amule install-strip

# Build antiLeech from source
RUN mkdir -p /opt/antiLeech \
    && git clone --depth 1 https://github.com/persmule/amule-dlp.antiLeech.git /opt/antiLeech \
    && cd /opt/antiLeech \
    && ./autogen.sh \
    && ./configure \
        --prefix=/usr \
    && make \
    && make install \
    && cp /usr/share/amule/* /amule/usr/share/amule/

# Install a nicer web ui
RUN cd /amule/usr/share/amule-dlp/webserver \
    && git clone --depth 1 https://github.com/MatteoRagni/AmuleWebUI-Reloaded \
    && rm -rf AmuleWebUI-Reloaded/.git AmuleWebUI-Reloaded/doc-images

# Add startup script
ADD amule.sh /amule/home/amule/amule.sh

# Copy LIBS
RUN ldd /usr/bin/ed2k|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/ed2k.tar \
    && tar -xvf /tmp/ed2k.tar -C /amule \
    && ldd /usr/bin/cas|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/cas.tar \
    && tar -xvf /tmp/cas.tar -C /amule \
    && ldd /usr/bin/alcc|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/alcc.tar \
    && tar -xvf /tmp/alcc.tar -C /amule \
    && ldd /usr/bin/amule|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/amule.tar \
    && tar -xvf /tmp/amule.tar -C /amule \
    && ldd /usr/bin/amuled|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/amuled.tar \
    && tar -xvf /tmp/amuled.tar -C /amule \
    && ldd /usr/bin/amuleweb|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/amuleweb.tar \
    && tar -xvf /tmp/amuleweb.tar -C /amule \
    && ldd /usr/bin/amulecmd|cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/amulecmd.tar \
    && tar -xvf /tmp/amulecmd.tar -C /amule

FROM alpine:3.12

RUN apk --update add sudo bash

COPY --from=compiling  /amule  /

# Final cleanup
RUN chmod a+x /home/amule/amule.sh \
    && rm -rf /var/cache/apk/*

EXPOSE 4711/tcp 4712/tcp 4672/udp 4665/udp 4662/tcp 4661/tcp

ENTRYPOINT ["/home/amule/amule.sh"]
